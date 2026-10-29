// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Genesis Research Token
/// @notice Fixed-supply, 18-decimal GENS for the standard IMD project launch.
/// @dev ProjectFactory receives the entire supply and performs the protocol allocation.
/// The requester's later reserve transfer is an ordinary ERC-20 transfer, outside the launch.
contract LaunchToken is ERC20 {
    constructor() ERC20("Genesis Research Token", "GENS") {
        _mint(msg.sender, 1_000_000_000 * 10 ** 18);
    }
}
