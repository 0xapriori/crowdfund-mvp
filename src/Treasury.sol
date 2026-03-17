// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Treasury - Receives and manages protocol fees
/// @notice Collects 25bps fees from successful campaigns for protocol operations.
///         Admin address is configurable (can be EOA, multisig, or governance).
contract Treasury {
    address public admin;

    event FeeReceived(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);

    error NotAdmin();
    error TransferFailed();
    error ZeroAddress();
    error ZeroAmount();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(address _admin) {
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
    }

    /// @notice Receive protocol fees from Campaign contracts
    receive() external payable {
        emit FeeReceived(msg.sender, msg.value);
    }

    /// @notice Withdraw funds to a specified address
    function withdraw(address to, uint256 amount) external onlyAdmin {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0 || amount > address(this).balance) revert ZeroAmount();

        (bool success,) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(to, amount);
    }

    /// @notice Transfer admin role
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address old = admin;
        admin = newAdmin;
        emit AdminTransferred(old, newAdmin);
    }

    /// @notice Get treasury balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
