// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import { IERC20Minimal } from "ERC/interfaces/IERC20Minimal.sol";
import { ContractLib } from "Util/Contract.sol";

type Token is address;

library TokenImpl {
    error TokenBalanceInvalid();
    error TokenTransferFailure();

    /// Wrap an address into a Token and verify it's a contract.
    // @dev It's important to verify addr is a contract before we
    // transfer to it or else it will be a false success.
    function make(address _addr) internal view returns (Token) {
        ContractLib.assertContract(_addr);
        return Token.wrap(_addr);
    }

    /// Unwrap into an address
    function addr(Token self) internal pure returns (address) {
        return Token.unwrap(self);
    }

    /// Query the balance of this token for the caller.
    function balance(Token self) internal view returns (uint256) {
        (bool success, bytes memory data) =
            addr(self).staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        if (!(success && data.length >= 32)) {
            revert TokenBalanceInvalid();
        }
        return abi.decode(data, (uint256));
    }

    /// Transfer this token from caller to recipient.
    function transfer(Token self, address recipient, uint256 amount) internal {
        if (amount == 0) return; // Short circuit

        (bool success, bytes memory data) =
            addr(self).call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, recipient, amount));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert TokenTransferFailure();
        }
    }
}
