// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SmoothRateCurveLib, SmoothRateCurveConfig } from "../src/Math/SmoothRateCurveLib.sol";

contract SmoothRateCurveLibTest is Test {
    using SmoothRateCurveLib for SmoothRateCurveConfig;

    SmoothRateCurveConfig private emptyConfig;
    SmoothRateCurveConfig private mmConfigSPR;
    SmoothRateCurveConfig private ammSwapFeeSPRConfig;
    SmoothRateCurveConfig private ammBorrowPowerSPRConfig;
    SmoothRateCurveConfig private ammInternalBorrowerSPRConfig;

    uint128 constant private ZERO_PERCENT_X64 = 0;
    uint128 constant private TWENTY_PERCENT_X64 = 3689348814741910528; // (0.2 * 2**64 = 3689348814741910528)
    uint128 constant private FIFTY_PERCENT_X64 = 9223372036854775808; // (0.5 * 2**64 = 9223372036854775808) 
    uint128 constant private SEVENTY_PERCENT_X64 = 9223372036854775808; // (0.5 * 2**64 = 9223372036854775808) 
    uint128 constant private EIGHTY_PERCENT_X64 = 14757395258967642112; // (0.8 * 2**64 = 14757395258967642112)
    uint128 constant private ONE_HUNDRED_PERCENT_X64 = (1 << 64);
    uint128 constant private ONE_HUNDRED_TWENTY_PERCENT_X64 = 22136092888451461120;
    uint128 constant private TWO_HUNDRED_PERCENT_X64 = (2 << 64);

    function setUp() public {
        // base rate 0.5%, target rate 12%, target util 80%, max util 100%, max fee 9100% (as APRs)
        mmConfigSPR.initializeConfig(
            310220638285672831737560825856, 
            -13892382412, 
            18446744073709551616, 
            53229759979311 // technically 9099.999999999905%
        );

        // base rate 0.03%, target rate 0.3%, target util 50%, max util 100%, max fee 1% (as APRs)
        ammSwapFeeSPRConfig.initializeConfig(
            29133764291176239522245509120, 
            -1403861801,
            18446744073709551616,
            58494241735 // translates to an APR of 0.0999999999991329 instead of 0.1
        );

        // base rate 1.0%, target rate 2.0%, target util 70%, max util 120%, max fee 5% (as APRs)
        ammBorrowPowerSPRConfig.initializeConfig(
            2809789711637885816854168993792, 
            -124007792479, 
            22136092888451461120, 
            8774136260326 // translates to an APR of 14.999999999999863 instead of 15
        );

        // base rate 0.5%, target rate 16%, target util 50%, max util 120%, max fee 1500% (as APRs)
        ammInternalBorrowerSPRConfig.initializeConfig(
            2809789711637885816854168993792, 
            -124007792479, 
            22136092888451461120, 
            8774136260326 // translates to an APR of 14.999999999999863 instead of 15
        );
    }

    // Initialization Tests

    function testInitializeConfigPositiveBeta() public {
        emptyConfig.initializeConfig(1, 2, 3, 4);

        assertEq(emptyConfig.invAlphaX128, 1);
        assertEq(emptyConfig.betaX64, 2 + (1 << 64));
        assertEq(emptyConfig.maxUtilX64, 3);
        assertEq(emptyConfig.maxRateX64, 4);
    }

    function testInitializeConfigNegativeBeta() public {
        emptyConfig.initializeConfig(1, -2, 3, 4);

        assertEq(emptyConfig.invAlphaX128, 1);
        assertEq(emptyConfig.betaX64, (1 << 64) - 2);
        assertEq(emptyConfig.maxUtilX64, 3);
        assertEq(emptyConfig.maxRateX64, 4);   
    }

    function testRevertInitializeConfigIfNegativeBetaOverflowsTheOffset() public {
        int128 beta = -(1 << 72);
        vm.expectRevert(abi.encodeWithSelector(SmoothRateCurveLib.BetaOverflowsOffset.selector, beta));
        emptyConfig.initializeConfig(1, beta, 3, 4);
        console.log(emptyConfig.betaX64);
    }

    // Money Market Tests (SPR)

    function testMMSPRAtZeroPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(ZERO_PERCENT_X64);
        // APR of 0.0049999999986744675 instead of 0.005000000000000001
        assertEq(rateX64, 2924712086);
    }

    function testMMSPRAtTwentyPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(TWENTY_PERCENT_X64);
        // APR of 0.012187499999119673 instead of expected  0.0121875 , actual 0.012187499999999999
        assertEq(rateX64, 7128985711);
    }

    function testMMSPRAtFiftyPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(FIFTY_PERCENT_X64);
        // APR of 0.03374999999874572 instead of expected 0.03374999999999999 , actual 0.03374999999999999
        assertEq(rateX64, 19741806585);
    }

    // target util is at 80% for this config
    function testMMSPRAtTargetUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(EIGHTY_PERCENT_X64);
        // APR of 0.012187499999119673 instead of expected 0.12 , actual 0.012187499999999999
        assertEq(rateX64, 7128985711); 
    }

    function testMMSPRAtMaxUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(ONE_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 53229759979311); // hits max fee rate
    }

    function testMMSPROverMaxUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(TWO_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 53229759979311); // hits max fee rate
    }

    // Swap Fee Tests 

    function testSwapSPRAtZeroPercentUtilization() public {
        uint128 rateX64 = ammSwapFeeSPRConfig.calculateRateX64(0);
        // translates to an APR of 0.00029999999964693685 instead of 0.0002999999999999998
        assertEq(rateX64, 175482725);
    }

    function testSwapSPRAtTwentyPercentUtilization() public {
        uint128 rateX64 = ammSwapFeeSPRConfig.calculateRateX64(TWENTY_PERCENT_X64);
        // translates to an APR of 0.0009750000001347223 instead of 0.0009749999999999996
        assertEq(rateX64, 570318857); 
    }

    // target util is at 50% for this config
    function testSwapSPRAtTargetUtilization() public {
        uint128 rateX64 = ammSwapFeeSPRConfig.calculateRateX64(FIFTY_PERCENT_X64);
         // translates to an APR of 0.0029999999998885085 instead of 0.003
        assertEq(rateX64, 1754827252);
    }

    function testSwapSPRAtEightyPercentUtilization() public {
        uint128 rateX64 = ammSwapFeeSPRConfig.calculateRateX64(EIGHTY_PERCENT_X64);
        // translates to an APR of 0.011100000000613224 instead of 0.011100000000000002
        assertEq(rateX64, 6492860833);
    }

    function testSwapSPRAtMaxUtilization() public {
        uint128 rateX64 = ammSwapFeeSPRConfig.calculateRateX64(ONE_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 58494241735); // hits max fee rate
    }

    function testSwapSPROverMaxUtilization() public {
        uint128 rateX64 = ammSwapFeeSPRConfig.calculateRateX64(TWO_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 58494241735); // hits max fee rate
    }

    // Borrow Power Tests 

    // Internal Borrower Tests

    function testInternalBorrowerSPRAtZeroPercentUtilization() public {
        uint128 rateX64 = ammInternalBorrowerSPRConfig.calculateRateX64(0);
        // translates to an APR of 0.0050000000003840375 instead of 0.005
        assertEq(rateX64, 2924712087);
    }

    function testInternalBorrowerSPRAtTwentyPercentUtilization() public {
        uint128 rateX64 = ammInternalBorrowerSPRConfig.calculateRateX64(TWENTY_PERCENT_X64);
        // translates to an APR of 0.04840000000002481 instead of 0.04839999999999998
        assertEq(rateX64, 28311213000); 
    }

    // target util is at 50% for this config
    function testInternalBorrowerSPRAtTargetUtilization() public {
        uint128 rateX64 = ammInternalBorrowerSPRConfig.calculateRateX64(FIFTY_PERCENT_X64);
         // translates to an APR of 0.16000000000032222 instead of 0.16
        assertEq(rateX64, 93590786777);
    }

    function testInternalBorrowerSPRAtEightyPercentUtilization() public {
        uint128 rateX64 = ammInternalBorrowerSPRConfig.calculateRateX64(EIGHTY_PERCENT_X64);
        // translates to an APR of 0.43900000000021094 instead of 0.43900000000000006
        assertEq(rateX64, 256789721219);
    }

    function testInternalBorrowerSPRAtOneHundredPercentUtilization() public {
        uint128 rateX64 = ammInternalBorrowerSPRConfig.calculateRateX64(ONE_HUNDRED_PERCENT_X64);
        // translates to an APR of 1.0899999999999512 instead of 1.09
        assertEq(rateX64, 637587234917);
    }

    function testInternalBorrowerSPRAtMaxUtilization() public {
        uint128 rateX64 = ammInternalBorrowerSPRConfig.calculateRateX64(ONE_HUNDRED_TWENTY_PERCENT_X64);
        assertEq(rateX64, 8774136260326); // hits max fee rate
    }

    function testInternalBorrowerSPROverMaxUtilization() public {
        uint128 rateX64 = ammInternalBorrowerSPRConfig.calculateRateX64(TWO_HUNDRED_PERCENT_X64);
        assertEq(rateX64, 8774136260326); // hits max fee rate
    }
}