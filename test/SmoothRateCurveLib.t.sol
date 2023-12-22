// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { SmoothRateCurveLib, SmoothRateCurveConfig } from "../src/Math/SmoothRateCurveLib.sol";

contract SmoothRateCurveLibTest is Test {
    using SmoothRateCurveLib for SmoothRateCurveConfig;

    SmoothRateCurveConfig private mmConfigSPR;
    SmoothRateCurveConfig private ammSwapFeeSPRConfig;
    SmoothRateCurveConfig private ammBorrowPowerSPRConfig;
    SmoothRateCurveConfig private ammInternalBorrowerSPRConfig;

    uint128 constant private ZERO_PERCENT_X64 = 0;
    uint128 constant private TWENTY_PERCENT_X64 = 3689348814741910528; // (0.2 * 2**64 = 3689348814741910528)
    uint128 constant private FIFTY_PERCENT_X64 = 9223372036854775808; // (0.5 * 2**64 = 9223372036854775808) 
    uint128 constant private EIGHTY_PERCENT_X64 = 14757395258967642112; // (0.8 * 2**64 = 14757395258967642112)
    uint128 constant private ONE_HUNDRED_PERCENT_X64 = (1 << 64);
    uint128 constant private TWO_HUNDRED_PERCENT_X64 = (2 << 64);

    function setUp() public {
        // seconds_per_year = 365 * 24 * 60 * 60 = 31536000

/*
oh AMM has 3 curves
- Swap Fee curve (params are 0.0003, 0.0030, 50%, 100%, max 0.01)
- Borrow Power (params are 1.0, 2.0, 70%, 120%, max 5)
- Internal Borrower (0.5%, 16%, 50%, 120%, max=1500%)
*/

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

        // base rate 0.5%, target rate 12%, target util 80%, max util 100%, max fee 9100% (as APRs)


        // base rate 0.5%, target rate 12%, target util 80%, max util 100%, max fee 9100% (as APRs)
    }

    // Initialization Tests

    // Money Market Tests (SPR)

    function testMMSPRZeroPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(ZERO_PERCENT_X64);
        assertEq(rateX64, 2924712086); // APR of 0.0049999999986744675 instead of 0.005000000000000001
    }

    function testMMSPRTwentyPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(TWENTY_PERCENT_X64);
        assertEq(rateX64, 7128985711); // APR of 0.012187499999119673 instead of expected  0.0121875 , actual 0.012187499999999999
    }

    function testMMSPRFiftyPercentUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(9223372036854775808);
        assertEq(rateX64, 19741806585); // APR of 0.03374999999874572 instead of expected 0.03374999999999999 , actual 0.03374999999999999
    }

    // target util is at 80% for this config
    function testMMSPRAtTargetUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64(14757395258967642112); // 80% (0.8 * 2**64 = 14757395258967642112)
        assertEq(rateX64, 7128985711); // APR of 0.012187499999119673 instead of expected 0.12 , actual 0.012187499999999999
    }

    function testMMSPRAtMaxUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64((1 << 64)); // 100%
        assertEq(rateX64, 53229759979311); // APR of 90.99999999999905 instead of expected 91, actual 91
    }

    function testMMSPROverMaxUtilization() public {
        uint128 rateX64 = mmConfigSPR.calculateRateX64((2 << 64)); // 200% but max is 100%
        assertEq(rateX64, 53229759979311); // APR of 90.99999999999905 instead of expected 91, actual 91
    }

    // Swap Fee Tests 

    function testSwapSPRZeroPercentUtilization() public {
        uint128 rateX64 = ammSwapFeeSPRConfig.calculateRateX64(0);
        // translates to an APR of 0.00029999999964693685 instead of 0.0002999999999999998
        assertEq(rateX64, 175482725);
    }

    function testSwapSPRTwentyPercentUtilization() public {
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

}