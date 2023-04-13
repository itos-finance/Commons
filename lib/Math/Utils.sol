// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

library MathUtils {

    function abs(int256 self) internal pure returns (int256) {
        return self >= 0 ? self : -self;
    }

}
