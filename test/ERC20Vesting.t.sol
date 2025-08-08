// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20Vesting} from "../contracts/ERC20Vesting.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock contract to test the abstract ERC20Vesting contract
contract ERC20VestingMock is ERC20Vesting {
    constructor(uint64 vestingDuration_) ERC20Vesting(vestingDuration_) ERC20("Vesting Token", "VTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    // Expose the internal _withdraw function for testing
    function withdraw(address user, uint256 userVestingId) public returns (uint256, uint256) {
        return _withdraw(user, userVestingId);
    }

    // Override the transfer function to allow token transfers for testing purposes
    function transfer(address to, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }
}

contract ERC20VestingTest is Test {
    ERC20VestingMock public vestingToken;
    uint64 public constant VESTING_DURATION = 365 days;

    address public user1 = vm.addr(1);
    address public user2 = vm.addr(2);

    function setUp() public {
        vestingToken = new ERC20VestingMock(VESTING_DURATION);
        vestingToken.mint(user1, 1000e18);
    }

    function test_InitialState() public {
        assertEq(vestingToken.vestingDuration(), VESTING_DURATION, "Incorrect vesting duration");
        assertEq(vestingToken.totalVestingBalance(), 0, "Initial total vesting balance should be zero");
        assertEq(vestingToken.balanceOf(user1), 1000e18, "Incorrect initial balance for user1");
        assertEq(vestingToken.vestingBalanceOf(user1), 0, "Initial vesting balance for user1 should be zero");
    }

    function test_Vest() public {
        uint256 vestAmount = 100e18;
        vm.prank(user1);
        uint256 userVestingId = vestingToken.vest(vestAmount);

        assertEq(userVestingId, 0, "Incorrect userVestingId");
        assertEq(vestingToken.totalVestingBalance(), vestAmount, "Incorrect total vesting balance");
        assertEq(vestingToken.vestingBalanceOf(user1), vestAmount, "Incorrect vesting balance for user1");
        assertEq(vestingToken.getVestingLength(user1), 1, "Incorrect vesting length for user1");

        (uint256 vestedAmount, uint64 startTime, , ) = vestingToken.getUserVestingSchedule(user1, 0);
        assertEq(vestedAmount, vestAmount, "Incorrect vested amount in schedule");
        assertEq(startTime, block.timestamp, "Incorrect start time in schedule");
    }

    function test_Withdraw_FullyVested() public {
        uint256 vestAmount = 100e18;
        vm.prank(user1);
        vestingToken.vest(vestAmount);

        // Warp time to after the vesting period
        vm.warp(block.timestamp + VESTING_DURATION + 1);

        (uint256 unlockedAmount, uint256 lockedAmount) = vestingToken.withdraw(user1, 0);

        assertEq(unlockedAmount, vestAmount, "Unlocked amount should be the full vested amount");
        assertEq(lockedAmount, 0, "Locked amount should be zero");
        assertEq(vestingToken.totalVestingBalance(), 0, "Total vesting balance should be zero after withdrawal");
        assertEq(vestingToken.vestingBalanceOf(user1), 0, "User's vesting balance should be zero after withdrawal");
        assertEq(vestingToken.getVestingLength(user1), 0, "User's vesting length should be zero after withdrawal");
    }

    function test_Withdraw_PartiallyVested() public {
        uint256 vestAmount = 100e18;
        vm.prank(user1);
        vestingToken.vest(vestAmount);

        // Warp time to the middle of the vesting period
        vm.warp(block.timestamp + VESTING_DURATION / 2);

        (uint256 vestedAmount, , uint256 unlockedAmount, uint256 lockedAmount) = vestingToken.getUserVestingSchedule(user1, 0);
        
        assertTrue(unlockedAmount > 0, "Unlocked amount should be greater than zero");
        assertTrue(lockedAmount > 0, "Locked amount should be greater than zero");
        assertEq(vestedAmount, vestAmount, "Vested amount should remain the same");
        assertApproxEqAbs(unlockedAmount, vestAmount / 2, 1, "Unlocked amount should be approx half");
        assertApproxEqAbs(lockedAmount, vestAmount / 2, 1, "Locked amount should be approx half");
    }

    function test_VestingStatus() public {
        uint256 vestAmount = 100e18;
        uint64 startTime = uint64(block.timestamp);
        
        // Immediately after vesting starts
        (uint256 unlocked, uint256 locked) = vestingToken.vestingStatus(vestAmount, startTime);
        assertTrue(unlocked < 1e12, "Unlocked amount should be negligible at the start"); // small tolerance for 1 block time
        assertApproxEqAbs(locked, vestAmount, 1e12, "Locked amount should be almost the full amount at the start");

        // After vesting period has passed
        vm.warp(block.timestamp + VESTING_DURATION);

        (unlocked, locked) = vestingToken.vestingStatus(vestAmount, startTime);
        assertEq(unlocked, vestAmount, "Unlocked amount should be full amount after vesting period");
        assertEq(locked, 0, "Locked amount should be zero after vesting period");
    }

    function test_Transfer() public {
        uint256 transferAmount = 100e18;
        vm.prank(user1);
        vestingToken.transfer(user2, transferAmount);
        assertEq(vestingToken.balanceOf(user1), 900e18, "user1 balance is incorrect after transfer");
        assertEq(vestingToken.balanceOf(user2), transferAmount, "user2 balance is incorrect after transfer");
    }

    function test_Fail_Vest_InsufficientBalance() public {
        uint256 vestAmount = 2000e18; // More than user1's balance
        vm.prank(user1);
        vm.expectRevert("ERC20Vesting: Insufficient Balance");
        vestingToken.vest(vestAmount);
    }

    function test_Fail_Withdraw_InvalidScheduleId() public {
        vm.prank(user1);
        vm.expectRevert("ERC20Vesting: Invalid userVestingId");
        vestingToken.withdraw(user1, 0); // No vesting schedule exists yet
    }

    function test_Fail_GetUserVestingSchedule_InvalidId() public {
        vm.expectRevert("ERC20Vesting: Invalid userVestingId");
        vestingToken.getUserVestingSchedule(user1, 0);
    }

    function test_Fail_GetVestingSchedule_InvalidId() public {
        vm.expectRevert("ERC20Vesting: Invalid Schedule");
        vestingToken.getVestingSchedule(0);
    }
}
