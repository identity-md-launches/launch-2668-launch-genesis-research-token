// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LaunchToken} from "../src/LaunchToken.sol";

/// @dev Test-only allocation model. This is NOT ProjectFactory or a Uniswap integration.
/// Recipients below model protocol custody, without implementing pools or claims.
contract FactoryAllocationModel {
    function deployToken() external returns (LaunchToken) {
        return new LaunchToken();
    }

    function deployAndAllocate(address poolCustody, address swarmDistributor, address requester)
        external
        returns (LaunchToken token)
    {
        token = new LaunchToken();
        require(token.totalSupply() == 1_000_000_000e18, "wrong supply");
        require(token.balanceOf(address(this)) == token.totalSupply(), "not wholly minted to factory");
        require(token.transfer(poolCustody, 800_000_000e18), "pool allocation failed");
        require(token.transfer(swarmDistributor, 100_000_000e18), "swarm allocation failed");
        require(token.transfer(requester, 100_000_000e18), "requester allocation failed");
    }
}

contract LaunchAllocationTest is Test {
    address internal constant REQUESTER = 0x550011CAdCC758969391050241B2Fc43ED1a4B97;
    address internal constant RESERVE = 0x4A532cbC877fbBd4950FdAB65BFEA2e8567b857B;
    uint256 internal constant SUPPLY = 1_000_000_000e18;
    FactoryAllocationModel internal factory;
    LaunchToken internal token;
    address internal poolCustody;
    address internal swarmDistributor;
    address internal unrelatedWallet;

    function setUp() public {
        vm.chainId(4663);
        poolCustody = makeAddr("test-only pool custody");
        swarmDistributor = makeAddr("test-only Swarm distributor");
        unrelatedWallet = makeAddr("unrelated wallet");
        factory = new FactoryAllocationModel();
        token = factory.deployAndAllocate(poolCustody, swarmDistributor, REQUESTER);
    }

    function test_factoryReceivesAllSupplyBeforeAnyAllocation() public {
        LaunchToken fresh = factory.deployToken();
        assertEq(fresh.totalSupply(), SUPPLY);
        assertEq(fresh.balanceOf(address(factory)), SUPPLY);
        assertEq(fresh.balanceOf(REQUESTER), 0);
        assertEq(fresh.balanceOf(RESERVE), 0);
        assertEq(fresh.balanceOf(address(this)), 0);
    }

    function test_factoryAllocationIsEightyTenTenWithNoReserveTransfer() public view {
        assertEq(token.balanceOf(poolCustody), 800_000_000e18);
        assertEq(token.balanceOf(swarmDistributor), 100_000_000e18);
        assertEq(token.balanceOf(REQUESTER), 100_000_000e18);
        assertEq(token.balanceOf(RESERVE), 0);
        assertEq(token.balanceOf(address(factory)), 0);
        _assertConservation();
    }

    function test_requesterSeparatelyTransfersExactlyEightPercentToReserve() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(REQUESTER, RESERVE, 80_000_000e18);
        vm.prank(REQUESTER);
        assertTrue(token.transfer(RESERVE, 80_000_000e18));
        assertEq(token.balanceOf(RESERVE), 80_000_000e18);
        assertEq(token.balanceOf(REQUESTER), 20_000_000e18);
        assertEq(token.balanceOf(poolCustody), 800_000_000e18);
        assertEq(token.balanceOf(swarmDistributor), 100_000_000e18);
        _assertConservation();
    }

    function test_bothWalletAllocationsAreImmediatelyTransferable() public {
        vm.prank(REQUESTER);
        token.transfer(RESERVE, 80_000_000e18);
        // No block or timestamp advance between allocation, reserve funding and spending.
        vm.prank(REQUESTER);
        assertTrue(token.transfer(unrelatedWallet, 20_000_000e18));
        vm.prank(RESERVE);
        assertTrue(token.transfer(unrelatedWallet, 80_000_000e18));
        assertEq(token.balanceOf(unrelatedWallet), 100_000_000e18);
        assertEq(token.balanceOf(REQUESTER), 0);
        assertEq(token.balanceOf(RESERVE), 0);
        _assertConservation();
    }

    function test_reserveTransferNeedsRequesterOrItsAllowance() public {
        address[3] memory unauthorized = [address(factory), RESERVE, unrelatedWallet];
        for (uint256 i; i < unauthorized.length; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IERC20Errors.ERC20InsufficientAllowance.selector, unauthorized[i], 0, 80_000_000e18
                )
            );
            vm.prank(unauthorized[i]);
            token.transferFrom(REQUESTER, RESERVE, 80_000_000e18);
        }
        assertEq(token.balanceOf(REQUESTER), 100_000_000e18);
        assertEq(token.balanceOf(RESERVE), 0);
        _assertConservation();
    }

    function test_repeatingReserveTransferWithoutNewFundsFails() public {
        vm.prank(REQUESTER);
        token.transfer(RESERVE, 80_000_000e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, REQUESTER, 20_000_000e18, 80_000_000e18
            )
        );
        vm.prank(REQUESTER);
        token.transfer(RESERVE, 80_000_000e18);
        assertEq(token.balanceOf(REQUESTER), 20_000_000e18);
        assertEq(token.balanceOf(RESERVE), 80_000_000e18);
        _assertConservation();
    }

    function test_requesterCannotSpendSwarmOrPoolAllocation() public {
        address[2] memory protocolCustody = [poolCustody, swarmDistributor];
        for (uint256 i; i < protocolCustody.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, REQUESTER, 0, 1));
            vm.prank(REQUESTER);
            token.transferFrom(protocolCustody[i], REQUESTER, 1);
        }
        assertEq(token.balanceOf(poolCustody), 800_000_000e18);
        assertEq(token.balanceOf(swarmDistributor), 100_000_000e18);
        _assertConservation();
    }

    function _assertConservation() internal view {
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(
            token.balanceOf(poolCustody) + token.balanceOf(swarmDistributor) + token.balanceOf(REQUESTER)
                + token.balanceOf(RESERVE) + token.balanceOf(unrelatedWallet) + token.balanceOf(address(factory)),
            SUPPLY
        );
    }
}
