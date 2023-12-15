// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

/// @dev We use lower precision here than in fee calculator to accomodate
/// maxUtils that are over 1 (which avoids div by 0).
/// Plus precision is not as important in this rate.
struct SmoothRateCurveConfig {
    uint120 invAlphaX120; // Always less than 1

    // We assume this value has already had the BETA_OFFSET added to it.
    // Otherwise it can be negative.
    uint72 betaX64; // Give it the extra bits so I don't have to think as hard.

    uint64 maxUtilX56; // Will be every so slightly greater than 1
} // 256 bits

library SmoothRateCurveLib {
    uint120 public constant DEFAULT_INV_ALPHA_X120 = 3242783188242379110212435968;
    uint72 public constant DEFAULT_BETA_X64 = 18446744031676564409;
    uint64 public constant DEFAULT_MAX_UTIL_X56 = 72129651631965856;

    /// We use a beta offset so we can do all our operations in uint.
    uint72 private constant BETA_OFFSET = 1 << 64;

    /// @param utilX56 The utilization percentage in X56 format.
    /// @return sprX64 The SPR (seconds percentage rate) in X64 format.
    function calculateRate(SmoothRateCurveConfig storage self, uint64 utilX56) public view returns (uint64 sprX64) {
        // We know our util can't go over 1 due to liquidity constraints.
        // So we set our maxUtil to be slightly greater than 1 to avoid a divide by 0.
        sprX64 = uint64(self.betaX64 + self.invAlphaX120 / (self.maxUtilX56 - utilX56) - BETA_OFFSET);
    }

    function defaultConfig() public pure returns (SmoothRateCurveConfig memory config) {
        config.invAlphaX120 = DEFAULT_INV_ALPHA_X120;
        config.betaX64 = DEFAULT_BETA_X64;
        config.maxUtilX56 = DEFAULT_MAX_UTIL_X56;
    }
}
