// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import { X96 } from "./Ops.sol";
import { TickIndex, TickIndexImpl } from "Ticks/Tick.sol";

/**
 * @author Terence An
 * @notice Math functions for computations related to liquidity
 * @dev I rashly threw this together, avoiding Uniswaps implementation due to their license.
 * When their license expires in April 2023, maybe we can copy it.
 **/
library LiqMath {
    using X96 for uint160;
    using TickIndexImpl for TickIndex;

    /// Calculate the x and y required to add this liquidity to the Maker pool.
    function calcMakerAmounts(
        TickIndex current,
        TickIndex low,
        TickIndex high,
        uint128 addedLiq,
        bool roundUp
    ) internal pure returns(uint256 x, uint256 y) {
        if (current.isLT(low)) {
            y = 0;
            x = calcX(addedLiq, low.toRecipSqrtPrice(), high.toRecipSqrtPrice(), roundUp);
        } else if (high.isLT(current)) {
            x = 0;
            y = calcY(addedLiq, low.toSqrtPrice(), high.toSqrtPrice(), roundUp);
        } else {
            x = calcX(addedLiq, current.toRecipSqrtPrice(), high.toRecipSqrtPrice(), roundUp);
            y = calcY(addedLiq, low.toRecipSqrtPrice(), current.toRecipSqrtPrice(), roundUp);
        }
    }

    /// Calculate the x and y required to add this liquidity to the Taker pool.
    function calcTakerAmounts(
        TickIndex current,
        TickIndex low,
        TickIndex high,
        uint128 addedLiq,
        bool roundUp
    ) internal pure returns(uint256 x, uint256 y) {
        if (current.isLT(low)) {
            x = 0;
            y = calcY(addedLiq, low.toSqrtPrice(), high.toSqrtPrice(), roundUp);
        } else if (high.isLT(current)) {
            x = calcX(addedLiq, low.toRecipSqrtPrice(), high.toRecipSqrtPrice(), roundUp);
            y = 0;
        } else {
            x = calcX(addedLiq, low.toRecipSqrtPrice(), current.toRecipSqrtPrice(), roundUp);
            y = calcY(addedLiq, current.toRecipSqrtPrice(), high.toRecipSqrtPrice(), roundUp);
        }
    }

    /// @notice Calculate the x and y required to open an unconcentrated maker position.
    /// @dev we always round up.
    function calcWideMakerAmounts(TickIndex current, uint128 addedLiq, bool roundUp) internal pure returns (uint256 x, uint256 y) {
        x = current.toRecipSqrtPrice().mul(addedLiq, roundUp);
        y = current.toSqrtPrice().mul(addedLiq, roundUp);
    }

    /// Calculate x for a variety of situations using the formula:
    /// x = L (1 / sqrt(lowP) - 1 / sqrt(highP))
    function calcX(
        uint128 liq,
        uint160 lowSPriceRecipX96,
        uint160 highSPriceRecipX96,
        bool roundUp
    ) internal pure returns(uint256 x) {
        uint160 diff = lowSPriceRecipX96 - highSPriceRecipX96;
        x = diff.mul(liq, roundUp);
    }

    /// Calculate y for a variety of situations using the formula:
    /// y = L (sqrt(highP) - sqrt(lowP))
    function calcY(
        uint128 liq,
        uint160 lowSPriceX96,
        uint160 highSPriceX96,
        bool roundUp
    ) internal pure returns(uint256 y) {
        uint160 diff = highSPriceX96 - lowSPriceX96;
        y = diff.mul(liq, roundUp);
    }



}
