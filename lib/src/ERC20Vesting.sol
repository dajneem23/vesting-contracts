// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract ERC20Vesting is Ownable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        address beneficiary;
        uint64 cliff;
        uint64 start;
        uint64 duration;
        uint32 revocable; // 0 = false, 1 = true
        uint256 amount;
    }

    VestingSchedule private _vestingSchedule;
    IERC20 private _token;
    uint256 private _released;

    event Released(uint256 amount);
    event Revoked();

    constructor(address owner) Ownable(owner) {}

    function initialize(VestingSchedule calldata schedule, address token) external onlyOwner {
        require(schedule.duration > 0, "Vesting: duration must be > 0");
        require(schedule.amount > 0, "Vesting: amount must be > 0");
        _vestingSchedule = schedule;
        _token = IERC20(token);
    }

    function releasable() public view returns (uint256) {
        return _vestedAmount() - _released;
    }

    function release() public {
        uint256 releasableAmount = releasable();
        require(releasableAmount > 0, "Vesting: no tokens to release");
        _released += releasableAmount;
        emit Released(releasableAmount);
        _token.safeTransfer(_vestingSchedule.beneficiary, releasableAmount);
    }

    function revoke() public onlyOwner {
        require(_vestingSchedule.revocable == 1, "Vesting: not revocable");
        uint256 releasableAmount = releasable();
        uint256 totalVested = _released + releasableAmount;
        uint256 refund = _vestingSchedule.amount - totalVested;
        _vestingSchedule.amount = totalVested;
        emit Revoked();
        _token.safeTransfer(owner(), refund);
    }

    function _vestedAmount() private view returns (uint256) {
        VestingSchedule memory schedule = _vestingSchedule;
        if (block.timestamp < schedule.cliff) {
            return 0;
        }
        if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.amount;
        }
        return (schedule.amount * (block.timestamp - schedule.start)) / schedule.duration;
    }

    function getVestingSchedule() public view returns (VestingSchedule memory) {
        return _vestingSchedule;
    }

    function released() public view returns (uint256) {
        return _released;
    }

    function token() public view returns (address) {
        return address(_token);
    }
}
