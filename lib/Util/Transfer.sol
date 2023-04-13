// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import { Token, TokenImpl } from "Util/Token.sol";
import { IUniswapV3MintCallback, IUniswapV3SwapCallback } from "Interfaces/IUniV3.sol";
import { ITakerOpener, ITakerCloser } from "Interfaces/ITaker.sol";
import { AMMSpecLib } from "Interfaces/IResolution.sol";
import { SafeCast } from "Math/Cast.sol";

// @notice A convenience library for handling our transfer operations.
// This way the rest of the codebase doesn't have to think really carefully
// about safe transfer logic.
// @dev
library TransferLib {
    using TokenImpl for Token;
    using SafeCast for uint256;

    error MintInsufficientReceive(address token, uint256 expected, uint256 received);
    error SwapInsufficientReceive(address token, uint256 expected, uint256 received);
    error TakerInsufficientReceive(address token, uint256 expected, uint256 received);

    /// Receive quantities of both tokens through the Uniswap MintCallback interface.
    function mintReceive(
        Token tokenX, Token tokenY,
        uint256 x, uint256 y
    ) internal {
        bytes memory data = AMMSpecLib.serialize();

        uint256 beforeX = tokenX.balance();
        uint256 beforeY = tokenY.balance();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(x, y, data);

        uint256 received = tokenX.balance() - beforeX;
        if (x > received) {
            revert MintInsufficientReceive(tokenX.addr(), x, received);
        }
        received = tokenY.balance() - beforeY;
        if (y > received) {
            revert MintInsufficientReceive(tokenY.addr(), y, received);
        }
    }

    /// Receive an amount of one token through the Uniswap SwapCallback interface.
    /// This is usually prefaced by sending the user an amount of another token.
    /// We report the sent amount and requested amount in the callback.
    /// @param isX Is the token we expect to receive x?
    /// @param x the amount of token x we either sent (if neg) or expect to receive (if pos).
    /// @param y the amount of token y we either sent (if neg) or expect to receive (if pos).
    /// @param data A bytes representation of the pool's construction salt. Used to validate this is the desired contract.
    /// For opening a position, the user sets this value and we pass it back to them.
    /// This way the user validates the pool is the one they expect.
    /// For closing a position, the resolver validates the pool, but chooses and
    /// validates the position in other ways.
    function swapReceive(
        Token token,
        bool isX,
        uint256 x, uint256 y,
        bytes calldata data
    ) internal {
        // We if send more than 2^255-1 of a token we just revert.
        int256 iX = x.toInt256();
        int256 iY = y.toInt256();

        uint256 before = token.balance();
        uint256 amount;
        if (isX) {
            amount = x;
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(iX, -iY, data);
        } else {
            amount = y;
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(-iX, iY, data);
        }
        uint256 received = token.balance() - before; // after is a reserved keyword
        if (received < amount) {
            revert SwapInsufficientReceive(token.addr(), amount, received);
        }
    }

    /// Expect receipt of a certain amount of tokens while possibly providing some tokens
    /// when opening a taker position.
    /// @param data A bytes representation of the pool's construction salt. Used to validate this is the desired contract.
    /// For opening a position, the user sets this value and we pass it back to them.
    /// This way the user validates the pool is the one they expect.
    /// For closing a position, the resolver validates the pool, but chooses and
    /// validates the position in other ways.
    function takerOpenSwapReceive(
        Token token,
        bool isX,
        uint256 x, uint256 y,
        bytes calldata data
    ) internal {
        // We if send more than 2^255-1 of a token we just revert.
        int256 iX = x.toInt256();
        int256 iY = y.toInt256();

        uint256 before = token.balance();
        uint256 amount;
        if (isX) {
            amount = x;
            ITakerOpener(msg.sender).takerOpenSwapCallback(iX, -iY, data);
        } else {
            amount = y;
            ITakerOpener(msg.sender).takerOpenSwapCallback(-iX, iY, data);
        }
        uint256 received = token.balance() - before; // after is a reserved keyword
        if (received < amount) {
            revert TakerInsufficientReceive(token.addr(), amount, received);
        }
    }

    /// When closing a Taker position, we expect receipt of one token, and possibly receipt
    /// or transfer of the other.
    /// @param resolver Unlike other CBs, this is for closing and must be directed at the Resolver contract.
    /// @param x Send x if negative, otherwise expect receipt of x.
    /// @param y Send y if negative, otherwise expect receipt of y.
    function takerExerciseReceive(
        address resolver,
        Token tokenX,
        Token tokenY,
        int256 x, int256 y,
        bytes calldata instructions
    ) internal {
        if (x < 0) {
            tokenX.transfer(msg.sender, uint256(-x));
        } else if (y < 0) {
            tokenY.transfer(msg.sender, uint256(-y));
        }
        // They won't both be negative.

        bytes memory data = AMMSpecLib.serialize();

        // Request what we need.
        uint256 xBefore;
        uint256 yBefore;
        if (x > 0) xBefore = tokenX.balance();
        if (y > 0) yBefore = tokenY.balance();
        ITakerCloser(resolver).takerCloseSwapCallback(x, y, data, instructions);
        if (x > 0) {
            uint256 xAfter = tokenX.balance();
            if (xAfter >= xBefore + uint256(x))
                revert TakerInsufficientReceive(tokenX.addr(), uint256(x), xAfter - xBefore);
        }
        if (y > 0) {
            uint256 yAfter = tokenY.balance();
            if (yAfter >= yBefore + uint256(y))
                revert TakerInsufficientReceive(tokenY.addr(), uint256(y), yAfter - yBefore);
        }
    }
}
