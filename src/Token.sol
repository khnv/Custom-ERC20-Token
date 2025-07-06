// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

/**
 * @title MyToken
 * @dev A customizable ERC20 token with role-based access control, blacklist functionality, pausable features, and transfer fees.
 *
 * This contract extends OpenZeppelin's ERC20, ERC20Pausable, and AccessControl to provide:
 * - Standard ERC20 token functionality
 * - Role-based access control for different operations
 * - Blacklist management to prevent transfers from/to specific addresses
 * - Pausable functionality to halt all token transfers
 * - Transfer fee mechanism with configurable percentage
 *
 * @custom:security This contract uses AccessControl for secure role management.
 * Only authorized addresses can perform sensitive operations like minting, burning, and blacklist management.
 */
contract MyToken is ERC20, ERC20Pausable, AccessControl {
    // Define custom roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant BLACKLIST_MANAGER_ROLE = keccak256("BLACKLIST_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    /// @dev Mapping to track blacklisted addresses
    mapping(address => bool) blacklist;

    /// @dev Transfer fee percentage (in basis points, 100 = 1%)
    uint256 public transferFeePercentage;

    /// @dev Address that receives the transfer fees
    address public feeCollector;

    /// @dev Maximum fee percentage (10% = 1000 basis points)
    uint256 public constant MAX_FEE_PERCENTAGE = 1000;

    /// @dev Basis points denominator (100% = 10000)
    uint256 public constant BASIS_POINTS = 10000;

    //============================//
    //           Events           //
    //============================//

    /**
     * @dev Emitted when a user is added to the blacklist.
     * @param user The address that was blacklisted
     * @param by The address that performed the blacklisting
     */
    event UserBlacklisted(address indexed user, address indexed by);

    /**
     * @dev Emitted when a user is removed from the blacklist.
     * @param user The address that was removed from blacklist
     * @param by The address that performed the removal
     */
    event UserRemovedFromBlacklist(address indexed user, address indexed by);

    /**
     * @dev Emitted when transfer fee is updated.
     * @param oldFee The previous fee percentage
     * @param newFee The new fee percentage
     * @param by The address that updated the fee
     */
    event TransferFeeUpdated(uint256 oldFee, uint256 newFee, address indexed by);

    /**
     * @dev Emitted when fee collector is updated.
     * @param oldCollector The previous fee collector
     * @param newCollector The new fee collector
     * @param by The address that updated the collector
     */
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector, address indexed by);

    /**
     * @dev Emitted when transfer fee is collected.
     * @param from The address tokens were transferred from
     * @param to The address tokens were transferred to
     * @param amount The total amount transferred
     * @param feeAmount The fee amount collected
     * @param netAmount The net amount received by recipient
     */
    event TransferFeeCollected(
        address indexed from, address indexed to, uint256 amount, uint256 feeAmount, uint256 netAmount
    );

    //============================//
    //           Constructor      //
    //============================//

    /**
     * @dev Constructor that initializes the token with custom name and symbol.
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialFeePercentage The initial transfer fee percentage (in basis points)
     * @param initialFeeCollector The initial address to receive transfer fees
     *
     * Sets up the initial roles:
     * - Deployer gets DEFAULT_ADMIN_ROLE
     * - Deployer gets all custom roles initially
     * - Mints initial supply to deployer
     */
    constructor(string memory name, string memory symbol, uint256 initialFeePercentage, address initialFeeCollector)
        ERC20(name, symbol)
    {
        require(initialFeePercentage <= MAX_FEE_PERCENTAGE, "Fee percentage too high");
        require(initialFeeCollector != address(0), "Invalid fee collector");

        // Grant the contract deployer the default admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant the deployer all custom roles initially
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(BLACKLIST_MANAGER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);

        // Set initial fee parameters
        transferFeePercentage = initialFeePercentage;
        feeCollector = initialFeeCollector;

        _mint(msg.sender, 1000 * 10 ** decimals());
    }

    //============================//
    //           Functions        //
    //============================//

    /**
     * @dev Mints tokens to the caller's address.
     * @param amount The amount of tokens to mint
     *
     * Requirements:
     * - Caller must have MINTER_ROLE
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     */
    function mint(uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(msg.sender, amount);
    }

    /**
     * @dev Mints tokens to a specific address.
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     *
     * Requirements:
     * - Caller must have MINTER_ROLE
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     */
    function mintTo(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens from the caller's address.
     * @param amount The amount of tokens to burn
     *
     * Requirements:
     * - Caller must have BURNER_ROLE
     * - Caller must have sufficient balance
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     */
    function burn(uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Burns tokens from a specific address.
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     *
     * Requirements:
     * - Caller must have BURNER_ROLE
     * - `from` must have sufficient balance
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     */
    function burnFrom(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @dev Adds an address to the blacklist, preventing transfers from/to that address.
     * @param user The address to blacklist
     *
     * Requirements:
     * - Caller must have BLACKLIST_MANAGER_ROLE
     * - User must not already be blacklisted
     *
     * Emits a {UserBlacklisted} event.
     */
    function addToBlacklist(address user) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(!blacklist[user], "User is already blacklisted");
        blacklist[user] = true;
        emit UserBlacklisted(user, msg.sender);
    }

    /**
     * @dev Removes an address from the blacklist, allowing transfers from/to that address.
     * @param user The address to remove from blacklist
     *
     * Requirements:
     * - Caller must have BLACKLIST_MANAGER_ROLE
     * - User must be currently blacklisted
     *
     * Emits a {UserRemovedFromBlacklist} event.
     */
    function removeFromBlacklist(address user) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(blacklist[user], "User is not blacklisted");
        blacklist[user] = false;
        emit UserRemovedFromBlacklist(user, msg.sender);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * Requirements:
     * - Caller must have PAUSER_ROLE
     *
     * Emits a {Paused} event.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * Requirements:
     * - Caller must have PAUSER_ROLE
     *
     * Emits an {Unpaused} event.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Fee management functions

    /**
     * @dev Updates the transfer fee percentage.
     * @param newFeePercentage The new fee percentage (in basis points)
     *
     * Requirements:
     * - Caller must have FEE_MANAGER_ROLE
     * - New fee percentage must not exceed MAX_FEE_PERCENTAGE
     *
     * Emits a {TransferFeeUpdated} event.
     */
    function setTransferFeePercentage(uint256 newFeePercentage) external onlyRole(FEE_MANAGER_ROLE) {
        require(newFeePercentage <= MAX_FEE_PERCENTAGE, "Fee percentage too high");
        uint256 oldFee = transferFeePercentage;
        transferFeePercentage = newFeePercentage;
        emit TransferFeeUpdated(oldFee, newFeePercentage, msg.sender);
    }

    /**
     * @dev Updates the fee collector address.
     * @param newFeeCollector The new address to receive transfer fees
     *
     * Requirements:
     * - Caller must have FEE_MANAGER_ROLE
     * - New fee collector must not be zero address
     *
     * Emits a {FeeCollectorUpdated} event.
     */
    function setFeeCollector(address newFeeCollector) external onlyRole(FEE_MANAGER_ROLE) {
        require(newFeeCollector != address(0), "Invalid fee collector");
        address oldCollector = feeCollector;
        feeCollector = newFeeCollector;
        emit FeeCollectorUpdated(oldCollector, newFeeCollector, msg.sender);
    }

    /**
     * @dev Calculates the transfer fee for a given amount.
     * @param amount The amount to calculate fee for
     * @return feeAmount The calculated fee amount
     * @return netAmount The amount after fee deduction
     */
    function calculateTransferFee(uint256 amount) public view returns (uint256 feeAmount, uint256 netAmount) {
        if (transferFeePercentage == 0) {
            return (0, amount);
        }
        feeAmount = (amount * transferFeePercentage) / BASIS_POINTS;
        netAmount = amount - feeAmount;
    }

    /**
     * @dev Gets the current transfer fee information.
     * @return feePercentage The current fee percentage
     * @return collector The current fee collector address
     * @return maxFee The maximum allowed fee percentage
     */
    function getTransferFeeInfo() external view returns (uint256 feePercentage, address collector, uint256 maxFee) {
        return (transferFeePercentage, feeCollector, MAX_FEE_PERCENTAGE);
    }

    // Admin functions for role management

    /**
     * @dev Grants MINTER_ROLE to an account.
     * @param account The address to grant the role to
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function grantMinterRole(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }

    /**
     * @dev Revokes MINTER_ROLE from an account.
     * @param account The address to revoke the role from
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function revokeMinterRole(address account) external onlyRole(ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, account);
    }

    /**
     * @dev Grants BURNER_ROLE to an account.
     * @param account The address to grant the role to
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function grantBurnerRole(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, account);
    }

    /**
     * @dev Revokes BURNER_ROLE from an account.
     * @param account The address to revoke the role from
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function revokeBurnerRole(address account) external onlyRole(ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, account);
    }

    /**
     * @dev Grants BLACKLIST_MANAGER_ROLE to an account.
     * @param account The address to grant the role to
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function grantBlacklistManagerRole(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(BLACKLIST_MANAGER_ROLE, account);
    }

    /**
     * @dev Revokes BLACKLIST_MANAGER_ROLE from an account.
     * @param account The address to revoke the role from
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function revokeBlacklistManagerRole(address account) external onlyRole(ADMIN_ROLE) {
        _revokeRole(BLACKLIST_MANAGER_ROLE, account);
    }

    /**
     * @dev Grants PAUSER_ROLE to an account.
     * @param account The address to grant the role to
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function grantPauserRole(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(PAUSER_ROLE, account);
    }

    /**
     * @dev Revokes PAUSER_ROLE from an account.
     * @param account The address to revoke the role from
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function revokePauserRole(address account) external onlyRole(ADMIN_ROLE) {
        _revokeRole(PAUSER_ROLE, account);
    }

    /**
     * @dev Grants FEE_MANAGER_ROLE to an account.
     * @param account The address to grant the role to
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function grantFeeManagerRole(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(FEE_MANAGER_ROLE, account);
    }

    /**
     * @dev Revokes FEE_MANAGER_ROLE from an account.
     * @param account The address to revoke the role from
     *
     * Requirements:
     * - Caller must have ADMIN_ROLE
     */
    function revokeFeeManagerRole(address account) external onlyRole(ADMIN_ROLE) {
        _revokeRole(FEE_MANAGER_ROLE, account);
    }

    /**
     * @dev Grants ADMIN_ROLE to an account.
     * @param account The address to grant the role to
     *
     * Requirements:
     * - Caller must have DEFAULT_ADMIN_ROLE
     */
    function grantAdminRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, account);
    }

    /**
     * @dev Revokes ADMIN_ROLE from an account.
     * @param account The address to revoke the role from
     *
     * Requirements:
     * - Caller must have DEFAULT_ADMIN_ROLE
     */
    function revokeAdminRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, account);
    }

    /**
     * @dev Checks if an address is blacklisted.
     * @param user The address to check
     * @return True if the address is blacklisted, false otherwise
     */
    function isBlacklisted(address user) external view returns (bool) {
        return blacklist[user];
    }

    /**
     * @dev Hook that is called before any transfer of tokens.
     * @param from The address tokens are transferred from
     * @param to The address tokens are transferred to
     * @param value The amount of tokens being transferred
     *
     * Requirements:
     * - `from` must not be blacklisted
     * - `to` must not be blacklisted
     * - Contract must not be paused
     *
     * If transfer fee is enabled:
     * - Calculates fee amount
     * - Transfers fee to fee collector
     * - Transfers remaining amount to recipient
     * - Emits {TransferFeeCollected} event
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        require(!blacklist[from], "Sender is blacklisted");
        require(!blacklist[to], "Recipient is blacklisted");

        // Handle transfer fee logic
        if (transferFeePercentage > 0 && from != address(0) && to != address(0)) {
            (uint256 feeAmount, uint256 netAmount) = calculateTransferFee(value);

            if (feeAmount > 0) {
                // Transfer fee to collector
                super._update(from, feeCollector, feeAmount);
                // Transfer net amount to recipient
                super._update(from, to, netAmount);

                emit TransferFeeCollected(from, to, value, feeAmount, netAmount);
            } else {
                // No fee, normal transfer
                super._update(from, to, value);
            }
        } else {
            // No fee or minting/burning, normal transfer
            super._update(from, to, value);
        }
    }
}
