// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

contract BrrETH is Ownable, ERC4626 {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    string private constant _NAME = "Brrito-Compound WETH";
    string private constant _SYMBOL = "brr-cWETHv3";
    address private constant _WETH = 0x4200000000000000000000000000000000000006;
    address private constant _COMET =
        0x46e6b214b524310239732D51387075E0e70970bf;
    ICometRewards private constant _COMET_REWARDS =
        ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);
    IRouter private constant _ROUTER =
        IRouter(0x635d91a7fae76BD504fa1084e07Ab3a22495A738);
    uint256 private constant _FEE_BASE = 10_000;
    uint256 private constant _MAX_REWARD_FEE = 2_000;
    uint256 private constant _MAX_WITHDRAW_FEE = 5;

    // Default reward fee is 5% with a maximum of 20%.
    uint256 public rewardFee = 500;

    // Default withdraw fee is 0.05% with a maximum of 0.05%.
    uint256 public withdrawFee = 5;

    // The fee distributor contract for BRR stakers.
    address public feeDistributor = address(0);

    event SetRewardFee(uint256);
    event SetWithdrawFee(uint256);
    event SetFeeDistributor(address);

    error InvalidAssets();
    error InvalidAddress();
    error CannotExceedMax();

    constructor(address initialOwner) {
        feeDistributor = initialOwner;

        _initializeOwner(initialOwner);
        approveTokens();
    }

    function _deposit(
        address by,
        address to,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (assets == type(uint256).max) revert InvalidAssets();

        _COMET.safeTransferFrom(by, address(this), assets);
        _mint(to, shares);

        emit Deposit(by, to, assets, shares);
    }

    function name() public pure override returns (string memory) {
        return _NAME;
    }

    function symbol() public pure override returns (string memory) {
        return _SYMBOL;
    }

    function asset() public pure override returns (address) {
        return _COMET;
    }

    // Approve token allowances for vital contracts.
    function approveTokens() public {
        ICometRewards.RewardConfig memory rewardConfig = _COMET_REWARDS
            .rewardConfig(_COMET);

        // Enable the router to swap our Comet rewards for WETH.
        rewardConfig.token.safeApproveWithRetry(
            address(_ROUTER),
            type(uint256).max
        );

        // Enable Comet to transfer our WETH in exchange for cWETH.
        _WETH.safeApproveWithRetry(_COMET, type(uint256).max);
    }

    // Claim rewards and convert them into the vault asset.
    function rebase() external {
        _COMET_REWARDS.claim(_COMET, address(this), true);

        ICometRewards.RewardConfig memory rewardConfig = _COMET_REWARDS
            .rewardConfig(_COMET);
        uint256 tokenBalance = rewardConfig.token.balanceOf(address(this));

        if (tokenBalance == 0) return;

        // Fetching the quote onchain means that we're subject to front/back-running but the
        // assumption is that we will rebase so frequently that the rewards won't justify the effort.
        (uint256 index, uint256 output) = _ROUTER.getSwapOutput(
            keccak256(abi.encodePacked(rewardConfig.token, _WETH)),
            tokenBalance
        );

        // `swap` returns the entire WETH amount received from the swap.
        uint256 actualOutput = _ROUTER.swap(
            rewardConfig.token,
            _WETH,
            tokenBalance,
            output,
            index,
            address(0)
        );

        // Calculate the reward fees, which may be taken out from the output amount before supplying to Comet.
        uint256 rewardFeeShare = actualOutput.mulDiv(rewardFee, _FEE_BASE);

        // Only distribute rewards if there's enough to split between the owner and the fee distributor.
        if (rewardFeeShare > 1) {
            unchecked {
                // `rewardFeeShare` is a fraction of the output so we can safely subtract it without underflowing.
                actualOutput -= rewardFeeShare;

                uint256 ownerFeeShare = rewardFeeShare / 2;

                _WETH.safeTransfer(owner(), ownerFeeShare);
                _WETH.safeTransfer(
                    feeDistributor,
                    rewardFeeShare - ownerFeeShare
                );
            }
        }

        IComet(_COMET).supply(_WETH, actualOutput);
    }

    /**
     * @notice Set the reward fee.
     * @param  _rewardFee  uint256  Reward fee.
     */
    function setRewardFee(uint256 _rewardFee) external onlyOwner {
        if (_rewardFee > _MAX_REWARD_FEE) revert CannotExceedMax();

        rewardFee = _rewardFee;

        emit SetRewardFee(_rewardFee);
    }

    /**
     * @notice Set the withdraw fee.
     * @param  _withdrawFee  uint256  Withdraw fee.
     */
    function setWithdrawFee(uint256 _withdrawFee) external onlyOwner {
        if (_withdrawFee > _MAX_WITHDRAW_FEE) revert CannotExceedMax();

        withdrawFee = _withdrawFee;

        emit SetWithdrawFee(_withdrawFee);
    }

    /**
     * @notice Set the fee distributor.
     * @param  _feeDistributor  uint256  Fee distributor.
     */
    function setFeeDistributor(address _feeDistributor) external onlyOwner {
        if (_feeDistributor == address(0)) revert InvalidAddress();

        feeDistributor = _feeDistributor;

        emit SetFeeDistributor(_feeDistributor);
    }
}
