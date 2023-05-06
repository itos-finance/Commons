// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { FullMath } from "Math/FullMath.sol";

library X32 {
    // Multiply two 256 bit numbers to a 512 number, but one of the 256's is X32.
    function mul512(uint256 a, uint256 b)
    internal pure returns (uint256 bot, uint256 top) {
        (uint256 rawB, uint256 rawT) = FullMath.mul512(a, b);
        bot = (rawB >> 32) + (rawT << 224);
        top = rawT >> 32;
    }
}

library X64 {
    // Multiply two 256 bit numbers to a 512 number, but one of the 256's is X32.
    function mul512(uint256 a, uint256 b)
    internal pure returns (uint256 bot, uint256 top) {
        (uint256 rawB, uint256 rawT) = FullMath.mul512(a, b);
        bot = (rawB >> 64) + (rawT << 192);
        top = rawT >> 64;
    }
}

/**
 * @notice Utility for Q64.96 operations
 **/
library Q64X96 {

    uint256 constant PRECISION = 96;

    uint256 constant MASK64 = uint256(type(uint64).max);

    /// Multiply an X96 precision number by an arbitrary uint128 number.
    /// Returns with the same precision as b.
    /// The result takes up 196 bits.
    function mul(uint160 a, uint128 b, bool roundUp) internal pure returns(uint256) {
        uint256 m = mulX64(a, b);
        uint256 round = (roundUp && (m & MASK64 != 0)) ? 1 : 0;
        unchecked { return (m >> 64) + round; }
    }

    /// Mutliple an X96 precision number by an arbitrary uint128 number.
    /// Returns with precision X64
    /// The result takes up the full 256 bits.
    function mulX64(uint160 a, uint128 b) internal pure returns(uint256) {
        uint256 num = uint256(a);
        uint256 other = uint256(b) << PRECISION;
        (uint256 bot, uint256 top) = FullMath.mul512(num, other);
        // We know at most 160 + 96 + 128 = 384 bits are set.
        // Drop 96 * 2 - 64 = 128 bits to keep 64 precision.
        unchecked { return (top << 128) + (bot >> 128); }
    }

    // Divide a uint128 by a Q64X96 number.
    // Returns with the same precision as num.
    // The result can at most take 224 bits.
    function div(uint128 num, uint160 denom, bool roundUp)
    internal pure returns (uint256 res) {
        uint256 fullNum = uint256(num) << PRECISION;
        res = fullNum / denom;
        if (roundUp && (res * denom < fullNum)) {
            res += 1;
        }
    }
}

library X96 {
    uint256 constant PRECISION = 96;
    uint256 constant SHIFT = 1 << 96;
}

library X128 {
    uint256 constant PRECISION = 128;

    uint256 constant MAX = type(uint128).max;

    /// Multiply a 256 bit number by a 128 bit number. Either of which is X128.
    /// @dev This rounds results down.
    function mul256(uint128 a, uint256 b) internal pure returns (uint256) {
        (uint256 bot, uint256 top) = FullMath.mul512(a, b);
        return (bot >> 128) + (top << 128);
    }

    /// Multiply a 256 bit number by a 128 bit number. Either of which is X128.
    /// @dev This rounds results up.
    function mul256RoundUp(uint128 a, uint256 b) internal pure returns (uint256 res) {
        (uint256 bot, uint256 top) = FullMath.mul512(a, b);
        uint256 modmax = MAX;
        assembly {
            res := add(add(shr(128, bot), shl(128, top)), gt(mod(bot, modmax), 0))
        }
    }

    /// Multiply a 256 bit number by a 256 bit number, either of which is X128, to get 384 bits.
    /// @dev This rounds results down.
    /// @return bot The bottom 256 bits of the result.
    /// @return top The top 128 bits of the result.
    function mul512(uint256 a, uint256 b) internal pure returns (uint256 bot, uint256 top) {
        (uint256 _bot, uint256 _top) = FullMath.mul512(a, b);
        bot = (_bot >> 128) + (_top << 128);
        top = _top >> 128;
    }
}

/// Convenience library for interacting with Uint128s by other types.
library U128Ops {

    function add(uint128 self, int128 other) public pure returns (uint128) {
        if (other >= 0) {
            return self + uint128(other);
        } else {
            return self - uint128(-other);
        }
    }

    function sub(uint128 self, int128 other) public pure returns (uint128) {
        if (other >= 0) {
            return self - uint128(other);
        } else {
            return self + uint128(-other);
        }
    }
}
