// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import { BaseAdminFacet } from "Util/Admin.sol";
import { Timed } from "Util/Timed.sol";
import { AdminLib } from "Util/Admin.sol";

// A base class for admin facets that obey some opinionated time-gating.
abstract contract TimedAdminFacet is BaseAdminFacet {
    /// Return the useId to use in the Timed library.
    function getRightsUseID() public view virtual returns (uint256);

    /// The delay rights have to wait before being accepted.
    function getDelay() public view virtual returns (uint32);

    /// Submit rights in a Timed way to be accepted at a later time.
    function submitRights(address newAdmin, uint256 rights) external {
        AdminLib.validateOwner();
        Timed.memoryPrecommit(getRightsUseID(), abi.encode(newAdmin, rights));
    }

    /// The owner can accept these rights additions.
    function acceptRights() external {
        AdminLib.validateOwner();
        bytes memory entry = Timed.fetchPrecommit(getRightsUseID(), getDelay());
        (address admin, uint256 newRights) = abi.decode(entry, (address, uint256));
        AdminLib.register(admin, newRights);
    }

    /// The owner can veto rights additions.
    function vetoRights() external {
        AdminLib.validateOwner();
        Timed.deleteEntry(getRightsUseID());
    }

    /// Remove admin rights from an address. No time delay on this.
    function removeRights(address admin, uint256 rights) external {
        AdminLib.validateOwner();
        AdminLib.deregister(admin, rights);
    }
}
