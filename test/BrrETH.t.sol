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
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

contract BrrETHTest is Helper {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

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
            uint256 protocolFeeReceiverShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        )
    {
        uint256 rewardFee = vault.rewardFee();
        uint256 rewardFeeShare = amount.mulDiv(rewardFee, _FEE_BASE);

        // NOTE: The quote-fetching method rounds down, so this may be off by 1.
        // Using `mulDivUp` would not result in the exact value either.
        uint256 preFeeAmount = amount.mulDiv(_FEE_BASE, _SWAP_FEE_DEDUCTED);

        protocolFeeReceiverShare = rewardFeeShare / 2;
        feeDistributorShare = rewardFeeShare - protocolFeeReceiverShare;
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
                             deposit (ETH)
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositETHInsufficientSharesMinted() external {
        uint256 assets = 0;
        address to = address(this);
        uint256 minShares = 1;

        assertLt(
            vault.convertToShares(
                assets,
                vault.totalSupply(),
                vault.totalAssets()
            ),
            minShares
        );

        vm.expectRevert(BrrETH.InsufficientSharesMinted.selector);

        vault.deposit{value: assets}(to, minShares);
    }

    function testDepositETH() external {
        uint256 assets = 1 ether;
        address to = address(this);
        uint256 minShares = vault.convertToShares(
            assets - _COMET_ROUNDING_ERROR_MARGIN,
            vault.totalSupply(),
            vault.totalAssets()
        );
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        // Comet rounds down transfer amounts, making it difficult to check the final emitted values.
        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, assets, 0);

        uint256 shares = vault.deposit{value: assets}(to, minShares);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        assertLe(minShares, shares);
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
            uint256 minShares = vault.convertToShares(
                assets - _COMET_ROUNDING_ERROR_MARGIN,
                vault.totalSupply(),
                vault.totalAssets()
            );
            uint256 totalSupplyBefore = vault.totalSupply();
            uint256 totalAssetsBefore = vault.totalAssets();

            vm.expectEmit(true, true, true, false, address(vault));

            emit ERC4626.Deposit(address(this), anvilAccounts[i], assets, 0);

            uint256 shares = vault.deposit{value: assets}(
                anvilAccounts[i],
                minShares
            );
            uint256 totalSupplyAfter = vault.totalSupply();
            uint256 totalAssetsAfter = vault.totalAssets();
            uint256 expectedShares = vault.convertToShares(
                totalAssetsAfter - totalAssetsBefore,
                totalSupplyBefore,
                totalAssetsBefore
            );
            totalSupply += totalSupplyAfter - totalSupplyBefore;
            totalAssets += totalAssetsAfter - totalAssetsBefore;

            assertLe(minShares, shares);
            assertEq(expectedShares, shares);
            assertEq(shares, totalSupplyAfter - totalSupplyBefore);
            assertEq(shares, vault.balanceOf(anvilAccounts[i]));
            assertLe(totalSupplyAfter, totalAssetsAfter);
        }

        assertEq(totalSupply, vault.totalSupply());
        assertEq(totalAssets, vault.totalAssets());
    }

    function testDepositETHFuzz(uint80 assets, address to) external {
        vm.assume(assets >= _COMET_ROUNDING_ERROR_MARGIN);

        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 minShares = vault.convertToShares(
            uint256(assets) - _COMET_ROUNDING_ERROR_MARGIN,
            vault.totalSupply(),
            vault.totalAssets()
        );

        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, assets, 0);

        uint256 shares = vault.deposit{value: assets}(to, minShares);
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

    function testCannotDepositInsufficientAssetBalance() external {
        uint256 assets = type(uint256).max;
        address to = address(this);

        assertLt(_COMET.balanceOf(address(this)), assets);

        vm.expectRevert(BrrETH.InsufficientAssetBalance.selector);

        vault.deposit(assets, to);
    }

    function testCannotDepositInsufficientAssetBalanceFuzz(
        uint256 assets
    ) external {
        vm.assume(assets != 0);

        address to = address(this);

        assertLt(_COMET.balanceOf(address(this)), assets);

        vm.expectRevert(BrrETH.InsufficientAssetBalance.selector);

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
            uint256 protocolFeeReceiverShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        ) = _calculateFees(quote);
        quote -= protocolFeeReceiverShare + feeDistributorShare;
        uint256 newAssets = quote - _COMET_ROUNDING_ERROR_MARGIN;
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 protocolFeeReceiverBalance = _WETH.balanceOf(
            vault.protocolFeeReceiver()
        );

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.Harvest(
            _COMP,
            rewards,
            quote,
            protocolFeeReceiverShare + feeDistributorShare
        );

        vault.harvest();

        // Takes the Comet rounding error margin into account.
        assertLe(totalAssets + newAssets, vault.totalAssets());

        assertEq(totalSupply, vault.totalSupply());
        assertEq(
            protocolFeeReceiverBalance +
                protocolFeeReceiverShare +
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
            uint256 protocolFeeReceiverShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        ) = _calculateFees(quote);
        quote -= protocolFeeReceiverShare + feeDistributorShare;
        uint256 newAssets = quote - _COMET_ROUNDING_ERROR_MARGIN;
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 protocolFeeReceiverBalance = _WETH.balanceOf(
            vault.protocolFeeReceiver()
        );
        uint256 feeDistributorBalance = _WETH.balanceOf(vault.feeDistributor());

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.Harvest(
            _COMP,
            rewards,
            quote,
            protocolFeeReceiverShare + feeDistributorShare
        );

        vault.harvest();

        assertLe(totalAssets + newAssets, vault.totalAssets());
        assertEq(totalSupply, vault.totalSupply());

        if (vault.owner() == vault.feeDistributor()) {
            // The router's `getSwapOutput` method deducts fees and rounds down. To account for
            // cases where our test calculations are off by 1, we're using `assertLe` - as long
            // as the actual account balances are greater than our calculations, everything is fine.
            assertLe(
                protocolFeeReceiverBalance +
                    protocolFeeReceiverShare +
                    feeDistributorShare +
                    feeDistributorSwapFeeShare,
                _WETH.balanceOf(vault.owner())
            );
        } else {
            assertEq(
                protocolFeeReceiverBalance + protocolFeeReceiverShare,
                _WETH.balanceOf(vault.owner())
            );
            assertLe(
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
        bool shouldHarvest = false;

        assertTrue(msgSender != vault.owner());

        vm.prank(msgSender);
        vm.expectRevert(Ownable.Unauthorized.selector);

        vault.setCometRewards(cometRewards, shouldHarvest);
    }

    function testCannotSetCometRewardsInvalidCometRewards() external {
        address cometRewards = address(0);
        bool shouldHarvest = false;

        vm.expectRevert(BrrETH.InvalidCometRewards.selector);

        vault.setCometRewards(cometRewards, shouldHarvest);
    }

    function testSetCometRewards() external {
        address cometRewards = address(0xbeef);
        bool shouldHarvest = false;

        assertTrue(cometRewards != address(vault.cometRewards()));

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetCometRewards(cometRewards, shouldHarvest);

        vault.setCometRewards(cometRewards, shouldHarvest);

        assertEq(cometRewards, address(vault.cometRewards()));
    }

    function testSetCometRewardsShouldHarvest() external {
        address cometRewards = address(0xbeef);
        bool shouldHarvest = true;

        assertTrue(cometRewards != address(vault.cometRewards()));

        // Deposit and accrue enough time to ensure `harvest` is called (i.e. emits `Harvest` event).
        vault.deposit{value: 1 ether}(address(this), 1);

        skip(1 days);

        // Event members are unchecked, we just need to know that `harvest` was called.
        vm.expectEmit(false, false, false, false, address(vault));

        emit BrrETH.Harvest(_COMP, 0, 0, 0);

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetCometRewards(cometRewards, shouldHarvest);

        vault.setCometRewards(cometRewards, shouldHarvest);

        assertEq(cometRewards, address(vault.cometRewards()));
    }

    function testSetCometRewardsFuzz(
        address cometRewards,
        bool shouldHarvest
    ) external {
        vm.assume(
            cometRewards != address(0) &&
                cometRewards != address(vault.cometRewards())
        );

        assertTrue(cometRewards != address(vault.cometRewards()));

        if (shouldHarvest) {
            vault.deposit{value: 1 ether}(address(this), 1);

            skip(1 days);

            vm.expectEmit(false, false, false, false, address(vault));

            emit BrrETH.Harvest(_COMP, 0, 0, 0);
        }

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetCometRewards(cometRewards, shouldHarvest);

        vault.setCometRewards(cometRewards, shouldHarvest);

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
        ICometRewards.RewardConfig memory rewardConfig = _COMET_REWARDS
            .rewardConfig(_COMET);
        ERC20 rewardToken = ERC20(rewardConfig.token);
        address router = address(0xbeef);

        assertTrue(router != _ROUTER);
        assertEq(0, rewardToken.allowance(address(vault), router));
        assertEq(
            type(uint256).max,
            rewardToken.allowance(address(vault), _ROUTER)
        );

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetRouter(router);

        vault.setRouter(router);

        assertEq(router, address(vault.router()));
        assertEq(
            type(uint256).max,
            rewardToken.allowance(address(vault), router)
        );
        assertEq(0, rewardToken.allowance(address(vault), _ROUTER));
    }

    function testSetRouterFuzz(address router) external {
        vm.assume(router != address(0) && router != _ROUTER);

        ICometRewards.RewardConfig memory rewardConfig = _COMET_REWARDS
            .rewardConfig(_COMET);
        ERC20 rewardToken = ERC20(rewardConfig.token);

        assertEq(0, rewardToken.allowance(address(vault), router));

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrETH.SetRouter(router);

        vault.setRouter(router);

        assertEq(router, address(vault.router()));
        assertEq(
            type(uint256).max,
            rewardToken.allowance(address(vault), router)
        );
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
        uint256 rewardFee = _FEE_BASE + 1;

        vm.expectRevert(BrrETH.InvalidRewardFee.selector);

        vault.setRewardFee(rewardFee);
    }

    function testCannotSetRewardFeeInvalidRewardFeeFuzz(
        uint256 rewardFee
    ) external {
        vm.assume(rewardFee > _FEE_BASE);
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
        vm.assume(rewardFee <= _FEE_BASE);
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

    /*//////////////////////////////////////////////////////////////
                    Removed Ownable methods
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferOwnershipRemovedOwnableMethod() external {
        vm.expectRevert(BrrETH.RemovedOwnableMethod.selector);

        vault.transferOwnership(address(0));
    }

    function testCannotRenounceOwnershipRemovedOwnableMethod() external {
        vm.expectRevert(BrrETH.RemovedOwnableMethod.selector);

        vault.renounceOwnership();
    }

    /*//////////////////////////////////////////////////////////////
                    Removed ERC4626 methods
    //////////////////////////////////////////////////////////////*/

    function testCannotMaxMintRemovedERC4626Method() external {
        vm.expectRevert(BrrETH.RemovedERC4626Method.selector);

        vault.maxMint(address(0));
    }

    function testCannotMaxWithdrawRemovedERC4626Method() external {
        vm.expectRevert(BrrETH.RemovedERC4626Method.selector);

        vault.maxWithdraw(address(0));
    }

    function testCannotPreviewMintRemovedERC4626Method() external {
        vm.expectRevert(BrrETH.RemovedERC4626Method.selector);

        vault.previewMint(0);
    }

    function testCannotPreviewWithdrawRemovedERC4626Method() external {
        vm.expectRevert(BrrETH.RemovedERC4626Method.selector);

        vault.previewWithdraw(0);
    }

    function testCannotMintRemovedERC4626Method() external {
        vm.expectRevert(BrrETH.RemovedERC4626Method.selector);

        vault.mint(0, address(0));
    }

    function testCannotWithdrawRemovedERC4626Method() external {
        vm.expectRevert(BrrETH.RemovedERC4626Method.selector);

        vault.withdraw(0, address(0), address(0));
    }
}
