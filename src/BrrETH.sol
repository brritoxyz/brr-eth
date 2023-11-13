// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

contract BrrETH is Ownable, ERC4626 {
    using SafeTransferLib for address;

    string private constant _NAME = "Rebasing Compound ETH";
    string private constant _SYMBOL = "brrETH";
    address private constant _WETH = 0x4200000000000000000000000000000000000006;
    address private constant _COMET =
        0x46e6b214b524310239732D51387075E0e70970bf;
    ICometRewards private constant _COMET_REWARDS =
        ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);
    IRouter private constant _ROUTER =
        IRouter(0x635d91a7fae76BD504fa1084e07Ab3a22495A738);
    address[] private _rebaseTokens;

    event AddRebaseToken(address);
    event RemoveRebaseToken(address);

    constructor(address initialOwner) {
        _initializeOwner(initialOwner);

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

    function rebaseTokens() external view returns (address[] memory) {
        return _rebaseTokens;
    }

    function addRebaseToken(address rebaseToken) external onlyOwner {
        // Enable the token to be swapped by the router when rebasing.
        rebaseToken.safeApproveWithRetry(address(_ROUTER), type(uint256).max);

        _rebaseTokens.push(rebaseToken);

        emit AddRebaseToken(rebaseToken);
    }

    function removeRebaseToken(uint256 index) external onlyOwner {
        address removedRebaseToken = _rebaseTokens[index];

        unchecked {
            // Length should be checked by the caller.
            uint256 lastIndex = _rebaseTokens.length - 1;

            if (index != lastIndex)
                _rebaseTokens[index] = _rebaseTokens[lastIndex];

            _rebaseTokens.pop();
        }

        emit RemoveRebaseToken(removedRebaseToken);
    }

    // Claim rewards and convert them into the vault asset.
    function rebase() public {
        _COMET_REWARDS.claim(_COMET, address(this), true);

        uint256 tokensLength = _rebaseTokens.length;

        for (uint256 i = 0; i < tokensLength; ++i) {
            address token = _rebaseTokens[i];
            uint256 tokenBalance = token.balanceOf(address(this));

            if (tokenBalance == 0) continue;

            (uint256 index, uint256 output) = _ROUTER.getSwapOutput(
                keccak256(abi.encodePacked(token, _WETH)),
                tokenBalance
            );

            _ROUTER.swap(token, _WETH, tokenBalance, output, index, address(0));
        }

        IComet(_COMET).supply(_WETH, _WETH.balanceOf(address(this)));
    }

    function deposit(
        uint256 assets,
        address to
    ) public override returns (uint256 shares) {
        if (assets > _COMET.balanceOf(msg.sender)) revert InsufficientBalance();

        rebase();

        shares = previewDeposit(assets);

        _deposit(msg.sender, to, assets, shares);
    }

    function mint(
        uint256 shares,
        address to
    ) public override returns (uint256 assets) {
        rebase();

        assets = previewMint(shares);

        if (assets > _COMET.balanceOf(msg.sender)) revert InsufficientBalance();

        _deposit(msg.sender, to, assets, shares);
    }

    // Overridden to enforce 2-step ownership transfers.
    function transferOwnership(address) public payable override onlyOwner {}

    // Overridden to enforce 2-step ownership transfers.
    function renounceOwnership() public payable override onlyOwner {}
}
