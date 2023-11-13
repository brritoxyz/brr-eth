// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Helper} from "test/Helper.sol";
import {BrrETH} from "src/BrrETH.sol";
import {BrrETHDepositor} from "src/BrrETHDepositor.sol";

contract BrrETHDepositorTest is Helper, Test {
    using SafeTransferLib for address;

    BrrETH public immutable vault = new BrrETH(address(this));
    BrrETHDepositor public immutable depositor =
        new BrrETHDepositor(address(vault));

    constructor() {
        _WETH.safeApproveWithRetry(address(depositor), type(uint256).max);
    }

    function _getAssets(uint256 assets) private pure returns (uint256) {
        return (assets * 9_999) / 10_000;
    }

    /*//////////////////////////////////////////////////////////////
                             constructor
    //////////////////////////////////////////////////////////////*/

    function testConstructor() external {
        assertEq(address(vault), address(depositor.brrETH()));
        assertEq(
            type(uint256).max,
            ERC20(_WETH).allowance(address(depositor), _COMET)
        );
        assertEq(
            type(uint256).max,
            ERC20(_COMET).allowance(address(depositor), address(vault))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             deposit (ETH)
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositETHInvalidAmount() external {
        uint256 amount = 0;
        address to = address(this);

        vm.expectRevert(BrrETHDepositor.InvalidAmount.selector);

        depositor.deposit{value: amount}(to);
    }

    function testCannotDepositETHInvalidAddress() external {
        uint256 amount = 1;
        address to = address(0);

        vm.expectRevert(BrrETHDepositor.InvalidAddress.selector);

        depositor.deposit{value: amount}(to);
    }

    function testDepositETH() external {
        uint256 amount = 1 ether;
        address to = address(this);
        uint256 assetBalanceBefore = _COMET.balanceOf(address(vault));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 shares = depositor.deposit{value: amount}(to);

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
        uint256 shares = depositor.deposit{value: amount}(to);

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

        vm.expectRevert(BrrETHDepositor.InvalidAmount.selector);

        depositor.deposit(amount, to);
    }

    function testCannotDepositWETHInvalidAddress() external {
        uint256 amount = 1;
        address to = address(0);

        deal(_WETH, address(this), amount);

        vm.expectRevert(BrrETHDepositor.InvalidAddress.selector);

        depositor.deposit(amount, to);
    }

    function testDepositWETH() external {
        uint256 amount = 1 ether;
        address to = address(this);

        deal(_WETH, address(this), amount);

        uint256 assetBalanceBefore = _COMET.balanceOf(address(vault));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 shares = depositor.deposit(amount, to);

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
        uint256 shares = depositor.deposit(amount, to);

        assertLe(
            _getAssets(assetBalanceBefore + amount),
            _COMET.balanceOf(address(vault))
        );
        assertEq(sharesBalanceBefore + shares, vault.balanceOf(to));
    }
}
