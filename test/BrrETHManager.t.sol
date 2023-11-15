// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Helper} from "test/Helper.sol";
import {BrrETH} from "src/BrrETH.sol";
import {BrrETHManager} from "src/BrrETHManager.sol";

contract BrrETHManagerTest is Helper {
    using SafeTransferLib for address;

    BrrETH public immutable vault = new BrrETH(address(this));
    BrrETHManager public immutable manager = new BrrETHManager(address(vault));

    constructor() {
        _WETH.safeApproveWithRetry(address(manager), type(uint256).max);
    }

    function _getAssets(uint256 assets) private pure returns (uint256) {
        return (assets * 9_999) / 10_000;
    }

    /*//////////////////////////////////////////////////////////////
                             constructor
    //////////////////////////////////////////////////////////////*/

    function testConstructor() external {
        assertEq(address(vault), address(manager.brrETH()));
        assertEq(
            type(uint256).max,
            ERC20(_WETH).allowance(address(manager), _COMET)
        );
        assertEq(
            type(uint256).max,
            ERC20(_COMET).allowance(address(manager), address(vault))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             approveTokens
    //////////////////////////////////////////////////////////////*/

    function testApproveTokens() external {
        vm.startPrank(address(manager));

        _WETH.safeApprove(_COMET, 0);
        _COMET.safeApprove(address(vault), 0);

        vm.stopPrank();

        assertEq(0, ERC20(_WETH).allowance(address(manager), _COMET));
        assertEq(0, ERC20(_COMET).allowance(address(manager), address(vault)));

        manager.approveTokens();

        assertEq(
            type(uint256).max,
            ERC20(_WETH).allowance(address(manager), _COMET)
        );
        assertEq(
            type(uint256).max,
            ERC20(_COMET).allowance(address(manager), address(vault))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             deposit (ETH)
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositETHInvalidAmount() external {
        uint256 amount = 0;
        address to = address(this);

        vm.expectRevert(BrrETHManager.InvalidAmount.selector);

        manager.deposit{value: amount}(to);
    }

    function testCannotDepositETHInvalidAddress() external {
        uint256 amount = 1;
        address to = address(0);

        vm.expectRevert(BrrETHManager.InvalidAddress.selector);

        manager.deposit{value: amount}(to);
    }

    function testDepositETH() external {
        uint256 amount = 1 ether;
        address to = address(this);
        uint256 assetBalanceBefore = _COMET.balanceOf(address(vault));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 shares = manager.deposit{value: amount}(to);

        assertLe(
            _getAssets(assetBalanceBefore + amount),
            _COMET.balanceOf(address(vault))
        );
        assertEq(sharesBalanceBefore + shares, vault.balanceOf(to));
    }

    function testDepositETHFuzz(uint80 amount, address to) external {
        vm.assume(amount > 0.1 ether && to != address(0));

        uint256 assetBalanceBefore = _COMET.balanceOf(address(vault));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 shares = manager.deposit{value: amount}(to);

        assertLe(
            _getAssets(assetBalanceBefore + amount),
            _COMET.balanceOf(address(vault))
        );
        assertEq(sharesBalanceBefore + shares, vault.balanceOf(to));
    }

    /*//////////////////////////////////////////////////////////////
                             deposit (WETH)
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositWETHInvalidAmount() external {
        uint256 amount = 0;
        address to = address(this);

        vm.expectRevert(BrrETHManager.InvalidAmount.selector);

        manager.deposit(amount, to);
    }

    function testCannotDepositWETHInvalidAddress() external {
        uint256 amount = 1;
        address to = address(0);

        deal(_WETH, address(this), amount);

        vm.expectRevert(BrrETHManager.InvalidAddress.selector);

        manager.deposit(amount, to);
    }

    function testDepositWETH() external {
        uint256 amount = 1 ether;
        address to = address(this);

        deal(_WETH, address(this), amount);

        uint256 assetBalanceBefore = _COMET.balanceOf(address(vault));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 shares = manager.deposit(amount, to);

        assertLe(
            _getAssets(assetBalanceBefore + amount),
            _COMET.balanceOf(address(vault))
        );
        assertEq(sharesBalanceBefore + shares, vault.balanceOf(to));
    }

    function testDepositWETHFuzz(uint80 amount, address to) external {
        vm.assume(amount > 0.1 ether && to != address(0));

        deal(_WETH, address(this), amount);

        uint256 assetBalanceBefore = _COMET.balanceOf(address(vault));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 shares = manager.deposit(amount, to);

        assertLe(
            _getAssets(assetBalanceBefore + amount),
            _COMET.balanceOf(address(vault))
        );
        assertEq(sharesBalanceBefore + shares, vault.balanceOf(to));
    }
}
