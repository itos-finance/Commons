// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import { console2 } from "forge-std/console2.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { ContractLib } from "Util/Contract.sol";

contract ContractLibTest is PRBTest, StdCheats {
    function testIsContract() public {
        assertTrue(ContractLib.isContract(address(this)));
        assertTrue(!ContractLib.isContract(address(0)));

        ContractLib.assertContract(address(this));
        vm.expectRevert(ContractLib.NotAContract.selector);
        ContractLib.assertContract(address(0));
    }
}
