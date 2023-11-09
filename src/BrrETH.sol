// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";

contract BrrETH is ERC4626 {
    using SafeTransferLib for address;

    string private constant _NAME = "Rebasing Compound ETH";
    string private constant _SYMBOL = "brrETH";
    address private constant _WETH = 0x4200000000000000000000000000000000000006;
    address private constant _COMET_ADDR =
        0x46e6b214b524310239732D51387075E0e70970bf;
    IComet private constant _COMET = IComet(_COMET_ADDR);
    ICometRewards private constant _COMET_REWARDS =
        ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);

    error AssetsGreaterThanBalance();

    constructor() {
        _WETH.safeApprove(_COMET_ADDR, type(uint256).max);
    }

    function name() public pure override returns (string memory) {
        return _NAME;
    }

    function symbol() public pure override returns (string memory) {
        return _SYMBOL;
    }

    function asset() public pure override returns (address) {
        return _COMET_ADDR;
    }

    function deposit(
        uint256 assets,
        address to
    ) public override returns (uint256 shares) {
        if (assets > _COMET_ADDR.balanceOf(msg.sender))
            revert AssetsGreaterThanBalance();
        if (assets > maxDeposit(to)) revert DepositMoreThanMax();

        harvest();

        shares = previewDeposit(assets);

        _deposit(msg.sender, to, assets, shares);
    }

    function mint(
        uint256 shares,
        address to
    ) public override returns (uint256 assets) {
        if (shares > maxMint(to)) revert MintMoreThanMax();

        harvest();

        assets = previewMint(shares);

        if (assets > _COMET_ADDR.balanceOf(msg.sender))
            revert AssetsGreaterThanBalance();

        _deposit(msg.sender, to, assets, shares);
    }

    /**
     * @notice Claim rewards and convert them into the vault asset.
     */
    function harvest() public {
        _COMET_REWARDS.claim(_COMET_ADDR, address(this), true);

        // TODO: Swap COMP for WETH.

        _COMET.supply(_WETH, _WETH.balanceOf(address(this)));
    }
}
