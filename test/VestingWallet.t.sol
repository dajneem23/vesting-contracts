// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {VestingWalletMock} from "contracts/mocks/VestingWalletMock.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract VestingWalletTest is Test {
    VestingWalletMock public wallet;
    MockToken public token;

    address public beneficiary = vm.addr(1);
    uint64 public startTimestamp;
    uint64 public constant DURATION = 365 days;

    function setUp() public {
        startTimestamp = uint64(block.timestamp) + 100 days;
        wallet = new VestingWalletMock(beneficiary, startTimestamp, DURATION);
        token = new MockToken();
    }

    function test_InitialState() public {
        assertEq(wallet.owner(), beneficiary, "Incorrect beneficiary");
        assertEq(wallet.start(), startTimestamp, "Incorrect start timestamp");
        assertEq(wallet.duration(), DURATION, "Incorrect duration");
        assertEq(
            wallet.releasable(),
            0,
            "Initial releasable ETH should be zero"
        );
        assertEq(
            wallet.releasable(address(token)),
            0,
            "Initial releasable token should be zero"
        );
    }

    function test_ReceiveEth() public {
        uint256 amount = 1 ether;
        vm.deal(address(wallet), amount);
        assertEq(address(wallet).balance, amount, "Wallet did not receive ETH");
    }

    function test_ReleaseEth_FullyVested() public {
        uint256 amount = 1 ether;
        vm.deal(address(wallet), amount);

        vm.warp(startTimestamp + DURATION);

        uint256 releasableAmount = wallet.releasable();
        assertEq(releasableAmount, amount, "Releasable amount is incorrect");

        uint256 initialBalance = beneficiary.balance;
        vm.prank(beneficiary);
        wallet.release();
        assertEq(
            beneficiary.balance,
            initialBalance + amount,
            "Beneficiary did not receive ETH"
        );
        assertEq(wallet.released(), amount, "Released amount is incorrect");
    }

    function test_ReleaseEth_PartiallyVested() public {
        uint256 amount = 1 ether;
        vm.deal(address(wallet), amount);

        vm.warp(startTimestamp + DURATION / 2);

        uint256 releasableAmount = wallet.releasable();
        assertApproxEqAbs(
            releasableAmount,
            amount / 2,
            1,
            "Releasable amount is incorrect"
        );

        uint256 initialBalance = beneficiary.balance;
        vm.prank(beneficiary);
        wallet.release();
        assertApproxEqAbs(
            beneficiary.balance,
            initialBalance + amount / 2,
            1,
            "Beneficiary did not receive correct amount of ETH"
        );
        assertApproxEqAbs(
            wallet.released(),
            amount / 2,
            1,
            "Released amount is incorrect"
        );
    }

    function test_ReleaseERC20_FullyVested() public {
        uint256 amount = 1000e18;
        token.mint(address(wallet), amount);

        vm.warp(startTimestamp + DURATION);

        uint256 releasableAmount = wallet.releasable(address(token));
        assertEq(releasableAmount, amount, "Releasable amount is incorrect");

        uint256 initialBalance = token.balanceOf(beneficiary);
        vm.prank(beneficiary);
        wallet.release(address(token));
        assertEq(
            token.balanceOf(beneficiary),
            initialBalance + amount,
            "Beneficiary did not receive tokens"
        );
        assertEq(
            wallet.released(address(token)),
            amount,
            "Released amount is incorrect"
        );
    }

    function test_ReleaseERC20_PartiallyVested() public {
        uint256 amount = 1000e18;
        token.mint(address(wallet), amount);

        vm.warp(startTimestamp + DURATION / 2);

        uint256 releasableAmount = wallet.releasable(address(token));
        assertApproxEqAbs(
            releasableAmount,
            amount / 2,
            1,
            "Releasable amount is incorrect"
        );

        uint256 initialBalance = token.balanceOf(beneficiary);
        vm.prank(beneficiary);
        wallet.release(address(token));
        assertApproxEqAbs(
            token.balanceOf(beneficiary),
            initialBalance + amount / 2,
            1,
            "Beneficiary did not receive correct amount of tokens"
        );
        assertApproxEqAbs(
            wallet.released(address(token)),
            amount / 2,
            1,
            "Released amount is incorrect"
        );
    }

    function test_VestedAmount_BeforeStart() public {
        assertEq(
            wallet.vestedAmount(uint64(block.timestamp)),
            0,
            "Vested amount should be 0 before start"
        );
    }

    function test_VestedAmount_AtEnd() public {
        uint256 amount = 1 ether;
        vm.deal(address(wallet), amount);
        vm.warp(startTimestamp + DURATION);
        assertEq(
            wallet.vestedAmount(uint64(block.timestamp)),
            amount,
            "Vested amount should be total amount at the end"
        );
    }

    function test_ReleaseETH_MultipleTimes() public {
        uint256 amount = 1 ether;
        vm.deal(address(wallet), amount);

        vm.warp(startTimestamp + DURATION / 2);
        vm.prank(beneficiary);
        wallet.release();
        uint256 releasedFirst = wallet.released();
        assertGt(releasedFirst, 0, "First release failed");

        vm.warp(startTimestamp + DURATION);
        vm.prank(beneficiary);
        wallet.release();
        uint256 releasedTotal = wallet.released();
        assertEq(
            releasedTotal,
            amount,
            "Second release failed to release remaining funds"
        );
    }

    function test_ReleaseERC20_MultipleTimes() public {
        uint256 amount = 1000e18;
        token.mint(address(wallet), amount);

        vm.warp(startTimestamp + DURATION / 3);
        vm.prank(beneficiary);
        wallet.release(address(token));
        uint256 releasedFirst = wallet.released(address(token));
        assertGt(releasedFirst, 0, "First ERC20 release failed");

        vm.warp(startTimestamp + (2 * DURATION) / 3);
        vm.prank(beneficiary);
        wallet.release(address(token));
        uint256 releasedSecond = wallet.released(address(token));
        assertGt(
            releasedSecond,
            releasedFirst,
            "Second ERC20 release did not increase released amount"
        );

        vm.warp(startTimestamp + DURATION);
        vm.prank(beneficiary);
        wallet.release(address(token));
        assertEq(
            wallet.released(address(token)),
            amount,
            "Final release did not match full amount"
        );
    }

    function test_CannotReleaseBeforeStart() public {
        uint256 amount = 1 ether;
        vm.deal(address(wallet), amount);

        vm.warp(startTimestamp - 1);
        assertEq(
            wallet.releasable(),
            0,
            "ETH should not be releasable before vesting start"
        );

        vm.prank(beneficiary);
        wallet.release(); // should revert or do nothing
        assertEq(beneficiary.balance, 0, "Beneficiary received ETH too early");
    }

    function test_OnlyBeneficiaryCanRelease() public {
        uint256 amount = 1 ether;
        vm.deal(address(wallet), amount);
        vm.warp(startTimestamp + DURATION);
        vm.prank(address(2)); // not the beneficiary
        vm.expectRevert();
        wallet.release();
    }

    function test_ZeroFundsNoRelease() public {
        vm.warp(startTimestamp + DURATION);
        vm.prank(beneficiary);
        wallet.release(); // no funds, but should not revert
        assertEq(wallet.released(), 0);
    }
}
