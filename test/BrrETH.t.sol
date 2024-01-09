// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Helper} from "test/Helper.sol";
import {BrrETH} from "src/BrrETH.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

contract BrrETHTest is Helper {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    address public immutable owner = address(this);
    BrrETH public immutable vault = new BrrETH(address(this));
    address[10] public anvilAccounts = [
        address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266),
        address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
        address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC),
        address(0x90F79bf6EB2c4f870365E785982E1f101E93b906),
        address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65),
        address(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc),
        address(0x976EA74026E726554dB657fA54763abd0C3a0aa9),
        address(0x14dC79964da2C08b23698B3D3cc7Ca32193d9955),
        address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f),
        address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720)
    ];

    constructor() {
        // Allow Comet to transfer WETH on our behalf.
        _WETH.safeApproveWithRetry(_COMET, type(uint256).max);

        // Allow the vault to transfer cWETHv3 on our behalf.
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
    )
        internal
        view
        returns (
            uint256 ownerShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        )
    {
        uint256 rewardFee = vault.rewardFee();
        uint256 rewardFeeShare = amount.mulDiv(rewardFee, _FEE_BASE);
        uint256 preFeeAmount = amount.mulDiv(_FEE_BASE, _SWAP_FEE_DEDUCTED);
        ownerShare = rewardFeeShare / 2;
        feeDistributorShare = rewardFeeShare - ownerShare;
        feeDistributorSwapFeeShare =
            (preFeeAmount -
                preFeeAmount.mulDiv(_SWAP_FEE_DEDUCTED, _FEE_BASE)) /
            2;
    }

    /*//////////////////////////////////////////////////////////////
                             constructor
    //////////////////////////////////////////////////////////////*/

    function testConstructor() external {
        // The initial `feeDistributor` is set to the owner to avoid zero address transfers.
        assertEq(owner, vault.feeDistributor());

        assertEq(owner, vault.owner());

        // Comet must have max allowance for the purposes of supplying WETH for cWETHv3.
        assertEq(
            type(uint256).max,
            ERC20(_WETH).allowance(address(vault), _COMET)
        );

        // The router must have max allowance for the purposes of swapping COMP for WETH.
        assertEq(
            type(uint256).max,
            ERC20(_COMP).allowance(address(vault), _ROUTER)
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
                             deposit (ETH)
    //////////////////////////////////////////////////////////////*/

    function testDepositETH() external {
        uint256 assets = 1 ether;
        address to = address(this);
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        // Comet rounds down transfer amounts, making it difficult to check the final emitted values.
        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, assets, 0);

        uint256 shares = vault.deposit{value: assets}(to);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        assertEq(expectedShares, shares);
        assertEq(shares, totalSupplyAfter - totalSupplyBefore);
        assertEq(shares, vault.balanceOf(to));
        assertLe(totalSupplyAfter, totalAssetsAfter);
    }

    function testDepositETHMultiple() external {
        uint256 baseAsset = 0.001 ether;
        uint256 totalSupply = 0;
        uint256 totalAssets = 0;

        for (uint256 i = 0; i < anvilAccounts.length; ++i) {
            uint256 assets = baseAsset * (i + 1);
            uint256 totalSupplyBefore = vault.totalSupply();
            uint256 totalAssetsBefore = vault.totalAssets();

            vm.expectEmit(true, true, true, false, address(vault));

            emit ERC4626.Deposit(address(this), anvilAccounts[i], assets, 0);

            uint256 shares = vault.deposit{value: assets}(anvilAccounts[i]);
            uint256 totalSupplyAfter = vault.totalSupply();
            uint256 totalAssetsAfter = vault.totalAssets();
            uint256 expectedShares = vault.convertToShares(
                totalAssetsAfter - totalAssetsBefore,
                totalSupplyBefore,
                totalAssetsBefore
            );
            totalSupply += totalSupplyAfter - totalSupplyBefore;
            totalAssets += totalAssetsAfter - totalAssetsBefore;

            assertLt(0, shares);
            assertEq(expectedShares, shares);
            assertEq(shares, totalSupplyAfter - totalSupplyBefore);
            assertEq(shares, vault.balanceOf(anvilAccounts[i]));
            assertLe(totalSupplyAfter, totalAssetsAfter);
        }

        assertEq(totalSupply, vault.totalSupply());
        assertEq(totalAssets, vault.totalAssets());
    }

    function testDepositETHFuzz(uint80 assets, address to) external {
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, assets, 0);

        uint256 shares = vault.deposit{value: assets}(to);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        assertEq(expectedShares, shares);
        assertEq(shares, totalSupplyAfter - totalSupplyBefore);
        assertEq(shares, vault.balanceOf(to));
        assertLe(totalSupplyAfter, totalAssetsAfter);
    }

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositDepositMoreThanMax() external {
        uint256 assets = type(uint256).max;
        address to = address(this);

        assertLt(_COMET.balanceOf(address(this)), assets);

        vm.expectRevert(ERC4626.DepositMoreThanMax.selector);

        vault.deposit(assets, to);
    }

    function testCannotDepositDepositMoreThanMaxFuzz(uint256 assets) external {
        vm.assume(assets != 0);

        address to = address(this);

        assertLt(_COMET.balanceOf(address(this)), assets);

        vm.expectRevert(ERC4626.DepositMoreThanMax.selector);

        vault.deposit(assets, to);
    }

    function testDeposit() external {
        uint256 assets = _getCWETH(1e18);
        address to = address(this);
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        // Comet rounds down transfer amounts, making it difficult to check the final emitted values.
        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, assets, 0);

        uint256 shares = vault.deposit(assets, to);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        assertEq(expectedShares, shares);
        assertEq(shares, totalSupplyAfter - totalSupplyBefore);
        assertEq(shares, vault.balanceOf(to));
        assertLe(totalSupplyAfter, totalAssetsAfter);
    }

    function testDepositMultiple() external {
        uint256 baseAsset = 0.001 ether;
        uint256 totalSupply = 0;
        uint256 totalAssets = 0;

        for (uint256 i = 0; i < anvilAccounts.length; ++i) {
            uint256 asset = _getCWETH(baseAsset * (i + 1));
            uint256 totalSupplyBefore = vault.totalSupply();
            uint256 totalAssetsBefore = vault.totalAssets();

            vm.expectEmit(true, true, true, false, address(vault));

            emit ERC4626.Deposit(address(this), anvilAccounts[i], asset, 0);

            uint256 shares = vault.deposit(asset, anvilAccounts[i]);
            uint256 totalSupplyAfter = vault.totalSupply();
            uint256 totalAssetsAfter = vault.totalAssets();
            uint256 expectedShares = vault.convertToShares(
                totalAssetsAfter - totalAssetsBefore,
                totalSupplyBefore,
                totalAssetsBefore
            );
            totalSupply += totalSupplyAfter - totalSupplyBefore;
            totalAssets += totalAssetsAfter - totalAssetsBefore;

            assertLt(0, shares);
            assertEq(expectedShares, shares);
            assertEq(shares, totalSupplyAfter - totalSupplyBefore);
            assertEq(shares, vault.balanceOf(anvilAccounts[i]));
            assertLe(totalSupplyAfter, totalAssetsAfter);
        }

        assertEq(totalSupply, vault.totalSupply());
        assertEq(totalAssets, vault.totalAssets());
    }

    function testDepositFuzz(uint80 assets, address to) external {
        assets = uint80(_getCWETH(assets));
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, assets, 0);

        uint256 shares = vault.deposit(assets, to);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        assertEq(expectedShares, shares);
        assertEq(shares, totalSupplyAfter - totalSupplyBefore);
        assertEq(shares, vault.balanceOf(to));
        assertLe(totalSupplyAfter, totalAssetsAfter);
    }

    /*//////////////////////////////////////////////////////////////
                             harvest
    //////////////////////////////////////////////////////////////*/

    function testHarvest() external {
        uint256 assets = 1e18;
        uint256 accrualTime = 1 days;

        _getCWETH(assets);

        // Reassign `assets` since Comet rounds down 1.
        assets = _COMET.balanceOf(address(this));

        vault.deposit(assets, address(this));

        skip(accrualTime);

        IComet(_COMET).accrueAccount(address(vault));

        IComet.UserBasic memory userBasic = IComet(_COMET).userBasic(
            address(vault)
        );
        uint256 rewards = userBasic.baseTrackingAccrued * 1e12;
        (, uint256 quote) = IRouter(_ROUTER).getSwapOutput(
            keccak256(abi.encodePacked(_COMP, _WETH)),
            rewards
        );
        (
            uint256 ownerShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        ) = _calculateFees(quote);
        quote -= ownerShare + feeDistributorShare;
        uint256 newAssets = quote - 1;
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 ownerBalance = _WETH.balanceOf(vault.owner());

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
        assertEq(
            ownerBalance +
                ownerShare +
                feeDistributorShare +
                feeDistributorSwapFeeShare,
            _WETH.balanceOf(vault.owner())
        );
    }

    function testHarvestFuzz(
        uint80 assets,
        uint24 accrualTime,
        bool setFeeDistributor
    ) external {
        vm.assume(assets > 0.01 ether && accrualTime > 100);

        // Randomly set the fee distributor to test proper fee distribution across two different accounts.
        if (setFeeDistributor) vault.setFeeDistributor(address(0xbeef));

        _getCWETH(assets);

        assets = uint80(_COMET.balanceOf(address(this)));

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
        (
            uint256 ownerShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        ) = _calculateFees(quote);
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
                ownerBalance +
                    ownerShare +
                    feeDistributorShare +
                    feeDistributorSwapFeeShare,
                _WETH.balanceOf(vault.owner())
            );
        } else {
            assertEq(ownerBalance + ownerShare, _WETH.balanceOf(vault.owner()));
            assertEq(
                feeDistributorBalance +
                    feeDistributorShare +
                    feeDistributorSwapFeeShare,
                _WETH.balanceOf(vault.feeDistributor())
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                             setCometRewards
    //////////////////////////////////////////////////////////////*/

    function testCannotSetCometRewardsUnauthorized() external {
        address msgSender = address(0);
        address cometRewards = address(0xbeef);

        assertTrue(msgSender != vault.owner());

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.setCometRewards(cometRewards);
    }

    function testCannotSetCometRewardsInvalidCometRewards() external {
        address cometRewards = address(0);

        vm.expectRevert(BrrETH.InvalidCometRewards.selector);

        vault.setCometRewards(cometRewards);
    }

    function testSetCometRewards() external {
        address cometRewards = address(0xbeef);

        assertTrue(cometRewards != address(vault.cometRewards()));

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetCometRewards(cometRewards);

        vault.setCometRewards(cometRewards);

        assertEq(cometRewards, address(vault.cometRewards()));
    }

    function testSetCometRewardsFuzz(address cometRewards) external {
        vm.assume(
            cometRewards != address(0) &&
                cometRewards != address(vault.cometRewards())
        );

        assertTrue(cometRewards != address(vault.cometRewards()));

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetCometRewards(cometRewards);

        vault.setCometRewards(cometRewards);

        assertEq(cometRewards, address(vault.cometRewards()));
    }

    /*//////////////////////////////////////////////////////////////
                             setRouter
    //////////////////////////////////////////////////////////////*/

    function testCannotSetRouterUnauthorized() external {
        address msgSender = address(0);
        address router = address(0xbeef);

        assertTrue(msgSender != vault.owner());

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.setRouter(router);
    }

    function testCannotSetRouterInvalidCometRewards() external {
        address router = address(0);

        vm.expectRevert(BrrETH.InvalidRouter.selector);

        vault.setRouter(router);
    }

    function testSetRouter() external {
        address router = address(0xbeef);

        assertTrue(router != address(vault.router()));

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetRouter(router);

        vault.setRouter(router);

        assertEq(router, address(vault.router()));
    }

    function testSetRouterFuzz(address router) external {
        vm.assume(router != address(0));

        assertTrue(router != address(vault.router()));

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetRouter(router);

        vault.setRouter(router);

        assertEq(router, address(vault.router()));
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
                             setProtocolFeeReceiver
    //////////////////////////////////////////////////////////////*/

    function testCannotSetProtocolFeeReceiverUnauthorized() external {
        address msgSender = address(0);
        address protocolFeeReceiver = address(0xbeef);

        assertTrue(msgSender != vault.owner());

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.setProtocolFeeReceiver(protocolFeeReceiver);
    }

    function testCannotSetProtocolFeeReceiverInvalidProtocolFeeReceiver()
        external
    {
        address msgSender = vault.owner();
        address protocolFeeReceiver = address(0);

        vm.prank(msgSender);
        vm.expectRevert(BrrETH.InvalidProtocolFeeReceiver.selector);

        vault.setProtocolFeeReceiver(protocolFeeReceiver);
    }

    function testSetProtocolFeeReceiver() external {
        address msgSender = vault.owner();
        address protocolFeeReceiver = address(0xbeef);

        assertTrue(protocolFeeReceiver != vault.protocolFeeReceiver());

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetProtocolFeeReceiver(protocolFeeReceiver);

        vault.setProtocolFeeReceiver(protocolFeeReceiver);

        assertEq(protocolFeeReceiver, vault.protocolFeeReceiver());
    }

    /*//////////////////////////////////////////////////////////////
                             setFeeDistributor
    //////////////////////////////////////////////////////////////*/

    function testCannotSetFeeDistributorUnauthorized() external {
        address msgSender = address(0);
        address feeDistributor = address(0xbeef);

        assertTrue(msgSender != vault.owner());

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.setFeeDistributor(feeDistributor);
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
