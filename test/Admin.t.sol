// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import { console2 } from "forge-std/console2.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { AdminLib, AdminLevel } from "Util/Admin.sol";

contract AdminTest is PRBTest, StdCheats {
    AdminTestHelper public helper;

    function setUp() public {
        AdminLib.initOwner(msg.sender);
        helper = new AdminTestHelper(this);
    }

    function requireValidation(uint8 level) external view {
        AdminLib.validateLevel(level);
    }

    function testOwner() public {
        assertEq(AdminLib.getOwner(), msg.sender);
        AdminLib.validateOwner();

        // Test that we also validate as any other level
        AdminLib.validateLevel(3);
        AdminLib.validateLevel(AdminLevel.Two);
        AdminLib.validateLevel(AdminLevel.One);
        AdminLib.validateLevel(0);

        // We can't reinitialize
        vm.expectRevert(abi.encodeWithSelector(AdminLib.CannotReinitializeOwner.selector, msg.sender));

        AdminLib.initOwner(address(this));
        // But we can reassign
        AdminLib.reassignOwner(address(this));

        // Verify we're not the owner anymore
        vm.expectRevert(AdminLib.InsufficientCredentials.selector);
        AdminLib.validateOwner();

        assertEq(AdminLib.getOwner(), address(this));
    }

    function testRegistration() public {
        assertEq(uint8(AdminLib.getAdminLevel(address(helper))), 0);

        AdminLib.register(address(helper), 2);
        assertEq(uint8(AdminLib.getAdminLevel(address(helper))), 2);
        helper.validateAs(2);
        helper.validateAs(1);

        vm.expectRevert(AdminLib.InsufficientCredentials.selector);
        helper.validateAs(3);

        // We can downgrade admin levels
        AdminLib.register(address(helper), 1);
        assertEq(uint8(AdminLib.getAdminLevel(address(helper))), 1);
        vm.expectRevert(AdminLib.InsufficientCredentials.selector);
        helper.validateAs(2);

        // And upgrade
        AdminLib.register(address(helper), 3);
        assertEq(uint8(AdminLib.getAdminLevel(address(helper))), 3);
        helper.validateAs(3);

        // And remove entirely
        AdminLib.deregister(address(helper));
        vm.expectRevert(AdminLib.InsufficientCredentials.selector);
        helper.validateAs(1);

        assertEq(uint8(AdminLib.getAdminLevel(address(helper))), 0);
    }
}

contract AdminTestHelper {
    AdminTest public tester;

    constructor(AdminTest _tester) {
        tester = _tester;
    }

    function validateAs(uint8 num) public view {
        tester.requireValidation(num);
    }
}
