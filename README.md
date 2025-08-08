# Vesting Contracts

This project provides Solidity contracts for token vesting mechanisms on the Ethereum blockchain. It includes two main contracts: `ERC20Vesting` and `VestingWallet`.

## Features

- **ERC20Vesting**: An abstract contract that extends the standard ERC20 token to include vesting logic. It allows for multiple, linear vesting schedules per user.
- **VestingWallet**: A wallet contract that holds and manages assets (Ether and ERC20 tokens) for a beneficiary, releasing them over a specified period.

## Contracts

### `ERC20Vesting.sol`

An abstract contract that adds vesting functionalities to an ERC20 token.

- **Linear Vesting**: Tokens are released linearly over a configurable duration.
- **Multiple Schedules**: Each user can have multiple vesting schedules.
- **Vesting Management**: Functions to create, view, and manage vesting schedules.
- **Withdrawal**: Allows users to withdraw vested tokens.

### `VestingWallet.sol`

A standalone wallet for vesting Ether and ERC20 tokens.

- **Time-locked Release**: Funds are released over a defined duration after a start time.
- **Beneficiary-centric**: Designed to hold funds for a specific beneficiary.
- **Supports ETH and ERC20**: Can manage both native Ether and any ERC20 token.
- **Ownable**: The contract has an owner with administrative privileges.

## Usage

To use these contracts, you can either:
1. Inherit from `ERC20Vesting` to create your own vestable token.
2. Deploy `VestingWallet` to manage vesting for a specific beneficiary.

### Example: Creating a Vestable Token

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Vesting} from "./ERC20Vesting.sol";

contract MyVestingToken is ERC20Vesting {
    constructor(uint64 vestingDuration)
        ERC20Vesting(vestingDuration)
        ERC20("MyVestingToken", "MVT")
    {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
```

## Testing

This project uses Foundry for testing. To run the tests, use the following command:

```bash
forge test
```