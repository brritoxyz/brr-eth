// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

contract BrrETH is ERC4626 {
    using SafeTransferLib for address;

    string private constant _NAME = "Brrito-Compound WETH";
    string private constant _SYMBOL = "brr-cWETHv3";
    address private constant _WETH = 0x4200000000000000000000000000000000000006;
    address private constant _COMET =
        0x46e6b214b524310239732D51387075E0e70970bf;
    ICometRewards private constant _COMET_REWARDS =
        ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);
    IRouter private constant _ROUTER =
        IRouter(0x635d91a7fae76BD504fa1084e07Ab3a22495A738);

    error InvalidAssets();

    constructor() {
        _WETH.safeApproveWithRetry(_COMET, type(uint256).max);
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

        _afterDeposit(assets, shares);
    }

    function _withdraw(
        address by,
        address to,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (assets == type(uint256).max) revert InvalidAssets();
        if (by != owner) _spendAllowance(owner, by, shares);

        _beforeWithdraw(assets, shares);
        _burn(owner, shares);
        _COMET.safeTransfer(to, assets);

        emit Withdraw(by, to, owner, assets, shares);
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

        IComet(_COMET).supply(
            _WETH,
            // `swap` returns the entire WETH amount received from the swap.
            _ROUTER.swap(
                rewardConfig.token,
                _WETH,
                tokenBalance,
                output,
                index,
                address(0)
            )
        );
    }
}
