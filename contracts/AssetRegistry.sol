// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AssetRegistry is Ownable {
    struct AssetInfo {
        address token;
        string symbol;
        uint8 decimals;
        bool enabled;
        string category;
        bytes32 officialSourceHash;
    }

    struct PairInfo {
        address baseAsset;
        address quoteAsset;
        bool enabled;
        uint256 minAmount;
        uint256 maxAmount;
    }

    error InvalidAddress();
    error InvalidAsset();
    error DuplicateAsset();
    error IdenticalPair();
    error UnsupportedAsset();
    error InvalidLimits();

    mapping(address => AssetInfo) private assets;
    mapping(bytes32 => PairInfo) private pairs;

    event AssetRegistered(
        address indexed token,
        string symbol,
        uint8 decimals,
        string category,
        bytes32 officialSourceHash
    );
    event AssetStatusUpdated(address indexed token, bool enabled);
    event PairStatusUpdated(
        bytes32 indexed pairId, address indexed baseAsset, address indexed quoteAsset, bool enabled
    );
    event PairLimitsUpdated(bytes32 indexed pairId, uint256 minAmount, uint256 maxAmount);

    constructor(address initialOwner) Ownable(initialOwner) { }

    function registerAsset(
        address token,
        string calldata symbol,
        string calldata category,
        bytes32 officialSourceHash
    ) external onlyOwner {
        if (token == address(0) || token.code.length == 0) {
            revert InvalidAddress();
        }
        if (assets[token].token != address(0)) revert DuplicateAsset();
        if (bytes(symbol).length == 0 || bytes(symbol).length > 16) revert InvalidAsset();

        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        if (tokenDecimals == 0 || tokenDecimals > 18) revert InvalidAsset();

        assets[token] = AssetInfo({
            token: token,
            symbol: symbol,
            decimals: tokenDecimals,
            enabled: true,
            category: category,
            officialSourceHash: officialSourceHash
        });
        emit AssetRegistered(token, symbol, tokenDecimals, category, officialSourceHash);
    }

    function setAssetStatus(address token, bool enabled) external onlyOwner {
        if (assets[token].token == address(0)) revert UnsupportedAsset();
        assets[token].enabled = enabled;
        emit AssetStatusUpdated(token, enabled);
    }

    function enablePair(address baseAsset, address quoteAsset) external onlyOwner {
        _validatePairAssets(baseAsset, quoteAsset);
        bytes32 pairId = getPairId(baseAsset, quoteAsset);
        PairInfo storage pair = pairs[pairId];
        pair.baseAsset = baseAsset;
        pair.quoteAsset = quoteAsset;
        pair.enabled = true;
        emit PairStatusUpdated(pairId, baseAsset, quoteAsset, true);
    }

    function disablePair(address baseAsset, address quoteAsset) external onlyOwner {
        bytes32 pairId = getPairId(baseAsset, quoteAsset);
        PairInfo storage pair = pairs[pairId];
        if (pair.baseAsset == address(0)) revert UnsupportedAsset();
        pair.enabled = false;
        emit PairStatusUpdated(pairId, baseAsset, quoteAsset, false);
    }

    function setPairLimits(bytes32 pairId, uint256 minAmount, uint256 maxAmount)
        external
        onlyOwner
    {
        if (pairs[pairId].baseAsset == address(0)) revert UnsupportedAsset();
        if (maxAmount != 0 && maxAmount < minAmount) revert InvalidLimits();
        pairs[pairId].minAmount = minAmount;
        pairs[pairId].maxAmount = maxAmount;
        emit PairLimitsUpdated(pairId, minAmount, maxAmount);
    }

    function isSupportedAsset(address token) public view returns (bool) {
        return assets[token].token != address(0) && assets[token].enabled;
    }

    function isSupportedPair(address baseAsset, address quoteAsset) public view returns (bool) {
        PairInfo storage pair = pairs[getPairId(baseAsset, quoteAsset)];
        return pair.enabled && isSupportedAsset(baseAsset) && isSupportedAsset(quoteAsset);
    }

    function getPairId(address baseAsset, address quoteAsset) public pure returns (bytes32) {
        return keccak256(abi.encode(baseAsset, quoteAsset));
    }

    function assetInfo(address token) external view returns (AssetInfo memory) {
        return assets[token];
    }

    function pairInfo(bytes32 pairId) external view returns (PairInfo memory) {
        return pairs[pairId];
    }

    function _validatePairAssets(address baseAsset, address quoteAsset) private view {
        if (baseAsset == quoteAsset) revert IdenticalPair();
        if (!isSupportedAsset(baseAsset) || !isSupportedAsset(quoteAsset)) {
            revert UnsupportedAsset();
        }
    }
}
