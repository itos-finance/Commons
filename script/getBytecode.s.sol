// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Diamond } from "src/Diamond.sol";


contract getBytecodeScript is Script {
    function run() public view {
        bytes memory initCode = type(Diamond).creationCode;
        console2.log(initCode.length);
    }
}
