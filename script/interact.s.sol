// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/Token.sol";

/**
 * @title MyToken Interaction Script
 * @dev Script to interact with the deployed MyToken contract on Sepolia
 */
contract MyTokenInteraction is Script {
    
    // Deployed contract address on Sepolia
    address constant DEPLOYED_CONTRACT = 0x36330bfB3Ea893CbDCaB077A5ef8aCD7C0fb3430;
    
    MyToken public token;
    
    function setUp() public {
        token = MyToken(DEPLOYED_CONTRACT);
    }
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Interacting with MyToken at:", DEPLOYED_CONTRACT);
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Example interactions - uncomment what you want to test
        
        // 1. Check contract info
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply());
        console.log("Transfer fee:", token.transferFeePercentage(), "basis points");
        console.log("Fee collector:", token.feeCollector());
        
        // 2. Check deployer balance
        console.log("Deployer balance:", token.balanceOf(deployer));
        
        // 3. Example: Mint tokens (if you have MINTER_ROLE)
         token.mint(100 * 10**18);
         console.log("Minted 100 tokens to deployer");
        
        // 4. Example: Grant roles to another address
         address newMinter = 0x1234567890123456789012345678901234567890; // Replace with actual address
         token.grantMinterRole(newMinter);
         console.log("Granted MINTER_ROLE to:", newMinter);
        
         // 5. Example: Update transfer fee
         token.setTransferFeePercentage(500); // 5%
         console.log("Updated transfer fee to 5%");
        
        // 6. Example: Transfer tokens (will incur fee)
         address recipient = 0x1234567890123456789012345678901234567890; // Replace with actual address
         token.transfer(recipient, 100 * 10**18);
         console.log("Transferred 100 tokens to:", recipient);
        
        vm.stopBroadcast();
        
        console.log("Interaction completed!");
    }
    
    /**
     * @dev Helper function to check if an address has a specific role
     */
    function checkRole(address account, bytes32 role) public view {
        bool hasRole = token.hasRole(role, account);
        console.log("Address", account);
        console.log("has role", uint256(role), ":", hasRole);
    }
    
    /**
     * @dev Helper function to get all role information for an address
     */
    function checkAllRoles(address account) public view {
        console.log("=== Role Check for", account, "===");
        checkRole(account, token.DEFAULT_ADMIN_ROLE());
        checkRole(account, token.ADMIN_ROLE());
        checkRole(account, token.MINTER_ROLE());
        checkRole(account, token.BURNER_ROLE());
        checkRole(account, token.BLACKLIST_MANAGER_ROLE());
        checkRole(account, token.PAUSER_ROLE());
        checkRole(account, token.FEE_MANAGER_ROLE());
    }
} 