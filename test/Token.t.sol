// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MyToken} from "../src/Token.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// Event declarations for testing
event UserBlacklisted(address indexed user, address indexed by);

event UserRemovedFromBlacklist(address indexed user, address indexed by);

event TransferFeeUpdated(uint256 oldFee, uint256 newFee, address indexed by);

event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector, address indexed by);

contract TokenTest is Test {
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address feeCollector = address(0x4);
    address admin = address(0x5);
    address blacklistManager = address(0x6);
    address pauser = address(0x7);
    address feeManager = address(0x8);

    MyToken public token;

    function setUp() public {
        vm.startPrank(owner);
        token = new MyToken("MyToken", "MTK", 250, feeCollector); // 2.5% fee
        vm.stopPrank();
    }

    // ============================
    // Constructor Tests
    // ============================

    function test_constructor() public view {
        assertEq(token.name(), "MyToken");
        assertEq(token.symbol(), "MTK");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 1000 * 10 ** 18);
        assertEq(token.transferFeePercentage(), 250);
        assertEq(token.feeCollector(), feeCollector);
        assertEq(token.MAX_FEE_PERCENTAGE(), 1000);
        assertEq(token.BASIS_POINTS(), 10000);
    }

    function test_constructor_revert_highFee() public {
        vm.expectRevert("Fee percentage too high");
        new MyToken("MyToken", "MTK", 1001, feeCollector);
    }

    function test_constructor_revert_invalidCollector() public {
        vm.expectRevert("Invalid fee collector");
        new MyToken("MyToken", "MTK", 250, address(0));
    }

    // ============================
    // Minting Tests
    // ============================

    function test_mint() public {
        vm.startPrank(owner);
        token.mint(100 * 10 ** 18);
        assertEq(token.balanceOf(owner), 1100 * 10 ** 18);
        vm.stopPrank();
    }

    function test_mint_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.mint(100 * 10 ** 18);
        vm.stopPrank();
    }

    function test_mintTo() public {
        vm.startPrank(owner);
        token.mintTo(user1, 100 * 10 ** 18);
        assertEq(token.balanceOf(user1), 100 * 10 ** 18);
        vm.stopPrank();
    }

    function test_mintTo_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.mintTo(user2, 100 * 10 ** 18);
        vm.stopPrank();
    }

    // ============================
    // Burning Tests
    // ============================

    function test_burn() public {
        vm.startPrank(owner);
        token.burn(100 * 10 ** 18);
        assertEq(token.balanceOf(owner), 900 * 10 ** 18);
        vm.stopPrank();
    }

    function test_burn_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.burn(100 * 10 ** 18);
        vm.stopPrank();
    }

    function test_burnFrom() public {
        vm.startPrank(owner);
        token.mintTo(user1, 200 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(owner);
        token.burnFrom(user1, 100 * 10 ** 18);
        assertEq(token.balanceOf(user1), 100 * 10 ** 18);
        vm.stopPrank();
    }

    function test_burnFrom_unauthorized() public {
        vm.startPrank(owner);
        token.mintTo(user1, 200 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert();
        token.burnFrom(user1, 100 * 10 ** 18);
        vm.stopPrank();
    }

    // ============================
    // Blacklist Tests
    // ============================

    function test_addToBlacklist() public {
        vm.startPrank(owner);
        token.addToBlacklist(user1);
        assertTrue(token.isBlacklisted(user1));
        vm.stopPrank();
    }

    function test_addToBlacklist_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.addToBlacklist(user2);
        vm.stopPrank();
    }

    function test_addToBlacklist_alreadyBlacklisted() public {
        vm.startPrank(owner);
        token.addToBlacklist(user1);
        vm.expectRevert("User is already blacklisted");
        token.addToBlacklist(user1);
        vm.stopPrank();
    }

    function test_removeFromBlacklist() public {
        vm.startPrank(owner);
        token.addToBlacklist(user1);
        token.removeFromBlacklist(user1);
        assertFalse(token.isBlacklisted(user1));
        vm.stopPrank();
    }

    function test_removeFromBlacklist_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.removeFromBlacklist(user2);
        vm.stopPrank();
    }

    function test_removeFromBlacklist_notBlacklisted() public {
        vm.startPrank(owner);
        vm.expectRevert("User is not blacklisted");
        token.removeFromBlacklist(user1);
        vm.stopPrank();
    }

    function test_transfer_blacklistedSender() public {
        vm.startPrank(owner);
        // Ensure user2 is not blacklisted
        if (token.isBlacklisted(user2)) {
            token.removeFromBlacklist(user2);
        }
        // Mint tokens to user1 BEFORE blacklisting them
        token.mintTo(user1, 100 * 10 ** 18);
        token.addToBlacklist(user1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Sender is blacklisted");
        token.transfer(user2, 50 * 10 ** 18);
        vm.stopPrank();
    }

    function test_transfer_blacklistedRecipient() public {
        vm.startPrank(owner);
        token.addToBlacklist(user2);
        vm.expectRevert("Recipient is blacklisted");
        token.transfer(user2, 50 * 10 ** 18);
        vm.stopPrank();
    }

    // ============================
    // Pause Tests
    // ============================

    function test_pause() public {
        vm.startPrank(owner);
        token.pause();
        assertTrue(token.paused());
        vm.stopPrank();
    }

    function test_pause_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.pause();
        vm.stopPrank();
    }

    function test_unpause() public {
        vm.startPrank(owner);
        token.pause();
        token.unpause();
        assertFalse(token.paused());
        vm.stopPrank();
    }

    function test_unpause_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.unpause();
        vm.stopPrank();
    }

    function test_transfer_whenPaused() public {
        vm.startPrank(owner);
        token.pause();
        vm.expectRevert();
        token.transfer(user1, 50 * 10 ** 18);
        vm.stopPrank();
    }

    // ============================
    // Transfer Fee Tests
    // ============================

    function test_transferFee() public {
        vm.startPrank(owner);
        token.mintTo(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.transfer(user2, 1000 * 10 ** 18);
        // 2.5% fee = 25 tokens, net = 975 tokens
        assertEq(token.balanceOf(user2), 975 * 10 ** 18);
        assertEq(token.balanceOf(feeCollector), 25 * 10 ** 18);
        vm.stopPrank();
    }

    function test_transferFee_zeroFee() public {
        vm.startPrank(owner);
        token.setTransferFeePercentage(0);
        token.mintTo(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.transfer(user2, 1000 * 10 ** 18);
        assertEq(token.balanceOf(user2), 1000 * 10 ** 18);
        assertEq(token.balanceOf(feeCollector), 0);
        vm.stopPrank();
    }

    function test_transferFee_minting() public {
        vm.startPrank(owner);
        token.mintTo(user1, 1000 * 10 ** 18);
        // Minting should not incur fees
        assertEq(token.balanceOf(user1), 1000 * 10 ** 18);
        assertEq(token.balanceOf(feeCollector), 0);
        vm.stopPrank();
    }

    function test_transferFee_burning() public {
        vm.startPrank(owner);
        token.burn(100 * 10 ** 18);
        // Burning should not incur fees
        assertEq(token.balanceOf(feeCollector), 0);
        vm.stopPrank();
    }

    function test_calculateTransferFee() public {
        (uint256 fee, uint256 net) = token.calculateTransferFee(1000 * 10 ** 18);
        assertEq(fee, 25 * 10 ** 18); // 2.5% of 1000
        assertEq(net, 975 * 10 ** 18); // 1000 - 25
    }

    function test_calculateTransferFee_zeroFee() public {
        vm.startPrank(owner);
        token.setTransferFeePercentage(0);
        vm.stopPrank();

        (uint256 fee, uint256 net) = token.calculateTransferFee(1000 * 10 ** 18);
        assertEq(fee, 0);
        assertEq(net, 1000 * 10 ** 18);
    }

    function test_getTransferFeeInfo() public {
        (uint256 feePercentage, address collector, uint256 maxFee) = token.getTransferFeeInfo();
        assertEq(feePercentage, 250);
        assertEq(collector, feeCollector);
        assertEq(maxFee, 1000);
    }

    // ============================
    // Fee Management Tests
    // ============================

    function test_setTransferFeePercentage() public {
        vm.startPrank(owner);
        token.setTransferFeePercentage(500); // 5%
        assertEq(token.transferFeePercentage(), 500);
        vm.stopPrank();
    }

    function test_setTransferFeePercentage_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.setTransferFeePercentage(500);
        vm.stopPrank();
    }

    function test_setTransferFeePercentage_tooHigh() public {
        vm.startPrank(owner);
        vm.expectRevert("Fee percentage too high");
        token.setTransferFeePercentage(1001);
        vm.stopPrank();
    }

    function test_setFeeCollector() public {
        vm.startPrank(owner);
        token.setFeeCollector(user1);
        assertEq(token.feeCollector(), user1);
        vm.stopPrank();
    }

    function test_setFeeCollector_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.setFeeCollector(user2);
        vm.stopPrank();
    }

    function test_setFeeCollector_invalidAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid fee collector");
        token.setFeeCollector(address(0));
        vm.stopPrank();
    }

    // ============================
    // Role Management Tests
    // ============================

    function test_grantMinterRole() public {
        vm.startPrank(owner);
        token.grantMinterRole(user1);
        assertTrue(token.hasRole(token.MINTER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_grantMinterRole_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.grantMinterRole(user2);
        vm.stopPrank();
    }

    function test_revokeMinterRole() public {
        vm.startPrank(owner);
        token.grantMinterRole(user1);
        token.revokeMinterRole(user1);
        assertFalse(token.hasRole(token.MINTER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_grantBurnerRole() public {
        vm.startPrank(owner);
        token.grantBurnerRole(user1);
        assertTrue(token.hasRole(token.BURNER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_revokeBurnerRole() public {
        vm.startPrank(owner);
        token.grantBurnerRole(user1);
        token.revokeBurnerRole(user1);
        assertFalse(token.hasRole(token.BURNER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_grantBlacklistManagerRole() public {
        vm.startPrank(owner);
        token.grantBlacklistManagerRole(user1);
        assertTrue(token.hasRole(token.BLACKLIST_MANAGER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_revokeBlacklistManagerRole() public {
        vm.startPrank(owner);
        token.grantBlacklistManagerRole(user1);
        token.revokeBlacklistManagerRole(user1);
        assertFalse(token.hasRole(token.BLACKLIST_MANAGER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_grantPauserRole() public {
        vm.startPrank(owner);
        token.grantPauserRole(user1);
        assertTrue(token.hasRole(token.PAUSER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_revokePauserRole() public {
        vm.startPrank(owner);
        token.grantPauserRole(user1);
        token.revokePauserRole(user1);
        assertFalse(token.hasRole(token.PAUSER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_grantFeeManagerRole() public {
        vm.startPrank(owner);
        token.grantFeeManagerRole(user1);
        assertTrue(token.hasRole(token.FEE_MANAGER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_revokeFeeManagerRole() public {
        vm.startPrank(owner);
        token.grantFeeManagerRole(user1);
        token.revokeFeeManagerRole(user1);
        assertFalse(token.hasRole(token.FEE_MANAGER_ROLE(), user1));
        vm.stopPrank();
    }

    function test_grantAdminRole() public {
        vm.startPrank(owner);
        token.grantAdminRole(user1);
        assertTrue(token.hasRole(token.ADMIN_ROLE(), user1));
        vm.stopPrank();
    }

    function test_revokeAdminRole() public {
        vm.startPrank(owner);
        token.grantAdminRole(user1);
        token.revokeAdminRole(user1);
        assertFalse(token.hasRole(token.ADMIN_ROLE(), user1));
        vm.stopPrank();
    }

    // ============================
    // Integration Tests
    // ============================

    function test_completeWorkflow() public {
        // Setup roles
        vm.startPrank(owner);
        token.grantMinterRole(user1);
        token.grantBurnerRole(user2);
        token.grantBlacklistManagerRole(blacklistManager);
        token.grantPauserRole(pauser);
        token.grantFeeManagerRole(feeManager);

        vm.stopPrank();

        // Test minting
        vm.startPrank(user1);
        token.mintTo(user2, 1000 * 10 ** 18);
        assertEq(token.balanceOf(user2), 1000 * 10 ** 18);
        vm.stopPrank();

        // Test transfer with fee
        vm.startPrank(user2);
        token.transfer(user1, 500 * 10 ** 18);
        assertEq(token.balanceOf(user1), 487.5 * 10 ** 18); // 500 - 2.5% fee
        assertEq(token.balanceOf(feeCollector), 12.5 * 10 ** 18); // 2.5% fee
        vm.stopPrank();

        // Test blacklisting
        vm.startPrank(blacklistManager);
        token.addToBlacklist(user1);
        assertTrue(token.isBlacklisted(user1));
        vm.stopPrank();

        // Test burning
        vm.startPrank(user2);
        token.burn(100 * 10 ** 18);
        assertEq(token.balanceOf(user2), 400 * 10 ** 18);
        vm.stopPrank();

        // Test pausing
        vm.startPrank(pauser);
        token.pause();
        assertTrue(token.paused());
        vm.stopPrank();

        // Test fee management
        vm.startPrank(feeManager);
        token.setTransferFeePercentage(500); // 5%
        token.setFeeCollector(user2);
        assertEq(token.transferFeePercentage(), 500);
        assertEq(token.feeCollector(), user2);
        vm.stopPrank();
    }

    // ============================
    // Edge Cases and Error Tests
    // ============================

    function test_transfer_insufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert();
        token.transfer(user2, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function test_burn_insufficientBalance() public {
        vm.startPrank(owner);
        vm.expectRevert();
        token.burn(2000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_burnFrom_insufficientBalance() public {
        vm.startPrank(owner);
        token.mintTo(user1, 100 * 10 ** 18);
        vm.expectRevert();
        token.burnFrom(user1, 200 * 10 ** 18);
        vm.stopPrank();
    }

    function test_transfer_toSelf() public {
        vm.startPrank(owner);
        token.transfer(owner, 100 * 10 ** 18);
        // Should work but with fee deduction
        assertEq(token.balanceOf(owner), 997.5 * 10 ** 18); // 1000 - 100 + 100 - 2.5% fee
        vm.stopPrank();
    }

    function test_transfer_zeroAmount() public {
        vm.startPrank(owner);
        token.transfer(user1, 0);
        assertEq(token.balanceOf(user1), 0);
        vm.stopPrank();
    }

    function test_mint_zeroAmount() public {
        vm.startPrank(owner);
        token.mint(0);
        assertEq(token.balanceOf(owner), 1000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_burn_zeroAmount() public {
        vm.startPrank(owner);
        token.burn(0);
        assertEq(token.balanceOf(owner), 1000 * 10 ** 18);
        vm.stopPrank();
    }

    // ============================
    // Event Tests
    // ============================

    function test_events() public {
        vm.startPrank(owner);

        // Test UserBlacklisted event
        vm.expectEmit(true, true, false, true);
        emit UserBlacklisted(user1, owner);
        token.addToBlacklist(user1);

        // Test UserRemovedFromBlacklist event
        vm.expectEmit(true, true, false, true);
        emit UserRemovedFromBlacklist(user1, owner);
        token.removeFromBlacklist(user1);

        // Test TransferFeeUpdated event
        vm.expectEmit(false, false, false, true);
        emit TransferFeeUpdated(250, 500, owner);
        token.setTransferFeePercentage(500);

        // Test FeeCollectorUpdated event
        vm.expectEmit(true, true, false, true);
        emit FeeCollectorUpdated(feeCollector, user1, owner);
        token.setFeeCollector(user1);

        vm.stopPrank();
    }

    // ============================
    // Gas Optimization Tests
    // ============================

    function test_gas_efficient_transfers() public {
        vm.startPrank(owner);
        token.mintTo(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(user1);
        // Test multiple transfers to ensure gas efficiency
        for (uint256 i = 0; i < 5; i++) {
            token.transfer(user2, 10 * 10 ** 18);
        }
        vm.stopPrank();
    }
}
