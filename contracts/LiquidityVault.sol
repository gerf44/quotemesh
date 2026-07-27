// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AssetRegistry } from "./AssetRegistry.sol";

contract LiquidityVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Balance {
        uint256 available;
        uint256 reserved;
    }

    error InvalidAddress();
    error InvalidAmount();
    error UnsupportedAsset();
    error InsufficientAvailable();
    error InsufficientReserved();
    error UnauthorizedMarket();
    error MarketAlreadySet();
    error UnexpectedTokenBehavior();

    AssetRegistry public immutable assetRegistry;
    address public market;

    mapping(address => mapping(address => Balance)) private balances;
    mapping(address => uint256) public totalAvailableLiability;
    mapping(address => uint256) public totalReservedLiability;

    event LiquidityDeposited(address indexed provider, address indexed token, uint256 amount);
    event LiquidityWithdrawn(
        address indexed provider, address indexed token, address indexed recipient, uint256 amount
    );
    event LiquidityReserved(address indexed provider, address indexed token, uint256 amount);
    event LiquidityReleased(address indexed provider, address indexed token, uint256 amount);
    event ProtocolFeeAccrued(address indexed feeRecipient, address indexed token, uint256 amount);
    event MarketConfigured(address indexed market);

    modifier onlyMarket() {
        if (msg.sender != market) revert UnauthorizedMarket();
        _;
    }

    constructor(address initialOwner, AssetRegistry assetRegistry_) Ownable(initialOwner) {
        if (address(assetRegistry_) == address(0)) revert InvalidAddress();
        assetRegistry = assetRegistry_;
    }

    function setMarketOnce(address market_) external onlyOwner {
        if (market != address(0)) revert MarketAlreadySet();
        if (market_ == address(0) || market_.code.length == 0) revert InvalidAddress();
        market = market_;
        emit MarketConfigured(market_);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!assetRegistry.isSupportedAsset(token)) revert UnsupportedAsset();
        if (amount == 0) revert InvalidAmount();

        IERC20 asset = IERC20(token);
        uint256 beforeBalance = asset.balanceOf(address(this));
        asset.safeTransferFrom(msg.sender, address(this), amount);
        if (asset.balanceOf(address(this)) != beforeBalance + amount) {
            revert UnexpectedTokenBehavior();
        }

        balances[msg.sender][token].available += amount;
        totalAvailableLiability[token] += amount;
        emit LiquidityDeposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount, address recipient) external nonReentrant {
        if (recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        Balance storage balance = balances[msg.sender][token];
        if (balance.available < amount) revert InsufficientAvailable();

        balance.available -= amount;
        totalAvailableLiability[token] -= amount;

        IERC20 asset = IERC20(token);
        uint256 vaultBefore = asset.balanceOf(address(this));
        uint256 recipientBefore = asset.balanceOf(recipient);
        asset.safeTransfer(recipient, amount);
        if (
            asset.balanceOf(address(this)) + amount != vaultBefore
                || asset.balanceOf(recipient) != recipientBefore + amount
        ) revert UnexpectedTokenBehavior();

        emit LiquidityWithdrawn(msg.sender, token, recipient, amount);
    }

    function reserve(address provider, address token, uint256 amount) external onlyMarket {
        if (amount == 0) revert InvalidAmount();
        Balance storage balance = balances[provider][token];
        if (balance.available < amount) revert InsufficientAvailable();
        balance.available -= amount;
        balance.reserved += amount;
        totalAvailableLiability[token] -= amount;
        totalReservedLiability[token] += amount;
        emit LiquidityReserved(provider, token, amount);
    }

    function release(address provider, address token, uint256 amount) external onlyMarket {
        Balance storage balance = balances[provider][token];
        if (balance.reserved < amount) revert InsufficientReserved();
        balance.reserved -= amount;
        balance.available += amount;
        totalReservedLiability[token] -= amount;
        totalAvailableLiability[token] += amount;
        emit LiquidityReleased(provider, token, amount);
    }

    function settle(
        address taker,
        address provider,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 buyAmount,
        uint256 feeAmount,
        address feeRecipient
    ) external onlyMarket nonReentrant {
        if (taker == address(0) || provider == address(0) || feeRecipient == address(0)) {
            revert InvalidAddress();
        }
        if (sellAmount == 0 || buyAmount == 0 || feeAmount > sellAmount) revert InvalidAmount();
        Balance storage providerBuy = balances[provider][buyToken];
        if (providerBuy.reserved < buyAmount) revert InsufficientReserved();

        providerBuy.reserved -= buyAmount;
        totalReservedLiability[buyToken] -= buyAmount;

        uint256 providerCredit = sellAmount - feeAmount;
        balances[provider][sellToken].available += providerCredit;
        balances[feeRecipient][sellToken].available += feeAmount;
        totalAvailableLiability[sellToken] += sellAmount;

        IERC20 sellAsset = IERC20(sellToken);
        IERC20 buyAsset = IERC20(buyToken);
        uint256 sellBefore = sellAsset.balanceOf(address(this));
        sellAsset.safeTransferFrom(taker, address(this), sellAmount);
        if (sellAsset.balanceOf(address(this)) != sellBefore + sellAmount) {
            revert UnexpectedTokenBehavior();
        }

        uint256 buyBefore = buyAsset.balanceOf(address(this));
        uint256 takerBefore = buyAsset.balanceOf(taker);
        buyAsset.safeTransfer(taker, buyAmount);
        if (
            buyAsset.balanceOf(address(this)) + buyAmount != buyBefore
                || buyAsset.balanceOf(taker) != takerBefore + buyAmount
        ) revert UnexpectedTokenBehavior();

        if (feeAmount != 0) emit ProtocolFeeAccrued(feeRecipient, sellToken, feeAmount);
    }

    function availableBalanceOf(address provider, address token) external view returns (uint256) {
        return balances[provider][token].available;
    }

    function reservedBalanceOf(address provider, address token) external view returns (uint256) {
        return balances[provider][token].reserved;
    }

    function totalLiability(address token) public view returns (uint256) {
        return totalAvailableLiability[token] + totalReservedLiability[token];
    }

    function actualBalance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function isSolvent(address token) external view returns (bool) {
        return actualBalance(token) >= totalLiability(token);
    }
}
