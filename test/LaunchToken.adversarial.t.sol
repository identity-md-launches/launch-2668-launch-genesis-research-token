// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LaunchToken} from "src/LaunchToken.sol";

/// @dev Local caller only; neither a production factory nor a claim implementation.
contract TokenCallerProbe {
    function deploy(bytes32 salt) external returns (LaunchToken) {
        return new LaunchToken{salt: salt}();
    }

    function pull(LaunchToken token, address owner, address recipient, uint256 amount) external {
        require(token.transferFrom(owner, recipient, amount), "transfer failed");
    }
}

contract LaunchTokenAdversarialTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000e18;
    address internal constant REQUESTER = 0x550011CAdCC758969391050241B2Fc43ED1a4B97;
    LaunchToken internal token;
    address internal alice;
    address internal bob;

    function setUp() public {
        vm.chainId(4663);
        alice = makeAddr("adversarial alice");
        bob = makeAddr("adversarial bob");
        token = new LaunchToken();
    }

    function test_create2MintsOnlyToImmediateDeployerDespiteRequesterOrigin() public {
        TokenCallerProbe caller = new TokenCallerProbe();
        bytes32 salt = keccak256("local GENS creation probe");
        address predicted = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), address(caller), salt, keccak256(type(LaunchToken).creationCode))
                    )
                )
            )
        );
        vm.recordLogs();
        vm.prank(REQUESTER, REQUESTER);
        LaunchToken created = caller.deploy(salt);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(address(created), predicted);
        assertEq(created.totalSupply(), SUPPLY);
        assertEq(created.balanceOf(address(caller)), SUPPLY);
        assertEq(created.balanceOf(REQUESTER), 0);
        assertEq(created.balanceOf(address(this)), 0);
        assertEq(logs.length, 1, "constructor must emit only the whole-supply mint");
        assertEq(logs[0].emitter, address(created));
        assertEq(logs[0].topics.length, 3);
        assertEq(logs[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(logs[0].topics[1], bytes32(0));
        assertEq(logs[0].topics[2], bytes32(uint256(uint160(address(caller)))));
        assertEq(abi.decode(logs[0].data, (uint256)), SUPPLY);
    }

    function test_intermediaryCannotUseOriginOrAnotherSpendersApproval() public {
        TokenCallerProbe caller = new TokenCallerProbe();
        token.approve(alice, SUPPLY);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(caller), 0, 1));
        vm.prank(alice, address(this));
        caller.pull(token, address(this), bob, 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.allowance(address(this), alice), SUPPLY);
    }

    function test_appendedAddressCannotSpoofTransferSender() public {
        bytes memory data = abi.encodePacked(abi.encodeCall(IERC20.transfer, (bob, 1)), address(this));
        vm.prank(alice);
        (bool ok, bytes memory reason) = address(token).call(data);
        assertFalse(ok);
        assertEq(reason, abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_transferFromByOwnerStillNeedsSelfApproval() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(address(this), alice, 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        token.approve(address(this), 1);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), address(this)), 0);
        assertEq(token.balanceOf(alice), 1);
    }

    function test_maximumFiniteAllowanceIsNotInfinite() public {
        token.approve(alice, type(uint256).max - 1);
        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), bob, SUPPLY));
        assertEq(token.allowance(address(this), alice), type(uint256).max - 1 - SUPPLY);
        assertEq(token.balanceOf(bob), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_infiniteApprovalCanBeRevokedAndCannotBeReused() public {
        token.approve(alice, type(uint256).max);
        vm.prank(alice);
        token.transferFrom(address(this), bob, 1);
        assertEq(token.allowance(address(this), alice), type(uint256).max);
        token.approve(alice, 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transferFrom(address(this), bob, 1);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.allowance(address(this), alice), 0);
    }

    function test_maximumTransferFromRevertsWithBalanceErrorNotOverflow() public {
        token.approve(alice, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        vm.prank(alice);
        token.transferFrom(address(this), bob, type(uint256).max);
        assertEq(token.allowance(address(this), alice), type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_zeroSpenderRejectedForZeroAndMaximumApprovals() public {
        uint256[2] memory amounts = [uint256(0), type(uint256).max];
        for (uint256 i; i < amounts.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
            token.approve(address(0), amounts[i]);
        }
        assertEq(token.allowance(address(this), address(0)), 0);
    }

    function test_delegatedTransferCoversEveryAddressAliasPartition() public {
        address[5] memory spenders = [alice, address(this), alice, alice, address(this)];
        address[5] memory recipients = [bob, bob, address(this), alice, address(this)];
        for (uint256 i; i < spenders.length; ++i) {
            LaunchToken fresh = new LaunchToken();
            fresh.approve(spenders[i], SUPPLY);
            vm.prank(spenders[i]);
            assertTrue(fresh.transferFrom(address(this), recipients[i], SUPPLY));
            assertEq(fresh.balanceOf(recipients[i]), SUPPLY);
            assertEq(fresh.balanceOf(address(this)), recipients[i] == address(this) ? SUPPLY : 0);
            assertEq(fresh.allowance(address(this), spenders[i]), 0);
            assertEq(fresh.totalSupply(), SUPPLY);
        }
    }

    function test_allStandardEntryPointsRejectNativeValue() public {
        bytes[9] memory calls = [
            abi.encodeWithSignature("name()"),
            abi.encodeWithSignature("symbol()"),
            abi.encodeWithSignature("decimals()"),
            abi.encodeCall(IERC20.totalSupply, ()),
            abi.encodeCall(IERC20.balanceOf, (address(this))),
            abi.encodeCall(IERC20.allowance, (address(this), alice)),
            abi.encodeCall(IERC20.transfer, (alice, 1)),
            abi.encodeCall(IERC20.approve, (alice, 1)),
            abi.encodeCall(IERC20.transferFrom, (address(this), alice, 1))
        ];
        token.approve(address(this), 1);
        vm.deal(address(this), 9);
        for (uint256 i; i < calls.length; ++i) {
            (bool ok,) = address(token).call{value: 1}(calls[i]);
            assertFalse(ok, "plain ERC-20 entry point accepted native currency");
        }
        assertEq(address(token).balance, 0);
        assertEq(address(this).balance, 9);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(address(this), address(this)), 1);
        assertEq(token.allowance(address(this), alice), 0);
    }

    /// forge-config: default.fuzz.runs = 1024
    function testFuzz_truncatedMutatingCalldataCannotChangeState(uint256 callSeed, uint256 lengthSeed) public {
        token.approve(address(this), SUPPLY);
        bytes[3] memory calls = [
            abi.encodeCall(IERC20.transfer, (alice, 1)),
            abi.encodeCall(IERC20.approve, (alice, 1)),
            abi.encodeCall(IERC20.transferFrom, (address(this), alice, 1))
        ];
        bytes memory data = calls[callSeed % calls.length];
        uint256 length = bound(lengthSeed, 0, data.length - 1);
        assembly ("memory-safe") { mstore(data, length) }
        vm.recordLogs();
        (bool ok,) = address(token).call(data);
        assertFalse(ok);
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(address(this), address(this)), SUPPLY);
        assertEq(token.allowance(address(this), alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// forge-config: default.fuzz.runs = 1024
    function testFuzz_failedSpendCanBeRetriedAfterFunding(uint256 balanceSeed, uint256 amountSeed) public {
        uint256 balance = bound(balanceSeed, 0, SUPPLY - 1);
        uint256 amount = bound(amountSeed, balance + 1, SUPPLY);
        token.transfer(alice, balance);
        vm.prank(alice);
        token.approve(bob, amount);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, amount));
        vm.prank(bob);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, bob), amount);
        assertEq(token.balanceOf(alice), balance);
        token.transfer(alice, amount - balance);
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, amount));
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
    }

    /// forge-config: default.fuzz.runs = 1024
    function testFuzz_splitTransfersEqualLumpSumWithoutTaxOrDust(uint256 amountSeed, uint256 splitSeed) public {
        uint256 amount = bound(amountSeed, 1, SUPPLY);
        uint256 first = bound(splitSeed, 0, amount);
        assertTrue(token.transfer(alice, first));
        assertTrue(token.transfer(alice, amount - first));
        assertEq(token.balanceOf(alice), amount);
        vm.prank(alice);
        assertTrue(token.transfer(address(this), amount));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// forge-config: default.fuzz.runs = 1024
    function testFuzz_replacingPartiallySpentApprovalDoesNotAddOldAllowance(
        uint256 initialSeed,
        uint256 spentSeed,
        uint256 replacementSeed
    ) public {
        uint256 initial = bound(initialSeed, 1, SUPPLY);
        uint256 spent = bound(spentSeed, 1, initial);
        uint256 replacement = bound(replacementSeed, 0, SUPPLY - spent);
        token.approve(alice, initial);
        token.approve(bob, 7);
        vm.prank(alice);
        token.transferFrom(address(this), bob, spent);
        token.approve(alice, replacement);
        assertEq(token.allowance(address(this), alice), replacement);
        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), bob, replacement));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transferFrom(address(this), bob, 1);
        assertEq(token.allowance(address(this), alice), 0);
        assertEq(token.allowance(address(this), bob), 7);
        assertEq(token.balanceOf(bob), spent + replacement);
        assertEq(token.balanceOf(address(this)), SUPPLY - spent - replacement);
    }
}
