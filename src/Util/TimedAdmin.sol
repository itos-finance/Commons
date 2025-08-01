// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import { BaseAdminFacet } from "../Util/Admin.sol";
import { Timed } from "../Util/Timed.sol";
import { AdminLib } from "../Util/Admin.sol";
import { IERC173 } from "../ERC/interfaces/IERC173.sol";

// A base class for admin facets that obey some opinionated time-gating.
abstract contract TimedAdminFacet is BaseAdminFacet {
    uint256 private constant OWNER_USE_ID = uint256(keccak256("Itos.timed.admin.owner.useid.20250610"));

    /// Return the useId for admin rights to use in the Timed library.
    /// @param add True if we want to add rights. False if we want to remove them.
    function getRightsUseID(bool add) internal view virtual returns (uint256);

    /// The delay rights have to wait before being accepted.
    /// @param add True if we want to add rights. False if we want to remove them.
    function getDelay(bool add) public view virtual returns (uint32);

    /* Owner changes */

    function transferOwnership(address _newOwner) external virtual override {
        AdminLib.validateOwner();
        Timed.memoryPrecommit(OWNER_USE_ID, abi.encode(_newOwner));
    }

    /// The pending owner can accept their ownership rights.
    function acceptOwnership() external virtual override {
        bytes memory entry = Timed.fetchPrecommit(OWNER_USE_ID, getDelay(true));
        address _newOwner = abi.decode(entry, (address));
        AdminLib.reassignOwner(_newOwner);
        AdminLib.acceptOwnership();
        emit IERC173.OwnershipTransferred(AdminLib.getOwner(), msg.sender);
    }

    /* Rights changes */

    /// Submit rights in a Timed way to be accepted at a later time.
    /// @param add True if we want to add these rights. False if we want to remove them.
    function submitRights(address newAdmin, uint256 rights, bool add) external {
        AdminLib.validateOwner();
        Timed.memoryPrecommit(getRightsUseID(add), abi.encode(newAdmin, rights));
    }

    /// The owner can accept these rights changes.
    function acceptRights() external {
        AdminLib.validateOwner();
        bytes memory entry = Timed.fetchPrecommit(getRightsUseID(true), getDelay(true));
        (address admin, uint256 newRights) = abi.decode(entry, (address, uint256));
        AdminLib.register(admin, newRights);
    }

    /// Owner removes admin rights from an address in a time gated manner.
    function removeRights() external {
        AdminLib.validateOwner();
        bytes memory entry = Timed.fetchPrecommit(getRightsUseID(false), getDelay(false));
        (address admin, uint256 rights) = abi.decode(entry, (address, uint256));
        AdminLib.deregister(admin, rights);
    }

    /// The owner can veto rights additions.
    /// @param add Whether the veto is for an add to rights or a remove.
    function vetoRights(bool add) external {
        AdminLib.validateOwner();
        Timed.deleteEntry(getRightsUseID(add));
    }
}
