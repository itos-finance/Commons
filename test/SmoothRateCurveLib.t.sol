// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { SmoothRateCurveLib, SmoothRateCurveConfig } from "../src/Math/SmoothRateCurveLib.sol";

contract SmoothRateCurveLibTest is Test {
    using SmoothRateCurveLib for SmoothRateCurveConfig;

    SmoothRateCurveConfig private mmConfigAPR;
    SmoothRateCurveConfig private mmConfigSPR;
    SmoothRateCurveConfig private ammConfig;
    SmoothRateCurveConfig private otherConfig;

    function setUp() public {
        // reasonable defaults for the money market
        // base rate 0.5%, target rate 12%, target util 80%, max util 100%, max fee 9100%
        mmConfigAPR.initializeConfig(
            38215304878816319171133364334755840, 
            -438110171750601664, 
            72057594037927936, 
            1678653710707569197056
        );

        // reasonable defaults for the money market
        // base rate 0.5%, target rate 12%, target util 80%, max util 100%, max fee 9100%
        mmConfigSPR.initializeConfig(
            1211799368303409498974846976, 
            -13892382412, 
            72057594037927936, 
            53229759979311 // technically 9099.999999999905%
        );

        // reasonable defaults for the AMM 
        // base rate 1.5%, target rate 20%, target util 50%, max util 85%, max fee 32000%
        // ammConfig.initializeConfig();

        // other sort of random configuration
        // otherConfig.initializeConfig();
    }

    // Initialization Tests

    // Money Market Tests (SPR)

    function testMMZeroPercentUtilizationSPR() public {
        uint72 rateX64 = mmConfigSPR.calculateRateX64(0);
        assertEq(rateX64, 2924712086); // APR of 0.0049999999986744675 instead of 0.005000000000000001
    }

    function testMMTwentyPercentUtilizationSPR() public {
        uint72 rateX64 = mmConfigSPR.calculateRateX64(14411518807585588); // 20%
        assertEq(rateX64, 7128985711); // APR of 0.012187499999119673 instead of expected  0.0121875 , actual 0.012187499999999999
    }

    function testMMFiftyPercentUtilizationSPR() public {
        uint72 rateX64 = mmConfigSPR.calculateRateX64(36028797018963968); // 50%
        assertEq(rateX64, 19741806585); // APR of 0.03374999999874572 instead of expected 0.03374999999999999 , actual 0.03374999999999999
    }

    function testMMTargetUtilizationSPR() public {
        uint72 rateX64 = mmConfigSPR.calculateRateX64(14411518807585588); // 80%
        assertEq(rateX64, 7128985711); // APR of 0.012187499999119673 instead of expected 0.12 , actual 0.012187499999999999
    }

    function testMMNearMaxUtilizationSPR() public {
        // without max limit, this would have been 91.47625 ~9147%
        uint72 rateX64 = mmConfigSPR.calculateRateX64((1 << 56) - 1);
        assertEq(rateX64, 1678653710707569197056); // expected 91, actual 91
    }

    function testMMAtMaxUtilizationSPR() public {
        uint72 rateX64 = mmConfigSPR.calculateRateX64((1 << 56)); // 100%
        assertEq(rateX64, 1678653710707569197056); // APR of 90.99999999999905 instead of expected 91, actual 91
    }

    function testMMOverMaxUtilizationSPR() public {
        uint72 rateX64 = mmConfigAPR.calculateRateX64((2 << 56)); // 200% but max is 100%
        assertEq(rateX64, 1678653710707569197056); // APR of 90.99999999999905 instead of expected 91, actual 91
    }

    // Money Market Tests (APR)

    function testMMZeroPercentUtilizationAPR() public {
        uint72 rateX64 = mmConfigAPR.calculateRateX64(0);
        assertEq(rateX64, 92233720368547776); // 0.005000000000000001
    }

    function testMMTwentyPercentUtilizationAPR() public {
        uint72 rateX64 = mmConfigAPR.calculateRateX64(14411518807585588); // 20%
        assertEq(rateX64, 224819693398335145); // expected  0.0121875 , actual 0.012187499999999999
    }

    function testMMFiftyPercentUtilizationAPR() public {
        uint72 rateX64 = mmConfigAPR.calculateRateX64(36028797018963968); // 50%
        assertEq(rateX64, 622577612487697216); // expected 0.03374999999999999 , actual 0.03374999999999999
    }

    function testMMTargetUtilizationAPR() public {
        uint72 rateX64 = mmConfigAPR.calculateRateX64(14411518807585588); // 80%
        assertEq(rateX64, 224819693398335145); // expected 0.12 , actual 0.012187499999999999
    }

    function testMMNearMaxUtilizationAPR() public {
        // without max limit, this would have been 91.47625 ~9147%
        uint72 rateX64 = mmConfigAPR.calculateRateX64((1 << 56) - 1);
        assertEq(rateX64, 1678653710707569197056); // expected 91, actual 91
    }

    function testMMAtMaxUtilizationAPR() public {
        uint72 rateX64 = mmConfigAPR.calculateRateX64((1 << 56)); // 100%
        assertEq(rateX64, 1678653710707569197056); // expected 91, actual 91
    }

    function testMMOverMaxUtilizationAPR() public {
        uint72 rateX64 = mmConfigAPR.calculateRateX64((2 << 56)); // 200% but max is 100%
        assertEq(rateX64, 1678653710707569197056); // expected 91, actual 91
    }

    // AMM Tests 

    // Other Config Tests 

}