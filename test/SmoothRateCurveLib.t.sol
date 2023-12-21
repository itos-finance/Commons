// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { SmoothRateCurveLib, SmoothRateCurveConfig } from "../src/Math/SmoothRateCurveLib.sol";

contract SmoothRateCurveLibTest is Test {
    using SmoothRateCurveLib for SmoothRateCurveConfig;

    SmoothRateCurveConfig private mmConfig;
    SmoothRateCurveConfig private ammConfig;
    SmoothRateCurveConfig private otherConfig;

    function setUp() public {
        // reasonable defaults for the money market
        // base rate 0.5%, target rate 12%, target util 80%, max util 100%, max fee 9100%
        mmConfig.initializeConfig(
            38215304878816319171133364334755840, 
            -438110171750601664, 
            72057594037927936, 
            1678653710707569197056
        );

        // reasonable defaults for the AMM 
        // ammConfig.initializeConfig();

        // other sort of random configuration
        // otherConfig.initializeConfig();
    }

    // Initialization Tests


    // Money Market Tests 

    function testMMZeroPercentUtilization() public {
        uint72 rateX64 = mmConfig.calculateRateX64(0);
        assertEq(rateX64, 92233720368547776); // 0.005000000000000001
    }

    function testMMTargetUtilization() public {
        uint72 rateX64 = mmConfig.calculateRateX64(14411518807585588); // 80%
        assertEq(rateX64, 224819693398335145); // expected 0.12 , actual 0.012187499999999999
    }

    function testMMFiftyPercentUtilization() public {
        uint72 rateX64 = mmConfig.calculateRateX64(36028797018963968); // 50%
        assertEq(rateX64, 622577612487697216); // expected 0.03374999999999999 , actual 0.03374999999999999
    }

    function testMMNearMaxUtilization() public {
        // without max limit, this would have been 91.47625 ~9147%
        uint72 rateX64 = mmConfig.calculateRateX64((1 << 56) - 1);
        assertEq(rateX64, 1678653710707569197056); // expected 91, actual 91
    }

    function testMMAtMaxUtilization() public {
        uint72 rateX64 = mmConfig.calculateRateX64((1 << 56)); // 100%
        assertEq(rateX64, 1678653710707569197056); // expected 91, actual 91
    }

    function testMMOverMaxUtilization() public {
        uint72 rateX64 = mmConfig.calculateRateX64((2 << 56)); // 200% but max is 100%
        assertEq(rateX64, 1678653710707569197056); // expected 91, actual 91
    }

    // AMM Tests 

    // Other Config Tests 

}