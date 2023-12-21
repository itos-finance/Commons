// SPDX-License-Identifier: BSL-1.1
// Copyright Itos Inc 2023 
pragma solidity ^0.8.13;

import "forge-std/console.sol";

// Smooth Rate Curve Equations
// q - utilization ratio
// F(q) - fee rate is a hyperbolic function of the utilization ratio
//
// Parameters
// f_b - base fee rate
// f_t - target fee rate 
// f_m - maximum fee rate 
// q_t - target utilization 
// q_m - max utilization 
//
// where 
// f_b, f_t, f_b exist in R 
// q, q_t, q_m exist in [0, 1]
//
// alpha =  q_t / (q_m * (q_m - q_t) * (f_t - f_b))
// beta = f_b - 1 / (alpha * q_m)
//
// F(q) = min(beta + 1 / (alpha * (q_m - q)), f_m)

// alpha [10_000, 0]

// SPR factor 31536000 = 365 * 24 * 60 * 60
// APR of 0.001% = 0.00001
// as a SPR = 0.00001 / 31536000 =  0.00000000000031709791983764586504312531709791983764586504312531709791983 

struct SmoothRateCurveConfig {
    uint120 invAlphaX120;
    uint72 betaX64; // inludes the BETA_OFFSET, otherwise value could be negative
    uint64 maxUtilX56;
    uint72 maxRateX64;
}

library SmoothRateCurveLib {
    /// We use a beta offset so we can do all our operations in uint.
    uint72 private constant BETA_OFFSET = 1 << 64;

    function calculateRateX64(SmoothRateCurveConfig storage self, uint64 utilX56) internal view returns (uint72 rateX64) {
        if (utilX56 >= self.maxUtilX56) {
            utilX56 = self.maxUtilX56 - 1;
        }

        uint72 calculatedRateX64 = uint72(self.betaX64 + self.invAlphaX120 / (self.maxUtilX56 - utilX56) - BETA_OFFSET);
        if (calculatedRateX64 > self.maxRateX64) {
            return self.maxRateX64;
        }
        return calculatedRateX64;
    }

    /// @notice Allows custom configs to be created with some safety checks.
    function initializeConfig(SmoothRateCurveConfig storage self, uint120 invAlphaX120, uint72 betaX64, uint64 maxUtilX56) internal {
        self.invAlphaX120 = invAlphaX120;
        self.betaX64 = betaX64 + BETA_OFFSET;
        self.maxUtilX56 = maxUtilX56;
    }

    /// @notice Creates config with 0.5% base rate, 12% target rate at 80% target util, and 100% max util. Max fee of 9100%.
    function initializeDefaultMoneyMarketConfig(SmoothRateCurveConfig storage self) internal {
        self.invAlphaX120 = 38215304878816319171133364334755840;
        self.betaX64 = 18008633901958949952;
        self.maxUtilX56 = 72057594037927936;
        self.maxRateX64 = 1678653710707569197056;
    }

    /// @notice Creates a config with 0% base rate, 0% target rate at 0% target util, and 50% max util.
    function initializeDefaultAMMConfig(SmoothRateCurveConfig storage self) internal {

    }
}
