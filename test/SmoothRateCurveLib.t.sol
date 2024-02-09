// SPDX-License-Identifier: BSL-1.1
// Copyright Itos Inc 2023
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import { SmoothRateCurveLib, SmoothRateCurveConfig } from "../src/Math/SmoothRateCurveLib.sol";

contract SmoothRateCurveLibTest is Test {
    using SmoothRateCurveLib for SmoothRateCurveConfig;

    SmoothRateCurveConfig private emptyConfig;
    SmoothRateCurveConfig private mmConfigSPR;
    SmoothRateCurveConfig private swapFeeSPRConfig;
    SmoothRateCurveConfig private borrowPowerConfig;
    SmoothRateCurveConfig private internalBorrowerSPRConfig;

    uint128 private constant ZERO_PERCENT_X64 = 0;
    uint128 private constant TWENTY_PERCENT_X64 = 3689348814741910528; // (0.2 * 2**64 = 3689348814741910528)
    uint128 private constant FIFTY_PERCENT_X64 = 9223372036854775808; // (0.5 * 2**64 = 9223372036854775808)
    uint128 private constant SEVENTY_PERCENT_X64 = 12912720851596685312; // (0.7 * 2**64 = 12912720851596685312)
    uint128 private constant EIGHTY_PERCENT_X64 = 14757395258967642112; // (0.8 * 2**64 = 14757395258967642112)
    uint128 private constant ONE_HUNDRED_PERCENT_X64 = (1 << 64);
    uint128 private constant ONE_HUNDRED_TWENTY_PERCENT_X64 = 22136092888451461120;
    uint128 private constant TWO_HUNDRED_PERCENT_X64 = (2 << 64);

    function setUp() public {
        // base rate 0.5%, target rate 12%, target util 80%, max util 100%, max fee 9100% (as APRs)
        mmConfigSPR.initializeStorageConfig(
            310220638285672831737560825856,
            -13892382412,
            18446744073709551616,
            53229759979311 // translates to an APR of 90.99999999999905 instead of 91
        );

        // base rate 0.03%, target rate 0.3%, target util 50%, max util 100%, max fee 1% (as APRs)
        swapFeeSPRConfig.initializeStorageConfig(
            29133764291176239522245509120,
            -1403861801,
            18446744073709551616,
            58494241735 // translates to an APR of 0.0999999999991329 instead of 0.1
        );

        // base rate 1, target rate 2, target util 70%, max util 120%, max fee 5
        borrowPowerConfig.initializeStorageConfig(
            291670600217947238206207436531303448576,
            5270498306774159360,
            22136092888451461120,
            5 << 64
        );

        // base rate 0.5%, target rate 16%, target util 50%, max util 120%, max fee 1500% (as APRs)
        internalBorrowerSPRConfig.initializeStorageConfig(
            2809789711637885816854168993792,
            -124007792479,
            22136092888451461120,
            8774136260326 // translates to an APR of 14.999999999999863 instead of 15
        );
    }

    // Initialization Tests

    function testStorageAndMemoryInitializationAreEqualWhenGivenTheSameParams() public {
        uint128 invAlphaX128 = 310220638285672831737560825856;
        int128 betaX64 = -13892382412;
        uint128 maxUtilX64 = 18446744073709551616;
        uint128 maxRateX64 = 53229759979311;

        emptyConfig.initializeStorageConfig(invAlphaX128, betaX64, maxUtilX64, maxRateX64);

        SmoothRateCurveConfig memory memoryConfig;
        memoryConfig.initializeMemoryConfig(invAlphaX128, betaX64, maxUtilX64, maxRateX64);

        assertEq(emptyConfig.invAlphaX128, memoryConfig.invAlphaX128);
        assertEq(emptyConfig.betaX64, memoryConfig.betaX64);
        assertEq(emptyConfig.maxUtilX64, memoryConfig.maxUtilX64);
        assertEq(emptyConfig.maxRateX64, memoryConfig.maxRateX64);

        assertEq(emptyConfig.invAlphaX128, invAlphaX128);
        assertEq(emptyConfig.betaX64, uint128((1 << 64) + betaX64));
        assertEq(emptyConfig.maxUtilX64, maxUtilX64);
        assertEq(emptyConfig.maxRateX64, maxRateX64);
    }

    function testInitializeStorageConfigPositiveBeta() public {
        emptyConfig.initializeStorageConfig(1, 2, 3, 3);

        assertEq(emptyConfig.invAlphaX128, 1);
        assertEq(emptyConfig.betaX64, 2 + (1 << 64));
        assertEq(emptyConfig.maxUtilX64, 3);
        assertEq(emptyConfig.maxRateX64, 3);
    }

    function testInitializeMemoryConfigPositiveBeta() public {
        SmoothRateCurveConfig memory memoryConfig;
        memoryConfig.initializeMemoryConfig(1, 2, 3, 3);

        assertEq(memoryConfig.invAlphaX128, 1);
        assertEq(memoryConfig.betaX64, 2 + (1 << 64));
        assertEq(memoryConfig.maxUtilX64, 3);
        assertEq(memoryConfig.maxRateX64, 3);
    }

    function testInitializeStorageConfigNegativeBeta() public {
        emptyConfig.initializeStorageConfig(100, -2, 3, 4);

        assertEq(emptyConfig.invAlphaX128, 100);
        assertEq(emptyConfig.betaX64, (1 << 64) - 2);
        assertEq(emptyConfig.maxUtilX64, 3);
        assertEq(emptyConfig.maxRateX64, 4);
    }

    function testInitializeMemoryConfigNegativeBeta() public {
        SmoothRateCurveConfig memory memoryConfig;
        memoryConfig.initializeMemoryConfig(100, -2, 3, 4);

        assertEq(memoryConfig.invAlphaX128, 100);
        assertEq(memoryConfig.betaX64, (1 << 64) - 2);
        assertEq(memoryConfig.maxUtilX64, 3);
        assertEq(memoryConfig.maxRateX64, 4);
    }

    function testRevertInitializeStorageConfigIfNegativeBetaOverflowsTheOffset() public {
        int128 beta = -(1 << 72);
        vm.expectRevert(abi.encodeWithSelector(SmoothRateCurveLib.BetaOverflowsOffset.selector, beta));
        emptyConfig.initializeStorageConfig(1, beta, 3, 4);
    }

    function testRevertInitializeMemoryConfigIfNegativeBetaOverflowsTheOffset() public {
        SmoothRateCurveConfig memory memoryConfig;

        int128 beta = -(1 << 72);
        vm.expectRevert(abi.encodeWithSelector(SmoothRateCurveLib.BetaOverflowsOffset.selector, beta));
        memoryConfig.initializeMemoryConfig(1, beta, 3, 4);
    }

    function testRevertInitializeStorageConfigIfCalculationOverflowsAtZeroPercentUtilization() public {
        int128 beta = -13892382412;
        vm.expectRevert(stdError.arithmeticError);
        emptyConfig.initializeStorageConfig((1 << 128) - 1, beta, 1, 4);
    }

    function testRevertInitializeStorageConfigIfCalculationOverflowsAtNearMaxUtilization() public {
        int128 beta = -13892382412;
        vm.expectRevert(stdError.arithmeticError);
        emptyConfig.initializeStorageConfig((1 << 128) - 1, beta, (1 << 128) - 1, 4);
    }

    function testRevertInitializeMemoryConfigIfCalculationOverflowsAtZeroPercentUtilization() public {
        SmoothRateCurveConfig memory memoryConfig;

        int128 beta = -13892382412;
        vm.expectRevert(stdError.arithmeticError);
        memoryConfig.initializeMemoryConfig((1 << 128) - 1, beta, 1, 4);
    }

    function testRevertInitializeMemoryConfigIfCalculationOverflowsAtNearMaxUtilization() public {
        SmoothRateCurveConfig memory memoryConfig;

        int128 beta = -13892382412;
        vm.expectRevert(stdError.arithmeticError);
        memoryConfig.initializeMemoryConfig((1 << 128) - 1, beta, (1 << 128) - 1, 4);
    }

    function testRevertInitializeStorageConfigIfMaxRateIsGreaterThanMaxCalculatedRate() public {
        vm.expectRevert(abi.encodeWithSelector(SmoothRateCurveLib.MaxRateAboveCurve.selector, 4, 1));
        emptyConfig.initializeStorageConfig(1, 0, 1, 4);
    }

    function testRevertInitializeMemoryConfigIfMaxRateIsGreaterThanMaxCalculatedRate() public {
        SmoothRateCurveConfig memory memoryConfig;

        vm.expectRevert(abi.encodeWithSelector(SmoothRateCurveLib.MaxRateAboveCurve.selector, 4, 1));
        memoryConfig.initializeMemoryConfig(1, 0, 1, 4);
    }

    // Money Market Tests (SPR)

    function testMMSPRAtZeroPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64Storage(ZERO_PERCENT_X64);
        // translates to an APR of 0.0049999999986744675 instead of 0.005000000000000001
        assertEq(rateX64, 2924712086);
    }

    function testMMSPRAtTwentyPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64Storage(TWENTY_PERCENT_X64);
        // translates to an APR of 0.012187499999119673 instead of 0.0121875
        assertEq(rateX64, 7128985711);
    }

    function testMMSPRAtFiftyPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64Storage(FIFTY_PERCENT_X64);
        // translates to an APR of 0.03374999999874572 instead of 0.03374999999999999
        assertEq(rateX64, 19741806585);
    }

    // target util is at 80% for this config
    function testMMSPRAtTargetUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64Storage(EIGHTY_PERCENT_X64);
        // translates to an APR of 0.11999999999895948 instead of 0.12
        assertEq(rateX64, 70193090082);
    }

    function testMMSPRAtMaxUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64Storage(ONE_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 53229759979311); // hits max fee rate
    }

    function testMMSPROverMaxUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64Storage(TWO_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 53229759979311); // hits max fee rate
    }

    // Swap Fee Tests

    function testSwapSPRAtZeroPercentUtilization() public {
        uint128 rateX64 = swapFeeSPRConfig.calculateRateX64Storage(0);
        // translates to an APR of 0.00029999999964693685 instead of 0.0002999999999999998
        assertEq(rateX64, 175482725);
    }

    function testSwapSPRAtTwentyPercentUtilization() public {
        uint128 rateX64 = swapFeeSPRConfig.calculateRateX64Storage(TWENTY_PERCENT_X64);
        // translates to an APR of 0.0009750000001347223 instead of 0.0009749999999999996
        assertEq(rateX64, 570318857);
    }

    // target util is at 50% for this config
    function testSwapSPRAtTargetUtilization() public {
        uint128 rateX64 = swapFeeSPRConfig.calculateRateX64Storage(FIFTY_PERCENT_X64);
        // translates to an APR of 0.0029999999998885085 instead of 0.003
        assertEq(rateX64, 1754827252);
    }

    function testSwapSPRAtEightyPercentUtilization() public {
        uint128 rateX64 = swapFeeSPRConfig.calculateRateX64Storage(EIGHTY_PERCENT_X64);
        // translates to an APR of 0.011100000000613224 instead of 0.011100000000000002
        assertEq(rateX64, 6492860833);
    }

    function testSwapSPRAtMaxUtilization() public {
        uint128 rateX64 = swapFeeSPRConfig.calculateRateX64Storage(ONE_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 58494241735); // hits max fee rate
    }

    function testSwapSPROverMaxUtilization() public {
        uint128 rateX64 = swapFeeSPRConfig.calculateRateX64Storage(TWO_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 58494241735); // hits max fee rate
    }

    // Borrow Power Tests

    function testBorrowPowerAtZeroPercentUtilization() public {
        uint128 rateX64 = borrowPowerConfig.calculateRateX64Storage(0);
        // 1511 below expected (1 << 64)
        assertEq(rateX64, 18446744073709553127);
    }

    function testBorrowPowerAtTwentyPercentUtilization() public {
        uint128 rateX64 = borrowPowerConfig.calculateRateX64Storage(TWENTY_PERCENT_X64);
        // 1.142857142857143 instead of 1.1428571428571428
        assertEq(rateX64, 21081993227096632173);
    }

    function testBorrowPowerAtFiftyPercentUtilization() public {
        uint128 rateX64 = borrowPowerConfig.calculateRateX64Storage(FIFTY_PERCENT_X64);
        // exactly 1.5102040816326532
        assertEq(rateX64, 27858348192949120701);
    }

    // target util is at 70% for this config
    function testBorrowPowerSPRAtTargetUtilization() public {
        uint128 rateX64 = borrowPowerConfig.calculateRateX64Storage(SEVENTY_PERCENT_X64);
        assertEq(rateX64, (2 << 64));
    }

    function testBorrowPowerAtEightyPercentUtilization() public {
        uint128 rateX64 = borrowPowerConfig.calculateRateX64Storage(EIGHTY_PERCENT_X64);
        // exactly 2.428571428571429
        assertEq(rateX64, 44799235607580347977);
    }

    function testBorrowPowerAtOneHundredPercentUtilization() public {
        uint128 rateX64 = borrowPowerConfig.calculateRateX64Storage(ONE_HUNDRED_PERCENT_X64);
        // exactly 4.571428571428572
        assertEq(rateX64, 84327972908386536594);
    }

    function testBorrowPowerAtMaxUtilization() public {
        uint128 rateX64 = borrowPowerConfig.calculateRateX64Storage(ONE_HUNDRED_TWENTY_PERCENT_X64);
        assertEq(rateX64, (5 << 64)); // hits max
    }

    function testBorrowPowerOverMaxUtilization() public {
        uint128 rateX64 = borrowPowerConfig.calculateRateX64Storage(TWO_HUNDRED_PERCENT_X64);
        assertEq(rateX64, (5 << 64)); // hits max
    }

    // Internal Borrower Tests

    function testInternalBorrowerSPRAtZeroPercentUtilization() public {
        uint128 rateX64 = internalBorrowerSPRConfig.calculateRateX64Storage(0);
        // translates to an APR of 0.0050000000003840375 instead of 0.005
        assertEq(rateX64, 2924712087);
    }

    function testInternalBorrowerSPRAtTwentyPercentUtilization() public {
        uint128 rateX64 = internalBorrowerSPRConfig.calculateRateX64Storage(TWENTY_PERCENT_X64);
        // translates to an APR of 0.04840000000002481 instead of 0.04839999999999998
        assertEq(rateX64, 28311213000);
    }

    // target util is at 50% for this config
    function testInternalBorrowerSPRAtTargetUtilization() public {
        uint128 rateX64 = internalBorrowerSPRConfig.calculateRateX64Storage(FIFTY_PERCENT_X64);
        // translates to an APR of 0.16000000000032222 instead of 0.16
        assertEq(rateX64, 93590786777);
    }

    function testInternalBorrowerSPRAtEightyPercentUtilization() public {
        uint128 rateX64 = internalBorrowerSPRConfig.calculateRateX64Storage(EIGHTY_PERCENT_X64);
        // translates to an APR of 0.43900000000021094 instead of 0.43900000000000006
        assertEq(rateX64, 256789721219);
    }

    function testInternalBorrowerSPRAtOneHundredPercentUtilization() public {
        uint128 rateX64 = internalBorrowerSPRConfig.calculateRateX64Storage(ONE_HUNDRED_PERCENT_X64);
        // translates to an APR of 1.0899999999999512 instead of 1.09
        assertEq(rateX64, 637587234917);
    }

    function testInternalBorrowerSPRAtMaxUtilization() public {
        uint128 rateX64 = internalBorrowerSPRConfig.calculateRateX64Storage(ONE_HUNDRED_TWENTY_PERCENT_X64);
        assertEq(rateX64, 8774136260326); // hits max fee rate
    }

    function testInternalBorrowerSPROverMaxUtilization() public {
        uint128 rateX64 = internalBorrowerSPRConfig.calculateRateX64Storage(TWO_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 8774136260326); // hits max fee rate
    }
}
