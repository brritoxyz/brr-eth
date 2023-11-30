// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Helper} from "test/Helper.sol";
import {BrrETH} from "src/BrrETH.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

interface IComet2 {
    function accrueAccount(address account) external;

    function withdraw(address asset, uint amount) external;
}

contract BrrETHTest is Helper {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    address public immutable owner = address(this);
    BrrETH public immutable vault = new BrrETH(address(this));

    constructor() {
        _WETH.safeApproveWithRetry(_COMET, type(uint256).max);
        _COMET.safeApproveWithRetry(address(vault), type(uint256).max);
    }

    function _getCWETH(uint256 amount) internal returns (uint256 balance) {
        deal(_WETH, address(this), amount);

        balance = _COMET.balanceOf(address(this));

        IComet(_COMET).supply(_WETH, amount);

        balance = _COMET.balanceOf(address(this)) - balance;
    }

    function _calculateFees(
        uint256 amount
    ) internal view returns (uint256 ownerShare, uint256 feeDistributorShare) {
        uint256 rewardFee = vault.rewardFee();
        uint256 rewardFeeShare = amount.mulDiv(rewardFee, _FEE_BASE);
        ownerShare = rewardFeeShare / 2;
        feeDistributorShare = rewardFeeShare - ownerShare;
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
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositInsufficientAssets() external {
        uint256 assets = _MIN_DEPOSIT - 1;
        address to = address(this);

        vm.expectRevert(BrrETH.InsufficientAssets.selector);

        vault.deposit(assets, to);
    }

    function testCannotDepositExcessiveAssets() external {
        uint256 assets = type(uint256).max;
        address to = address(this);

        vm.expectRevert(BrrETH.ExcessiveAssets.selector);

        vault.deposit(assets, to);
    }

    function testCannotDepositTransferFromFailed() external {
        uint256 assets = 1e18;
        address to = address(this);

        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);

        vault.deposit(assets, to);
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
                             harvest
    //////////////////////////////////////////////////////////////*/

    function testHarvest() external {
        uint256 assets = 10000000000000401;
        uint256 accrualTime = 187;

        _getCWETH(assets);

        vault.deposit(assets, address(this));

        skip(accrualTime);

        IComet(_COMET).accrueAccount(address(vault));

        IComet.UserBasic memory userBasic = IComet(_COMET).userBasic(
            address(vault)
        );
        uint256 rewards = userBasic.baseTrackingAccrued * 1e12;

        if (rewards == 0) return;

        (, uint256 quote) = IRouter(_ROUTER).getSwapOutput(
            keccak256(abi.encodePacked(_COMP, _WETH)),
            rewards
        );
        (uint256 ownerShare, uint256 feeDistributorShare) = _calculateFees(
            quote
        );
        quote -= ownerShare + feeDistributorShare;
        uint256 newAssets = quote - 1;
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 ownerBalance = _WETH.balanceOf(vault.owner());
        uint256 feeDistributorBalance = _WETH.balanceOf(vault.feeDistributor());

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.Harvest(
            _COMP,
            rewards,
            quote,
            ownerShare + feeDistributorShare
        );

        vault.harvest();

        assertEq(totalAssets + newAssets, vault.totalAssets());
        assertEq(totalSupply, vault.totalSupply());

        if (vault.owner() == vault.feeDistributor()) {
            assertEq(
                ownerBalance + ownerShare + feeDistributorShare,
                _WETH.balanceOf(vault.owner())
            );
        } else {
            assertEq(ownerBalance + ownerShare, _WETH.balanceOf(vault.owner()));
            assertEq(
                feeDistributorBalance + feeDistributorShare,
                _WETH.balanceOf(vault.feeDistributor())
            );
        }
    }

    function testHarvestFuzz(uint80 assets, uint24 accrualTime) external {
        vm.assume(assets > 0.01 ether && accrualTime > 100);

        _getCWETH(assets);

        vault.deposit(assets, address(this));

        skip(accrualTime);

        IComet(_COMET).accrueAccount(address(vault));

        IComet.UserBasic memory userBasic = IComet(_COMET).userBasic(
            address(vault)
        );
        uint256 rewards = uint256(userBasic.baseTrackingAccrued) * 1e12;

        if (rewards == 0) return;

        (, uint256 quote) = IRouter(_ROUTER).getSwapOutput(
            keccak256(abi.encodePacked(_COMP, _WETH)),
            rewards
        );
        (uint256 ownerShare, uint256 feeDistributorShare) = _calculateFees(
            quote
        );
        quote -= ownerShare + feeDistributorShare;
        uint256 newAssets = quote - 5;
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 ownerBalance = _WETH.balanceOf(vault.owner());
        uint256 feeDistributorBalance = _WETH.balanceOf(vault.feeDistributor());

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.Harvest(
            _COMP,
            rewards,
            quote,
            ownerShare + feeDistributorShare
        );

        vault.harvest();

        assertLe(totalAssets + newAssets, vault.totalAssets());
        assertEq(totalSupply, vault.totalSupply());

        if (vault.owner() == vault.feeDistributor()) {
            assertEq(
                ownerBalance + ownerShare + feeDistributorShare,
                _WETH.balanceOf(vault.owner())
            );
        } else {
            assertEq(ownerBalance + ownerShare, _WETH.balanceOf(vault.owner()));
            assertEq(
                feeDistributorBalance + feeDistributorShare,
                _WETH.balanceOf(vault.feeDistributor())
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                             setRewardFee
    //////////////////////////////////////////////////////////////*/

    function testCannotSetRewardFeeUnauthorized() external {
        address msgSender = address(0);
        uint256 rewardFee = 0;

        assertTrue(msgSender != vault.owner());

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.setRewardFee(rewardFee);
    }

    function testCannotSetRewardFeeInvalidRewardFee() external {
        uint256 rewardFee = _MAX_REWARD_FEE + 1;

        vm.expectRevert(BrrETH.InvalidRewardFee.selector);

        vault.setRewardFee(rewardFee);
    }

    function testSetRewardFee() external {
        uint256 rewardFee = 0;

        assertTrue(rewardFee != vault.rewardFee());

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetRewardFee(rewardFee);

        vault.setRewardFee(rewardFee);

        assertEq(rewardFee, vault.rewardFee());
    }

    function testSetRewardFeeFuzz(uint16 rewardFee) external {
        vm.assume(
            rewardFee != vault.rewardFee() && rewardFee <= _MAX_REWARD_FEE
        );
        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetRewardFee(rewardFee);

        vault.setRewardFee(rewardFee);

        assertEq(rewardFee, vault.rewardFee());
    }

    /*//////////////////////////////////////////////////////////////
                             setFeeDistributor
    //////////////////////////////////////////////////////////////*/

    function testCannotSetFeeDistributorUnauthorized() external {
        address msgSender = address(0);
        uint256 rewardFee = 0;

        assertTrue(msgSender != vault.owner());

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.setRewardFee(rewardFee);
    }

    function testCannotSetFeeDistributorInvalidFeeDistributor() external {
        address feeDistributor = address(0);

        vm.expectRevert(BrrETH.InvalidFeeDistributor.selector);

        vault.setFeeDistributor(feeDistributor);
    }

    function testSetFeeDistributor() external {
        address feeDistributor = address(0xbeef);

        assertTrue(feeDistributor != vault.feeDistributor());

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetFeeDistributor(feeDistributor);

        vault.setFeeDistributor(feeDistributor);

        assertEq(feeDistributor, vault.feeDistributor());
    }
}
