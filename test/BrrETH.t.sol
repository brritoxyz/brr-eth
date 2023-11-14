// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Helper} from "test/Helper.sol";
import {BrrETH} from "src/BrrETH.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

interface IComet2 {
    function accrueAccount(address account) external;

    function withdraw(address asset, uint amount) external;
}

contract BrrETHTest is Helper, Test {
    using SafeTransferLib for address;

    address public immutable owner = address(this);
    BrrETH public immutable vault = new BrrETH();

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
        assertEq(
            type(uint256).max,
            ERC20(_WETH).allowance(address(vault), _COMET)
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
        assertEq(_COMET, vault.asset());
    }

    /*//////////////////////////////////////////////////////////////
                             approveTokens
    //////////////////////////////////////////////////////////////*/

    function testApproveTokens() external {
        vm.startPrank(address(vault));

        _WETH.safeApprove(_COMET, 0);
        _COMP.safeApprove(_ROUTER, 0);

        vm.stopPrank();

        assertEq(ERC20(_WETH).allowance(address(vault), _COMET), 0);
        assertEq(ERC20(_COMP).allowance(address(vault), _ROUTER), 0);

        vault.approveTokens();

        assertEq(
            ERC20(_WETH).allowance(address(vault), _COMET),
            type(uint256).max
        );
        assertEq(
            ERC20(_COMP).allowance(address(vault), _ROUTER),
            type(uint256).max
        );
    }

    /*//////////////////////////////////////////////////////////////
                             rebase
    //////////////////////////////////////////////////////////////*/

    function testRebase() external {
        _getCWETH(10 ether);

        vault.deposit(10 ether, address(this));

        skip(10_000);

        IComet(_COMET).accrueAccount(address(vault));

        IComet.UserBasic memory userBasic = IComet(_COMET).userBasic(
            address(vault)
        );
        uint256 rewardsBalance = userBasic.baseTrackingAccrued * 1e12;
        (, uint256 output) = IRouter(_ROUTER).getSwapOutput(
            keccak256(abi.encodePacked(_COMP, _WETH)),
            rewardsBalance
        );
        uint256 newAssets = output - 1;
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();

        vault.rebase();

        assertEq(totalAssets + newAssets, vault.totalAssets());
        assertEq(totalSupply, vault.totalSupply());
    }

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositInvalidAssets() external {
        uint256 assets = type(uint256).max;
        address to = address(this);

        vm.expectRevert(BrrETH.InvalidAssets.selector);

        vault.deposit(assets, to);
    }

    function testCannotDepositTransferFromFailed() external {
        uint256 assets = 1e18;
        address to = address(this);

        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);

        vault.deposit(assets, to);
    }
}
