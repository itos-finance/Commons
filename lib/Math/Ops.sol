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

    uint256 constant SHIFT = 1 << 96;

    error Q64X96Overflow(uint160 a, uint256 b);

    /// Multiply an X96 precision number by an arbitrary uint256 number.
    /// Returns with the same precision as b.
    /// The result takes up 256 bits. Will error on overflow.
    function mul(uint160 a, uint256 b, bool roundUp) internal pure returns(uint256 res) {
        (uint256 bot, uint256 top) = FullMath.mul512(a, b);
        if ((top >> 96) > 0) {
            revert Q64X96Overflow(a, b);
        }
        assembly {
            res := add(shr(96, bot), shl(160, top))
        }
        if (roundUp && (bot % SHIFT > 0)) {
            res += 1;
        }
    }

    /// Same as the regular mul but without checking for overflow
    function unsafeMul(uint160 a, uint256 b, bool roundUp) internal pure returns(uint256 res) {
        (uint256 bot, uint256 top) = FullMath.mul512(a, b);
        assembly {
            res := add(shr(96, bot), shl(160, top))
        }
        if (roundUp) {
            uint256 modby = SHIFT;
            assembly {
                res := add(res, gt(mod(bot, modby), 0))
            }
        }
    }

    /// Divide a uint160 by a Q64X96 number.
    /// Returns with the same precision as num.
    /// @dev uint160 is chosen because once the 96 bits of precision are cancelled out,
    /// the result is at most 256 bits.
    function div(uint160 num, uint160 denom, bool roundUp)
    internal pure returns (uint256 res) {
        uint256 fullNum = uint256(num) << PRECISION;
        res = fullNum / denom;
        if (roundUp) {
            assembly {
                res := add(res, gt(fullNum, mul(res, denom)))
            }
        }
    }
}

library X96 {
    uint256 constant PRECISION = 96;
    uint256 constant SHIFT = 1 << 96;
}

library X128 {
    uint256 constant PRECISION = 128;

    uint256 constant SHIFT = 1 << 128;

    /// Multiply a 256 bit number by a 128 bit number. Either of which is X128.
    /// @dev This rounds results down.
    function mul256(uint128 a, uint256 b) internal pure returns (uint256) {
        (uint256 bot, uint256 top) = FullMath.mul512(a, b);
        unchecked {
            return (bot >> 128) + (top << 128);
        }
    }

    /// Multiply a 256 bit number by a 128 bit number. Either of which is X128.
    /// @dev This rounds results up.
    function mul256RoundUp(uint128 a, uint256 b) internal pure returns (uint256 res) {
        (uint256 bot, uint256 top) = FullMath.mul512(a, b);
        uint256 modmax = SHIFT;
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
        unchecked {
            bot = (_bot >> 128) + (_top << 128);
            top = _top >> 128;
        }
    }

    /// Multiply a 256 bit number by a 256 bit number, either of which is X128, to get 384 bits.
    /// @dev This rounds results up.
    /// @return bot The bottom 256 bits of the result.
    /// @return top The top 128 bits of the result.
    function mul512RoundUp(uint256 a, uint256 b) internal pure returns (uint256 bot, uint256 top) {
        (uint256 _bot, uint256 _top) = FullMath.mul512(a, b);
        uint256 modmax = SHIFT;
        assembly {
            bot := add(add(shr(128, _bot), shl(128, top)), gt(mod(_bot, modmax), 0))
            top := shr(128, _top)
        }
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

library U256Ops {
    function add(uint256 self, int256 other) public pure returns (uint256) {
        if (other >= 0) {
            return self + uint256(other);
        } else {
            return self - uint256(-other);
        }
    }

    function sub(uint256 self, uint256 other) public pure returns (int256) {
        if (other >= self) {
            uint256 temp = other - self;
            // Yes technically the max should be -type(int256).max but that's annoying to
            // get right and cheap for basically no benefit.
            require(temp <= uint256(type(int256).max));
            return -int256(temp);
        } else {
            uint256 temp = self - other;
            require(temp <= uint256(type(int256).max));
            return int256(temp);
        }
    }
}
