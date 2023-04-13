// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

/// @notice A classic concurrency lock
/// @dev This is a struct because we want to operate on this in storage so it gets
/// shared across calls into the contract.
struct Mutex {
    bool locked; // Defaults to 0 (false).
}

library MutexImpl {
    error MutexContention();
    // Somewhere in the code, it is possible to unlock twice. This means someone might be
    // able to exploit by sneaking a lock in between the two unlocks.
    error DoubleUnlock();

    function lock(Mutex storage self) internal {
        if (self.locked) {
            revert MutexContention();
        }
        self.locked = true;
    }

    function unlock(Mutex storage self) internal {
        if (!self.locked) {
            revert DoubleUnlock();
        }
        self.locked = false;
    }

    function isLocked(Mutex storage self) internal view returns (bool) {
        return self.locked;
    }
}

library MutexLib {
    bytes32 constant MUTEX_STORAGE_POSITION = keccak256("v4.mutex.diamond.storage");

    function mutexStorage() internal pure returns (Mutex storage m) {
        bytes32 position = MUTEX_STORAGE_POSITION;
        assembly {
            m.slot := position
        }
    }
}

contract Mutexed {
    using MutexImpl for Mutex;

    /// Modifier for a global locking mechanism.
    /// @dev We can explore taking in an arg to specify one of many locks if necessary.
    modifier mutexLocked {
        Mutex storage m = MutexLib.mutexStorage();
        m.lock();
        _;
        m.unlock();
    }
}
