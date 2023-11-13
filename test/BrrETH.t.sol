// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Helper} from "test/Helper.sol";
import {BrrETH} from "src/BrrETH.sol";

contract BrrETHTest is Helper, Test {
    using SafeTransferLib for address;

    BrrETH public immutable vault = new BrrETH(address(this));

    constructor() {
        _WETH_ADDR.safeApprove(_COMET_ADDR, type(uint256).max);
        _COMET_ADDR.safeApprove(address(vault), type(uint256).max);
    }

    function _getCWETH(uint256 amount) private returns (uint256 balance) {
        deal(_WETH_ADDR, address(this), amount);

        balance = _COMET.balanceOf(address(this));

        _COMET.supply(_WETH_ADDR, amount);

        balance = _COMET.balanceOf(address(this)) - balance;
    }

    /*//////////////////////////////////////////////////////////////
                             constructor
    //////////////////////////////////////////////////////////////*/

    function testConstructor() external {
        assertEq(
            type(uint256).max,
            ERC20(_WETH_ADDR).allowance(address(vault), _COMET_ADDR)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             name
    //////////////////////////////////////////////////////////////*/

    function testName() external {
        assertEq(_NAME, vault.name());
    }

    /*//////////////////////////////////////////////////////////////
                             symbol
    //////////////////////////////////////////////////////////////*/

    function testSymbol() external {
        assertEq(_SYMBOL, vault.symbol());
    }

    /*//////////////////////////////////////////////////////////////
                             asset
    //////////////////////////////////////////////////////////////*/

    function testAsset() external {
        assertEq(_COMET_ADDR, vault.asset());
    }

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositAssetsGreaterThanBalance() external {
        _getCWETH(1 ether);

        uint256 assets = type(uint256).max;
        address to = address(this);

        vm.expectRevert(BrrETH.AssetsGreaterThanBalance.selector);

        vault.deposit(assets, to);
    }

    function testCannotDepositAssetsGreaterThanBalanceFuzz(
        uint80 balance
    ) external {
        vm.assume(balance != 0);

        _getCWETH(balance);

        uint256 assets = uint256(balance) + 1;
        address to = address(this);

        vm.expectRevert(BrrETH.AssetsGreaterThanBalance.selector);

        vault.deposit(assets, to);
    }

    /*//////////////////////////////////////////////////////////////
                             mint
    //////////////////////////////////////////////////////////////*/

    function testCannotMintAssetsGreaterThanBalance() external {
        _getCWETH(1 ether);

        uint256 assets = type(uint256).max;
        address to = address(this);

        vm.expectRevert(BrrETH.AssetsGreaterThanBalance.selector);

        vault.deposit(assets, to);
    }
}
