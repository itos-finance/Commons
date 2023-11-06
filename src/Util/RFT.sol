// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.17;

import {Auto165Lib, IERC165} from "@Commons/ERC/Auto165.sol";
import {ContractLib} from "@Commons/Util/Contract.sol";
import {TransferHelper} from "@Commons/Util/TransferHelper.sol";

/* Interfaces to handle requests for tokens */
interface IRFTPayer {
    /**
     * @notice Called by other contracts requesting this contract for tokens.
     * @param tokens A list of tokens corresponding to each request.
     * @param requests A list of tokens amounts for each token.
     * Positive if requested, negative if paid to this contract.
     * @param data Additional information passed by the callee.
     */
    function tokenRequestCB(
        address[] calldata tokens,
        int256[] calldata requests,
        bytes calldata data) external;
}

/* Utilities for handling requests for tokens */

/// Contract that supports paying RFTs
abstract contract RFTPayer is IRFTPayer {
    constructor() {
        Auto165Lib.addSupport(type(IRFTPayer).interfaceId);
    }
}

library RFTLib {
    /**
     * @notice Request tokens and indicate payments to a payer contract.
     * @dev We simply INDICATE payments. The function caller is expect to actually do any payment transfers.
     */
    function request(address payer, address[] memory tokens, int256[] memory amounts, bytes memory data) internal {
        ContractLib.assertContract(payer);
        IRFTPayer(payer).tokenRequestCB(tokens, amounts, data);
    }

    /**
     * @notice Request tokens and indicate payments to a payer contract, or simply transfer is payer is not a contract.
     * This is the most common use case.
     * @dev We simply INDICATE payments. The function caller is expect to actually do any payment transfers.
     */
    function requestOrTransfer(
        address payer,
        address[] memory tokens,
        int256[] memory amounts,
        bytes memory data
    ) internal {
        if (ContractLib.isContract(payer)) {
            IRFTPayer(payer).tokenRequestCB(tokens, amounts, data);
        } else {
            for (uint256 i = 0; i < tokens.length; ++i) {
                if (amounts[i] > 0) {
                    TransferHelper.safeTransferFrom(tokens[i], payer, address(this), uint256(amounts[i]));
                }
            }
        }
    }

    /**
     * @notice Check if a contract supports RFTs through ERC165.
     * @dev Will revert if payer is contract but doesn't support ERC165.
     * @return support True if RFTs are supported by the payer.
     */
    function isSupported(
        address payer
    ) internal view returns (bool support) {
        return (ContractLib.isContract(payer) && IERC165(payer).supportsInterface(type(IRFTPayer).interfaceId));
    }
}