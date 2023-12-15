// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SmoothRateCurveLib, SmoothRateCurveConfig } from "../src/Math/SmoothRateCurveLib.sol";

contract SmoothRateCurveLibTest is Test {
    SmoothRateCurveConfig curveConfig;

    function setUp() public {
        curveConfig = SmoothRateCurveLib.defaultConfig();
    }

    function testDefaultConfig() public {
        SmoothRateCurveConfig memory config = SmoothRateCurveLib.defaultConfig();
        assertEq(config.invAlphaX120, 3242783188242379110212435968);
        assertEq(config.betaX64, 18446744031676564409);
        assertEq(config.maxUtilX56, 72129651631965856);
    }
}