// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract VestingWalletMock is Ownable, VestingWallet {


    constructor(
        address beneficiary_,
        uint64 start_,
        uint64 duration_
    ) VestingWallet(beneficiary_, start_, duration_) {}

    function release() public override onlyOwner {
        super.release();
    }
}
