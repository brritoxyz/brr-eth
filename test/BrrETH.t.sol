// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Helper} from "test/Helper.sol";
import {BrrETH} from "src/BrrETH.sol";
import {IComet} from "src/interfaces/IComet.sol";

contract BrrETHTest is Helper, Test {
    using SafeTransferLib for address;

    address public immutable owner = address(this);
    BrrETH public immutable vault = new BrrETH(owner);

    constructor() {
        _WETH.safeApproveWithRetry(_COMET, type(uint256).max);
        _COMET.safeApproveWithRetry(address(vault), type(uint256).max);
    }

    function _getCWETH(uint256 amount) private returns (uint256 balance) {
        deal(_WETH, address(this), amount);

        balance = _COMET.balanceOf(address(this));

        IComet(_COMET).supply(_WETH, amount);

        balance = _COMET.balanceOf(address(this)) - balance;
    }

    /*//////////////////////////////////////////////////////////////
                             constructor
    //////////////////////////////////////////////////////////////*/

    function testConstructor() external {
        assertEq(owner, vault.owner());
        assertEq(
            type(uint256).max,
            ERC20(_WETH).allowance(address(vault), _COMET)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             addRebaseToken
    //////////////////////////////////////////////////////////////*/

    function testCannotAddRebaseTokenUnauthorized() external {
        address msgSender = address(0);

        assertTrue(msgSender != owner);

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.addRebaseToken(_COMP);
    }

    function testAddRebaseToken() external {
        address msgSender = owner;
        address rebaseToken = _COMP;
        address[] memory rebaseTokens = vault.rebaseTokens();

        assertEq(rebaseTokens.length, 0);
        assertEq(ERC20(rebaseToken).allowance(address(vault), _ROUTER_ADDR), 0);

        vm.prank(msgSender);
        vm.expectEmit(false, false, false, true, address(vault));

        emit BrrETH.AddRebaseToken(rebaseToken);

        vault.addRebaseToken(rebaseToken);

        rebaseTokens = vault.rebaseTokens();

        assertEq(rebaseTokens.length, 1);
        assertEq(rebaseTokens[0], rebaseToken);
        assertEq(
            ERC20(rebaseToken).allowance(address(vault), _ROUTER_ADDR),
            type(uint256).max
        );
    }

    /*//////////////////////////////////////////////////////////////
                             removeRebaseToken
    //////////////////////////////////////////////////////////////*/

    function testCannotRemoveRebaseTokenUnauthorized() external {
        address msgSender = address(0);
        uint256 index = 0;

        assertTrue(msgSender != owner);

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.removeRebaseToken(index);
    }

    function testRemoveRebaseToken() external {
        address msgSender = owner;

        vm.startPrank(msgSender);

        vault.addRebaseToken(_COMP);
        vault.addRebaseToken(_WETH);

        address[] memory rebaseTokens = vault.rebaseTokens();
        uint256 index = 0;

        assertEq(rebaseTokens.length, 2);
        assertEq(rebaseTokens[0], _COMP);
        assertEq(rebaseTokens[1], _WETH);

        vm.expectEmit(false, false, false, true, address(vault));

        emit BrrETH.RemoveRebaseToken(_COMP);

        vault.removeRebaseToken(index);

        rebaseTokens = vault.rebaseTokens();

        assertEq(rebaseTokens.length, 1);
        assertEq(rebaseTokens[0], _WETH);

        vault.addRebaseToken(_COMP);

        emit BrrETH.RemoveRebaseToken(_WETH);

        vault.removeRebaseToken(index);

        rebaseTokens = vault.rebaseTokens();

        assertEq(rebaseTokens.length, 1);
        assertEq(rebaseTokens[0], _COMP);

        vault.removeRebaseToken(index);

        rebaseTokens = vault.rebaseTokens();

        assertEq(rebaseTokens.length, 0);

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
        assertEq(_COMET, vault.asset());
    }
}
