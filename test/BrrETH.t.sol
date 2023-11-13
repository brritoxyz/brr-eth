// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Helper} from "test/Helper.sol";
import {BrrETH} from "src/BrrETH.sol";

contract BrrETHTest is Helper, Test {
    using SafeTransferLib for address;

    address public immutable owner = address(this);
    BrrETH public immutable vault = new BrrETH(owner);

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
        assertEq(owner, vault.owner());
        assertEq(
            type(uint256).max,
            ERC20(_WETH_ADDR).allowance(address(vault), _COMET_ADDR)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             addRewardToken
    //////////////////////////////////////////////////////////////*/

    function testCannotAddRewardTokenUnauthorized() external {
        address msgSender = address(0);

        assertTrue(msgSender != owner);

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.addRewardToken(_COMP_ADDR);
    }

    function testAddRewardToken() external {
        address msgSender = owner;
        address rewardToken = _COMP_ADDR;
        address[] memory rewardTokens = vault.rewardTokens();

        assertEq(rewardTokens.length, 0);
        assertEq(ERC20(rewardToken).allowance(address(vault), _ROUTER_ADDR), 0);

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(vault));

        emit BrrETH.AddRewardToken(rewardToken);

        vault.addRewardToken(rewardToken);

        rewardTokens = vault.rewardTokens();

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], rewardToken);
        assertEq(
            ERC20(rewardToken).allowance(address(vault), _ROUTER_ADDR),
            type(uint256).max
        );
    }

    /*//////////////////////////////////////////////////////////////
                             removeRewardToken
    //////////////////////////////////////////////////////////////*/

    function testCannotRemoveRewardTokenUnauthorized() external {
        address msgSender = address(0);
        uint256 index = 0;

        assertTrue(msgSender != owner);

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.removeRewardToken(index);
    }

    function testRemoveRewardToken() external {
        address msgSender = owner;

        vm.startPrank(msgSender);

        vault.addRewardToken(_COMP_ADDR);
        vault.addRewardToken(_WETH_ADDR);

        address[] memory rewardTokens = vault.rewardTokens();
        uint256 index = 0;

        assertEq(rewardTokens.length, 2);
        assertEq(rewardTokens[0], _COMP_ADDR);
        assertEq(rewardTokens[1], _WETH_ADDR);

        vm.expectEmit(false, false, false, true, address(vault));

        emit BrrETH.RemoveRewardToken(_COMP_ADDR);

        vault.removeRewardToken(index);

        rewardTokens = vault.rewardTokens();

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], _WETH_ADDR);

        vault.addRewardToken(_COMP_ADDR);

        emit BrrETH.RemoveRewardToken(_WETH_ADDR);

        vault.removeRewardToken(index);

        rewardTokens = vault.rewardTokens();

        assertEq(rewardTokens.length, 1);
        assertEq(rewardTokens[0], _COMP_ADDR);

        vault.removeRewardToken(index);

        rewardTokens = vault.rewardTokens();

        assertEq(rewardTokens.length, 0);

        vm.stopPrank();
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
