// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LaunchToken} from "../src/LaunchToken.sol";

/// @dev A recipient whose fallback always reverts: ERC-20 transfers must not call it.
contract RejectingRecipient {
    fallback() external {
        revert("unexpected callback");
    }
}

contract LaunchTokenTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000e18;
    LaunchToken internal token;
    address internal alice;
    address internal bob;

    function setUp() public {
        vm.chainId(4663);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        token = new LaunchToken();
    }

    function test_metadataAndEntireSupplyBelongToDeployer() public view {
        assertEq(token.name(), "Genesis Research Token");
        assertEq(token.symbol(), "GENS");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.allowance(address(this), alice), 0);
    }

    function test_constructorEmitsSingleSupplyMint() public {
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(address(0), address(this), SUPPLY);
        new LaunchToken();
    }

    function test_transferEmitsEventAndMovesExactAmount() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(address(this), alice, 123e18);
        assertTrue(token.transfer(alice, 123e18));
        assertEq(token.balanceOf(alice), 123e18);
        assertEq(token.balanceOf(address(this)), SUPPLY - 123e18);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferEntireSupply() public {
        assertTrue(token.transfer(alice, SUPPLY));
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
        vm.prank(alice);
        assertTrue(token.transfer(address(this), SUPPLY));
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_zeroTransferFromEmptyAccountEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(alice, bob, 0);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 0));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_selfTransferPreservesBalance() public {
        assertTrue(token.transfer(address(this), SUPPLY));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferDoesNotCallRecipient() public {
        RejectingRecipient recipient = new RejectingRecipient();
        assertTrue(token.transfer(address(recipient), 1e18));
        assertEq(token.balanceOf(address(recipient)), 1e18);
    }

    function test_transferToZeroRevertsEvenForZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferCannotSpendAnotherHoldersBalance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transfer(bob, 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_selfTransferStillRequiresBalance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transfer(alice, 1);
    }

    function test_approveEmitsEventAndCanReplaceAndRevokeAllowance() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(address(this), alice, 10e18);
        assertTrue(token.approve(alice, 10e18));
        assertEq(token.allowance(address(this), alice), 10e18);
        assertTrue(token.approve(alice, 2e18));
        assertEq(token.allowance(address(this), alice), 2e18);
        assertTrue(token.approve(alice, 0));
        assertEq(token.allowance(address(this), alice), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transferFrom(address(this), bob, 1);
    }

    function test_approveZeroSpenderReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 1);
    }

    function test_approvalIsSpecificToOwnerAndSpender() public {
        token.approve(alice, 1e18);
        vm.prank(bob);
        token.approve(alice, SUPPLY);
        assertEq(token.allowance(address(this), alice), 1e18);
        assertEq(token.allowance(bob, alice), SUPPLY);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 1));
        vm.prank(bob);
        token.transferFrom(address(this), bob, 1);
    }

    function test_transferFromConsumesFiniteAllowanceAndEmitsTransfer() public {
        token.approve(alice, 3e18);
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(address(this), bob, 2e18);
        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), bob, 2e18));
        assertEq(token.allowance(address(this), alice), 1e18);
        assertEq(token.balanceOf(address(this)), SUPPLY - 2e18);
        assertEq(token.balanceOf(bob), 2e18);
        assertEq(token.balanceOf(alice), 0);
        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), bob, 1e18));
        assertEq(token.allowance(address(this), alice), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transferFrom(address(this), bob, 1);
    }

    function test_infiniteAllowanceRemainsUnchanged() public {
        token.approve(alice, type(uint256).max);
        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), bob, SUPPLY));
        assertEq(token.allowance(address(this), alice), type(uint256).max);
        assertEq(token.balanceOf(bob), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferFromSelfStillConsumesAllowance() public {
        token.approve(alice, SUPPLY);
        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), address(this), SUPPLY));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.allowance(address(this), alice), 0);
    }

    function test_zeroTransferFromWorksWithoutAllowance() public {
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 0));
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferFromToZeroRollsBackAllowance() public {
        token.approve(alice, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(alice);
        token.transferFrom(address(this), address(0), 10);
        assertEq(token.allowance(address(this), alice), 10);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_transferFromZeroSenderReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        token.transferFrom(address(0), alice, 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_insufficientBalanceRollsBackAllowance() public {
        vm.prank(alice);
        token.approve(bob, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 10));
        vm.prank(bob);
        token.transferFrom(alice, bob, 10);
        assertEq(token.allowance(alice, bob), 10);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_noAdminMintBurnTaxPauseBlacklistOrUpgradeEntryPoints() public {
        // Correct ABI arguments are essential: malformed dynamic calldata can revert even
        // when an unwanted upgrade/initialization function actually exists.
        bytes[20] memory calls = [
            abi.encodeWithSignature("mint(address,uint256)", alice, uint256(1)),
            abi.encodeWithSignature("mint(uint256)", uint256(1)),
            abi.encodeWithSignature("mint()"),
            abi.encodeWithSignature("burn(uint256)", uint256(1)),
            abi.encodeWithSignature("burnFrom(address,uint256)", address(this), uint256(1)),
            abi.encodeWithSignature("owner()"),
            abi.encodeWithSignature("transferOwnership(address)", alice),
            abi.encodeWithSignature("setOwner(address)", alice),
            abi.encodeWithSignature("setMinter(address)", alice),
            abi.encodeWithSignature("pause()"),
            abi.encodeWithSignature("unpause()"),
            abi.encodeWithSignature("blacklist(address)", alice),
            abi.encodeWithSignature("setBlacklist(address,bool)", alice, true),
            abi.encodeWithSignature("setFee(uint256)", uint256(1)),
            abi.encodeWithSignature("setTax(uint256)", uint256(1)),
            abi.encodeWithSignature("upgradeTo(address)", address(token)),
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(token), bytes("")),
            abi.encodeWithSignature("initialize(address)", alice),
            abi.encodeWithSignature("initialize()"),
            abi.encodeWithSignature("claim()")
        ];
        address[3] memory callers = [address(this), alice, address(0x550011CAdCC758969391050241B2Fc43ED1a4B97)];
        for (uint256 i; i < callers.length; ++i) {
            for (uint256 j; j < calls.length; ++j) {
                vm.prank(callers[i]);
                (bool ok,) = address(token).call(calls[j]);
                assertFalse(ok, "prohibited entry point accepted valid calldata");
                assertEq(token.totalSupply(), SUPPLY);
                assertEq(token.balanceOf(address(this)), SUPPLY);
            }
        }
        assertTrue(token.transfer(alice, 1));
    }

    function test_noNativeCurrencyOrFallbackEntryPoint() public {
        (bool emptyCall,) = address(token).call("");
        assertFalse(emptyCall);
        vm.deal(address(this), 1);
        (bool nativeTransfer,) = address(token).call{value: 1}("");
        assertFalse(nativeTransfer);
        assertEq(address(token).balance, 0);
    }

    function test_runtimeIsBoundedAndHasNoEscapeOpcodes() public view {
        bytes memory runtime = address(token).code;
        assertGt(runtime.length, 0);
        assertLe(runtime.length, 24_576);
        bool reachable = true;
        for (uint256 i; i < runtime.length; ++i) {
            uint8 op = uint8(runtime[i]);
            if (op == 0x5b) reachable = true;
            if (op >= 0x60 && op <= 0x7f) {
                i += op - 0x5f;
                continue;
            }
            if (reachable) {
                assertTrue(op != 0xf4 && op != 0xf2 && op != 0xff, "forbidden opcode");
            }
            if (op == 0x00 || op == 0x56 || op == 0xf3 || op == 0xfd || op == 0xfe || op == 0xff) reachable = false;
        }
    }

    /// forge-config: default.fuzz.runs = 1024
    function testFuzz_transferConservesSupply(address recipient, uint256 rawAmount) public {
        if (recipient == address(0) || recipient == address(this)) recipient = alice;
        uint256 amount = bound(rawAmount, 0, SUPPLY);
        assertTrue(token.transfer(recipient, amount));
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// forge-config: default.fuzz.runs = 1024
    function testFuzz_transferOverBalanceRevertsAtomically(uint256 rawAmount) public {
        uint256 amount = bound(rawAmount, SUPPLY + 1, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, amount)
        );
        token.transfer(alice, amount);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// forge-config: default.fuzz.runs = 1024
    function testFuzz_transferFromAccountsExactly(uint256 rawAllowance, uint256 rawAmount) public {
        uint256 approved = bound(rawAllowance, 0, type(uint256).max - 1);
        uint256 amount = bound(rawAmount, 0, approved < SUPPLY ? approved : SUPPLY);
        token.approve(alice, approved);
        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), bob, amount));
        assertEq(token.allowance(address(this), alice), approved - amount);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// forge-config: default.fuzz.runs = 1024
    function testFuzz_insufficientAllowanceRevertsAtomically(uint256 rawAllowance, uint256 rawAmount) public {
        uint256 approved = bound(rawAllowance, 0, SUPPLY - 1);
        uint256 amount = bound(rawAmount, approved + 1, SUPPLY);
        token.approve(alice, approved);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, approved, amount)
        );
        vm.prank(alice);
        token.transferFrom(address(this), bob, amount);
        assertEq(token.allowance(address(this), alice), approved);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
