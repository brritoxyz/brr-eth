// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

/// @title Brrito brrETH.
/// @author kp (kphed.eth).
/// @notice A yield-bearing ETH derivative built on Compound III.
contract BrrETH is Ownable, ERC4626 {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    string private constant _NAME = "Brrito ETH";
    string private constant _SYMBOL = "brrETH";
    address private constant _WETH = 0x4200000000000000000000000000000000000006;
    uint256 private constant _FEE_BASE = 10_000;
    address private constant _COMET =
        0x46e6b214b524310239732D51387075E0e70970bf;

    ICometRewards public cometRewards =
        ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);

    // The router used to swap rewards for WETH.
    IRouter public router = IRouter(0xafaE5a94e6F1C79D40F5460c47589BAD5c123B9c);

    // The default reward fee is 5% (500 / 10_000).
    uint256 public rewardFee = 500;

    // Receives the protocol's share of reward fees.
    address public protocolFeeReceiver = address(0);

    // Receives and distributes the stakedBRR token holder's share of reward fees.
    address public feeDistributor = address(0);

    event Harvest(
        address indexed token,
        uint256 rewards,
        uint256 supplyAssets,
        uint256 fees
    );
    event SetCometRewards(address, bool);
    event SetRouter(address);
    event SetRewardFee(uint256);
    event SetProtocolFeeReceiver(address);
    event SetFeeDistributor(address);

    error InsufficientSharesMinted();
    error InsufficientAssetBalance();
    error InvalidCometRewards();
    error InvalidRouter();
    error InvalidProtocolFeeReceiver();
    error InvalidFeeDistributor();
    error RemovedOwnableMethod();
    error RemovedERC4626Method();

    constructor(address initialOwner) {
        // The default fee recipients are set to the initial owner but
        // can be updated using one of the setter methods.
        protocolFeeReceiver = initialOwner;
        feeDistributor = initialOwner;

        _initializeOwner(initialOwner);
        approveTokens();
    }

    /**
     * @notice ERC20 token name.
     * @return string  Token name.
     */
    function name() public pure override returns (string memory) {
        return _NAME;
    }

    /**
     * @notice ERC20 token symbol.
     * @return string  Token symbol.
     */
    function symbol() public pure override returns (string memory) {
        return _SYMBOL;
    }

    /**
     * @notice Underlying ERC20 token asset.
     * @return address  Asset contract address.
     */
    function asset() public pure override returns (address) {
        return _COMET;
    }

    /// @notice Approve token allowances for vital contracts.
    function approveTokens() public {
        ICometRewards.RewardConfig memory rewardConfig = cometRewards
            .rewardConfig(_COMET);

        // Enable the router to swap our Comet rewards for WETH.
        rewardConfig.token.safeApproveWithRetry(
            address(router),
            type(uint256).max
        );

        // Enable Comet to transfer our WETH in exchange for cWETH.
        _WETH.safeApproveWithRetry(_COMET, type(uint256).max);
    }

    /**
     * @notice Returns the amount of shares that the Vault will exchange for the amount of assets provided,
     *         in an ideal scenario where all conditions are met.
     * @param  assets       uint256  Amount of assets to convert to shares.
     * @param  totalSupply  uint256  Amount of shares in the Vault prior to minting `shares`.
     * @param  totalAssets  uint256  Amount of assets in the Vault prior to transferring in `assets`.
     * @return              uint256  Amount of shares minted in exchange for `assets`.
     */
    function convertToShares(
        uint256 assets,
        uint256 totalSupply,
        uint256 totalAssets
    ) public pure returns (uint256) {
        // Will not realistically overflow since the `totalSupply` and `totalAssets` should never
        // exceed the amount of cWETHv3 that is deposited or received from compounding rewards.
        unchecked {
            return assets.fullMulDiv(totalSupply + 1, totalAssets + 1);
        }
    }

    /**
     * @notice Mints `shares` and emits the `Deposit` event.
     * @param  by      address  Address that minted the shares.
     * @param  to      address  Address to mint shares to.
     * @param  assets  uint256  Amount of assets deposited.
     * @param  shares  uint256  Amount of shares minted.
     */
    function _deposit(
        address by,
        address to,
        uint256 assets,
        uint256 shares
    ) internal override {
        _mint(to, shares);

        emit Deposit(by, to, assets, shares);
    }

    /**
     * @notice Mints `shares` Vault shares to `to` by depositing `assets` received from supplying ETH.
     * @param  to         address  Address to mint shares to.
     * @param  minShares  uint256  The minimum amount of shares that must be minted.
     * @return shares     uint256  Amount of shares minted.
     */
    function deposit(
        address to,
        uint256 minShares
    ) external payable returns (uint256 shares) {
        IWETH(_WETH).deposit{value: msg.value}();

        uint256 totalAssetsBefore = totalAssets();

        IComet(_COMET).supply(_WETH, msg.value);

        uint256 assets = totalAssets() - totalAssetsBefore;
        shares = convertToShares(assets, totalSupply(), totalAssetsBefore);

        if (shares < minShares) revert InsufficientSharesMinted();

        _deposit(msg.sender, to, assets, shares);
    }

    /**
     * @notice Mints `shares` Vault shares to `to` by depositing exactly `assets` of underlying tokens.
     * @dev    Comet rounds down transfer amounts, which will result in a 1+ wei discrepancy between `assets`
     *         and the actual amount received by the vault. To err on the side of safety, we are using the
     *         actual amount of assets received by the vault when calculating the amount of shares to mint.
     * @param  assets  uint256  Amount of assets to deposit.
     * @param  to      address  Address to mint shares to.
     * @return shares  uint256  Amount of shares minted.
     */
    function deposit(
        uint256 assets,
        address to
    ) public override returns (uint256 shares) {
        // Prevents `msg.sender` from using `type(uint256).max` for `assets` which is Comet's alias for "entire balance".
        if (assets > _COMET.balanceOf(msg.sender))
            revert InsufficientAssetBalance();

        uint256 totalAssetsBefore = totalAssets();

        _COMET.safeTransferFrom(msg.sender, address(this), assets);

        shares = convertToShares(
            // The difference is the exact amount of cWETHv3 received, after rounding down.
            totalAssets() - totalAssetsBefore,
            totalSupply(),
            totalAssetsBefore
        );

        _deposit(msg.sender, to, assets, shares);
    }

    /// @notice Claim rewards and convert them into the vault asset.
    function harvest() public {
        cometRewards.claim(_COMET, address(this), true);

        ICometRewards.RewardConfig memory rewardConfig = cometRewards
            .rewardConfig(_COMET);
        uint256 rewards = rewardConfig.token.balanceOf(address(this));

        if (rewards == 0) return;

        // Fetching the quote onchain means that we're subject to front/back-running but the
        // assumption is that we will harvest so frequently that the rewards won't justify the effort.
        (uint256 index, uint256 quote) = router.getSwapOutput(
            keccak256(abi.encodePacked(rewardConfig.token, _WETH)),
            rewards
        );

        // `swap` returns the entire WETH amount received from the swap.
        uint256 supplyAssets = router.swap(
            rewardConfig.token,
            _WETH,
            rewards,
            quote,
            index,
            // Receives half of the swap fees (the other half remains in the router contract for the protocol).
            feeDistributor
        );

        // Calculate the reward fees, which may be taken out from the output amount before supplying to Comet.
        uint256 fees = supplyAssets.mulDiv(rewardFee, _FEE_BASE);

        // Only distribute rewards if there's enough to split between the protocol fee receiver and the fee distributor.
        if (fees > 1) {
            unchecked {
                // `fees` is a fraction of the swap output so we can safely subtract it without underflowing.
                supplyAssets -= fees;

                uint256 protocolFeeReceiverShare = fees / 2;

                _WETH.safeTransfer(
                    protocolFeeReceiver,
                    protocolFeeReceiverShare
                );
                _WETH.safeTransfer(
                    feeDistributor,
                    fees - protocolFeeReceiverShare
                );
            }
        }

        emit Harvest(rewardConfig.token, rewards, supplyAssets, fees);

        IComet(_COMET).supply(_WETH, supplyAssets);
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVILEGED SETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the Comet Rewards contract.
     * @param  _cometRewards  address  Comet Rewards contract address.
     * @param  shouldHarvest  bool     Whether to call `harvest` before setting `cometRewards`.
     */
    function setCometRewards(
        address _cometRewards,
        bool shouldHarvest
    ) external onlyOwner {
        if (_cometRewards == address(0)) revert InvalidCometRewards();
        if (shouldHarvest) harvest();

        cometRewards = ICometRewards(_cometRewards);

        emit SetCometRewards(_cometRewards, shouldHarvest);
    }

    /**
     * @notice Set the router contract.
     * @param  _router  address  Router contract address.
     */
    function setRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert InvalidRouter();

        router = IRouter(_router);

        // Enable the new router to swap reward tokens into more WETH.
        approveTokens();

        emit SetRouter(_router);
    }

    /**
     * @notice Set the reward fee.
     * @param  _rewardFee  uint256  Reward fee.
     */
    function setRewardFee(uint256 _rewardFee) external onlyOwner {
        rewardFee = _rewardFee;

        emit SetRewardFee(_rewardFee);
    }

    /**
     * @notice Set the protocol fee receiver.
     * @param  _protocolFeeReceiver  address  Protocol fee receiver.
     */
    function setProtocolFeeReceiver(
        address _protocolFeeReceiver
    ) external onlyOwner {
        if (_protocolFeeReceiver == address(0))
            revert InvalidProtocolFeeReceiver();

        protocolFeeReceiver = _protocolFeeReceiver;

        emit SetProtocolFeeReceiver(_protocolFeeReceiver);
    }

    /**
     * @notice Set the fee distributor.
     * @param  _feeDistributor  address  Fee distributor.
     */
    function setFeeDistributor(address _feeDistributor) external onlyOwner {
        if (_feeDistributor == address(0)) revert InvalidFeeDistributor();

        feeDistributor = _feeDistributor;

        emit SetFeeDistributor(_feeDistributor);
    }

    /*//////////////////////////////////////////////////////////////
                    ENFORCE 2-STEP OWNERSHIP TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address) public payable override {
        revert RemovedOwnableMethod();
    }

    function renounceOwnership() public payable override {
        revert RemovedOwnableMethod();
    }

    /*//////////////////////////////////////////////////////////////
                        REMOVED ERC4626 METHODS
    //////////////////////////////////////////////////////////////*/

    function maxMint(address) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function maxWithdraw(address) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function previewMint(uint256) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function previewWithdraw(uint256) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function mint(uint256, address) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function withdraw(
        uint256,
        address,
        address
    ) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }
}
