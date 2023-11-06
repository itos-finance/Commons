// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.17;

import { console2 } from "forge-std/console2.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { RFTLib, RFTPayer, IRFTPayer, IERC165} from "@Commons/Util/RFT.sol";
import { MintableERC20 } from "@Commons/ERC/ERC20.u.sol";
import { ContractLib } from "@Commons/Util/Contract.sol";
import { Auto165 } from "@Commons/ERC/Auto165.sol";

contract MockRFTPayer is RFTPayer, Auto165 {
    function tokenRequestCB(
        address[] calldata tokens,
        int256[] calldata requests,
        bytes calldata
    ) external {
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (requests[i] > 0) {
                MintableERC20(tokens[i]).mint(msg.sender, uint256(requests[i]));
            }
        }
    }
}

/// @dev We need this contract to run the revert calls due to a Foundry bug
/// where if the testing contract reverts the test prematurely stops.
contract RFTTestHelper {
    address public token;
    constructor(address _token) {
        token = _token;
    }

    function request(address payer, int256 amount) external {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory amounts = new int256[](1);
        amounts[0] = amount;
        bytes memory nulldata;
        RFTLib.request(payer, tokens, amounts, nulldata);
    }

    function requestOrTransfer(address payer, int256 amount) external {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory amounts = new int256[](1);
        amounts[0] = amount;
        bytes memory nulldata;
        RFTLib.requestOrTransfer(payer, tokens, amounts, nulldata);
    }
}

contract RFTTest is PRBTest, StdCheats {
    MintableERC20 public token;
    address public human;
    address public payer;
    RFTTestHelper public helper;

    function setUp() public {
        token = new MintableERC20("eth", "ETH");
        human = address(0x1337133713371337);
        payer = address(new MockRFTPayer());
        helper = new RFTTestHelper(address(token));
    }

    function testRequests() public {
        token.mint(human, 1 ether);

        // Request
        // request from human fails
        vm.expectRevert(ContractLib.NotAContract.selector);
        helper.request(human, 1);
        // But contract succeeds
        helper.request(payer, 1);
        // This contract fails with EVM Error
        vm.expectRevert();
        helper.request(address(this), 1);

        // Request or Transfer
        // Give approval
        vm.prank(human);
        token.approve(address(helper), 1 ether);
        helper.requestOrTransfer(human, 1 gwei);
        // payer still works
        helper.requestOrTransfer(payer, 1 gwei);
        // This contract fails.
        vm.expectRevert();
        helper.requestOrTransfer(address(this), 1 gwei);

        // Request or fail
        assertFalse(RFTLib.isSupported(human));
        assertTrue(RFTLib.isSupported(payer));
    }
}