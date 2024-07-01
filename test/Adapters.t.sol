// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {UniswapV3Adapter} from "../src/adapters/uniswap/UniswapV3Adapter.sol";

contract AdaptersTest is PRBTest, StdCheats {
    function testFetchUniV3Position() public {
        UniswapV3Adapter adapter = new UniswapV3Adapter();
        adapter.availablePositions(address(0x4b4a9E128f6F709AA850696Bd3e501db5E23E3c0));
    }
}
