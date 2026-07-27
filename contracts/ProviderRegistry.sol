// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract ProviderRegistry is Ownable {
    struct ProviderProfile {
        string metadataURI;
        bytes32 profileHash;
        uint64 registeredAt;
        bool active;
        bool quoteMeshVerified;
        uint64 quotesSubmitted;
        uint64 tradesCompleted;
        uint64 quotesCancelled;
    }

    error InvalidProfile();
    error AlreadyRegistered();
    error NotRegistered();
    error UnauthorizedMarket();
    error MarketAlreadySet();
    error InvalidAddress();

    mapping(address => ProviderProfile) private profiles;
    address public market;

    event ProviderRegistered(
        address indexed provider, string metadataURI, bytes32 indexed profileHash
    );
    event ProviderProfileUpdated(
        address indexed provider, string metadataURI, bytes32 indexed profileHash
    );
    event ProviderStatusUpdated(address indexed provider, bool active);
    event ProviderVerificationUpdated(address indexed provider, bool quoteMeshVerified);
    event MarketConfigured(address indexed market);

    modifier onlyMarket() {
        if (msg.sender != market) revert UnauthorizedMarket();
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) { }

    function setMarketOnce(address market_) external onlyOwner {
        if (market != address(0)) revert MarketAlreadySet();
        if (market_ == address(0) || market_.code.length == 0) revert InvalidAddress();
        market = market_;
        emit MarketConfigured(market_);
    }

    function registerProvider(string calldata metadataURI, bytes32 profileHash) external {
        if (profiles[msg.sender].registeredAt != 0) revert AlreadyRegistered();
        _validateProfile(metadataURI, profileHash);
        profiles[msg.sender] = ProviderProfile({
            metadataURI: metadataURI,
            profileHash: profileHash,
            registeredAt: uint64(block.timestamp),
            active: true,
            quoteMeshVerified: false,
            quotesSubmitted: 0,
            tradesCompleted: 0,
            quotesCancelled: 0
        });
        emit ProviderRegistered(msg.sender, metadataURI, profileHash);
    }

    function updateProviderProfile(string calldata metadataURI, bytes32 profileHash) external {
        ProviderProfile storage profile = _registered(msg.sender);
        _validateProfile(metadataURI, profileHash);
        profile.metadataURI = metadataURI;
        profile.profileHash = profileHash;
        emit ProviderProfileUpdated(msg.sender, metadataURI, profileHash);
    }

    function pauseMyProviderAccount() external {
        ProviderProfile storage profile = _registered(msg.sender);
        profile.active = false;
        emit ProviderStatusUpdated(msg.sender, false);
    }

    function resumeMyProviderAccount() external {
        ProviderProfile storage profile = _registered(msg.sender);
        profile.active = true;
        emit ProviderStatusUpdated(msg.sender, true);
    }

    function setQuoteMeshVerification(address provider, bool verified) external onlyOwner {
        ProviderProfile storage profile = _registered(provider);
        profile.quoteMeshVerified = verified;
        emit ProviderVerificationUpdated(provider, verified);
    }

    function isActiveProvider(address provider) external view returns (bool) {
        return profiles[provider].registeredAt != 0 && profiles[provider].active;
    }

    function providerProfile(address provider) external view returns (ProviderProfile memory) {
        return profiles[provider];
    }

    function recordQuoteSubmitted(address provider) external onlyMarket {
        _registered(provider).quotesSubmitted++;
    }

    function recordTradeCompleted(address provider) external onlyMarket {
        _registered(provider).tradesCompleted++;
    }

    function recordQuoteCancelled(address provider) external onlyMarket {
        _registered(provider).quotesCancelled++;
    }

    function _registered(address provider) private view returns (ProviderProfile storage profile) {
        profile = profiles[provider];
        if (profile.registeredAt == 0) revert NotRegistered();
    }

    function _validateProfile(string calldata metadataURI, bytes32 profileHash) private pure {
        uint256 length = bytes(metadataURI).length;
        if (length == 0 || length > 256 || profileHash == bytes32(0)) revert InvalidProfile();
    }
}
