// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.17;

import {console2} from "forge-std/console2.sol";
import {INonfungiblePositionManager} from "./INonfungiblePositionManager.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

/**
 * Adapted from https://github.com/Uniswap/docs/blob/main/examples/smart-contracts/LiquidityExamples.sol
 */
contract UniswapV3Adapter is IERC721Receiver {
    INonfungiblePositionManager public immutable nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    constructor() {}

    /// @notice Represents the deposit of an NFT
    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    struct PositionParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
    }

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;

    function availablePositions(address sender) external {
        uint256 bal = nonfungiblePositionManager.balanceOf(sender);
        console2.log("bal", bal);

        uint256 tokenId = nonfungiblePositionManager.tokenOfOwnerByIndex(sender, bal - 1);
        uint256 tokenId2 = nonfungiblePositionManager.tokenOfOwnerByIndex(sender, 1);

        (address token0, address token1, uint128 liquidity) = getPosition(tokenId);

        console2.log(token0, token1, liquidity);
    }

    function getPosition(uint256 tokenId) public view returns (address, address, uint128) {
        (,, address token0, address token1,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);

        return (token0, token1, liquidity);
    }

    /**
     * Passes the ownership of a lp to the protocol
     */
    function lend() external {
        // nonfungiblePositionManager.transfer(address(this), )
    }

    function burn(uint256 tokenId) external {
        nonfungiblePositionManager.burn(tokenId);
    }

    /// @notice Collects the fees associated with provided liquidity
    /// @dev The contract must hold the erc721 token before it can collect fees
    /// @param tokenId The id of the erc721 token
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collectAllFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {
        // Caller must own the ERC721 position, meaning it must be a deposit
        // set amount0Max and amount1Max to type(uint128).max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);

        // send collected fees back to owner
        _sendToOwner(tokenId, amount0, amount1);
    }

    /// @notice Transfers funds to owner of NFT
    /// @param tokenId The id of the erc721
    /// @param amount0 The amount of token0
    /// @param amount1 The amount of token1
    function _sendToOwner(uint256 tokenId, uint256 amount0, uint256 amount1) private {
        // get owner of contract
        address owner = deposits[tokenId].owner;

        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
        // send collected fees to owner
        // TransferHelper.safeTransfer(token0, owner, amount0);
        // TransferHelper.safeTransfer(token1, owner, amount1);
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    // Note that the operator is recorded as the owner of the deposited NFT
    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        require(msg.sender == address(nonfungiblePositionManager), "not a univ3 nft");
        _createDeposit(operator, tokenId);
        return this.onERC721Received.selector;
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (,, address token0, address token1,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        // set the owner and data for position
        deposits[tokenId] = Deposit({owner: owner, liquidity: liquidity, token0: token0, token1: token1});
    }
}
