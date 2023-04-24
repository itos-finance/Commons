// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import { IERC173 } from "ERC/interfaces/IERC173.sol";
import { AdminLib } from "Util/Admin.sol";

contract AdminFacet is IERC173 {
    function transferOwnership(address _newOwner) external override {
        AdminLib.reassignOwner(_newOwner);
    }

    function owner() external override view returns (address owner_) {
        owner_ = AdminLib.getOwner();
    }
}
