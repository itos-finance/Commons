// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.12; // For string concat

import {Test} from "forge-std/Test.sol";

/**
 * ForkableTests rely on a json file that holds key value pairs of addresses of interest.
 * Those addresses can be fetched by name with the getAddr function.
 * This is used so we can run unittests either on forked addresses or without forking.
 * Thus reproductions of deployed errors can be debugged quickly and then converted into long-standing unittests.
 * And vice-versa, a unittest can be run on deployed contracts to periodically validate invariants.
 *
 * To use, instead of using setUp to set up the test, users can optionally fill in:
 * 1. preSetup/postSetup for transactions that always need to be called before and after deploy/fork setups.
 * 2. deploySetup for setting up the test when not forking from deployed addresses.
 * 3. forkSetup for an transactions they would like to call on the forked addresses outside
 * of the context of the unittests.
 *
 * When forking, your .env file MUST include DEPLOYED_ADDRS_PATH as a path from project root, which points
 * to the json file of deployed addresses. If you are not ready to test with forking, the path is not
 * necessary.
 */

contract ForkableTest is Test {
    string private _loadedJson;
    address private _deployer;

    /* Interface Overrides */
    function preSetup() internal virtual {}
    function deploySetup() internal virtual {}
    function forkSetup() internal virtual {}
    function postSetup() internal virtual {}

    /* Utility functions to be called by child classes */

    // How child classes interact with the fork addresses
    function getAddr(string memory key) internal view returns (address) {
        return vm.parseJsonAddress(_loadedJson, string.concat(".", key));
    }

    // Fetch the public key of the deployer
    function deployer() internal view returns (address) {
        return _deployer;
    }

    /* Json Internals */
    function loadJsonFile() internal {
        string memory pathToAddrs = vm.envString("DEPLOYED_ADDRS_PATH");
        string memory projectRoot = string.concat(vm.projectRoot(), "/");
        string memory jsonPath = string.concat(projectRoot, pathToAddrs);
        _loadedJson = vm.readFile(jsonPath);
    }

    /* Setup */
    function setUp() public {
        // Every call should come from the deployer due to permissions
        _deployer = vm.envOr("DEPLOYER_PUBLIC_KEY", address(this));
        vm.startBroadcast(_deployer);

        try vm.activeFork() returns (uint256) {
            _forkSetup();
        } catch {
            _deploySetup();
        }
    }

    function _deploySetup() internal {
        preSetup();
        deploySetup();
        postSetup();
    }

    function _forkSetup() internal {
        preSetup();
        loadJsonFile();
        forkSetup();
        postSetup();
    }
}