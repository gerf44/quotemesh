// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AssetRegistry } from "./AssetRegistry.sol";
import { ProviderRegistry } from "./ProviderRegistry.sol";
import { LiquidityVault } from "./LiquidityVault.sol";
import { SettlementRegistry } from "./SettlementRegistry.sol";

contract RFQMarket {
    enum RFQStatus {
        Open,
        Filled,
        Cancelled,
        Expired
    }

    enum QuoteStatus {
        Active,
        Cancelled,
        Filled,
        Released
    }

    enum AccessMode {
        Public,
        InviteOnly
    }

    struct RFQ {
        uint256 id;
        address taker;
        address sellToken;
        address buyToken;
        uint256 sellAmount;
        uint256 minBuyAmount;
        uint64 createdAt;
        uint64 expiresAt;
        RFQStatus status;
        AccessMode accessMode;
        bytes32 metadataHash;
        string metadataURI;
    }

    struct FirmQuote {
        uint256 id;
        uint256 rfqId;
        address provider;
        uint256 buyAmount;
        uint64 createdAt;
        uint64 expiresAt;
        QuoteStatus status;
        bytes32 providerReference;
    }

    error InvalidAddress();
    error InvalidAmount();
    error InvalidExpiry();
    error InvalidMetadata();
    error InvalidInvites();
    error InvalidPair();
    error InvalidStatus();
    error Unauthorized();
    error ProviderNotAllowed();
    error DuplicateActiveQuote();
    error QuoteMismatch();
    error StaleMinimum();
    error NotReleasable();
    error InvalidPagination();
    error FeeTooHigh();

    uint16 public constant MAX_FEE_BPS = 50;
    uint256 public constant MAX_INVITED_PROVIDERS = 16;
    uint256 public constant MAX_PAGE_SIZE = 100;
    uint64 public constant MAX_RFQ_DURATION = 30 days;

    AssetRegistry public immutable assetRegistry;
    ProviderRegistry public immutable providerRegistry;
    LiquidityVault public immutable liquidityVault;
    SettlementRegistry public immutable settlementRegistry;
    address public immutable feeRecipient;
    uint16 public immutable protocolFeeBps;

    uint256 public nextRFQId = 1;
    uint256 public nextQuoteId = 1;

    mapping(uint256 => RFQ) private rfqs;
    mapping(uint256 => FirmQuote) private quotes;
    mapping(uint256 => address[]) private invitedProviders;
    mapping(uint256 => mapping(address => bool)) private invited;
    mapping(uint256 => uint256[]) private rfqQuoteIds;
    mapping(uint256 => mapping(address => uint256)) public activeQuoteByProvider;

    event RFQCreated(
        uint256 indexed rfqId,
        address indexed taker,
        address indexed sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 minBuyAmount,
        uint64 expiresAt,
        AccessMode accessMode,
        bytes32 metadataHash
    );
    event RFQCancelled(uint256 indexed rfqId, address indexed taker);
    event RFQExpired(uint256 indexed rfqId);
    event QuoteSubmitted(
        uint256 indexed quoteId,
        uint256 indexed rfqId,
        address indexed provider,
        uint256 buyAmount,
        uint64 expiresAt,
        bytes32 providerReference
    );
    event QuoteReplaced(
        uint256 indexed quoteId,
        uint256 previousBuyAmount,
        uint256 newBuyAmount,
        uint64 newExpiresAt,
        bytes32 providerReference
    );
    event QuoteCancelled(uint256 indexed quoteId, uint256 indexed rfqId, address indexed provider);
    event QuoteReleased(
        uint256 indexed quoteId, uint256 indexed rfqId, address indexed provider, uint256 amount
    );
    event TradeSettled(
        bytes32 indexed tradeId,
        uint256 indexed rfqId,
        uint256 indexed quoteId,
        address taker,
        address provider,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 buyAmount,
        uint256 feeAmount
    );

    constructor(
        AssetRegistry assetRegistry_,
        ProviderRegistry providerRegistry_,
        LiquidityVault liquidityVault_,
        SettlementRegistry settlementRegistry_,
        address feeRecipient_,
        uint16 protocolFeeBps_
    ) {
        if (
            address(assetRegistry_) == address(0) || address(providerRegistry_) == address(0)
                || address(liquidityVault_) == address(0)
                || address(settlementRegistry_) == address(0) || feeRecipient_ == address(0)
        ) revert InvalidAddress();
        if (protocolFeeBps_ > MAX_FEE_BPS) revert FeeTooHigh();
        assetRegistry = assetRegistry_;
        providerRegistry = providerRegistry_;
        liquidityVault = liquidityVault_;
        settlementRegistry = settlementRegistry_;
        feeRecipient = feeRecipient_;
        protocolFeeBps = protocolFeeBps_;
    }

    function createRFQ(
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 minBuyAmount,
        uint64 expiresAt,
        AccessMode accessMode,
        address[] calldata inviteList,
        bytes32 metadataHash,
        string calldata metadataURI
    ) external returns (uint256 rfqId) {
        if (!assetRegistry.isSupportedPair(sellToken, buyToken)) {
            revert InvalidPair();
        }
        if (sellAmount == 0 || minBuyAmount == 0) revert InvalidAmount();
        if (expiresAt <= block.timestamp || expiresAt > block.timestamp + MAX_RFQ_DURATION) {
            revert InvalidExpiry();
        }
        if (bytes(metadataURI).length > 256) revert InvalidMetadata();

        AssetRegistry.PairInfo memory pair =
            assetRegistry.pairInfo(assetRegistry.getPairId(sellToken, buyToken));
        if (sellAmount < pair.minAmount || (pair.maxAmount != 0 && sellAmount > pair.maxAmount)) {
            revert InvalidAmount();
        }
        _validateInvites(accessMode, inviteList);

        rfqId = nextRFQId++;
        rfqs[rfqId] = RFQ({
            id: rfqId,
            taker: msg.sender,
            sellToken: sellToken,
            buyToken: buyToken,
            sellAmount: sellAmount,
            minBuyAmount: minBuyAmount,
            createdAt: uint64(block.timestamp),
            expiresAt: expiresAt,
            status: RFQStatus.Open,
            accessMode: accessMode,
            metadataHash: metadataHash,
            metadataURI: metadataURI
        });

        for (uint256 i; i < inviteList.length; i++) {
            address provider = inviteList[i];
            if (provider == address(0) || invited[rfqId][provider]) revert InvalidInvites();
            invited[rfqId][provider] = true;
            invitedProviders[rfqId].push(provider);
        }

        emit RFQCreated(
            rfqId,
            msg.sender,
            sellToken,
            buyToken,
            sellAmount,
            minBuyAmount,
            expiresAt,
            accessMode,
            metadataHash
        );
    }

    function cancelRFQ(uint256 rfqId) external {
        RFQ storage rfq = _openRFQ(rfqId);
        if (msg.sender != rfq.taker) revert Unauthorized();
        if (block.timestamp >= rfq.expiresAt) revert InvalidExpiry();
        rfq.status = RFQStatus.Cancelled;
        emit RFQCancelled(rfqId, msg.sender);
    }

    function expireRFQ(uint256 rfqId) external {
        RFQ storage rfq = _openRFQ(rfqId);
        if (block.timestamp < rfq.expiresAt) revert InvalidExpiry();
        rfq.status = RFQStatus.Expired;
        emit RFQExpired(rfqId);
    }

    function submitQuote(
        uint256 rfqId,
        uint256 buyAmount,
        uint64 expiresAt,
        bytes32 providerReference
    ) external returns (uint256 quoteId) {
        RFQ storage rfq = _validQuoteTarget(rfqId, msg.sender, buyAmount, expiresAt);
        if (activeQuoteByProvider[rfqId][msg.sender] != 0) revert DuplicateActiveQuote();

        liquidityVault.reserve(msg.sender, rfq.buyToken, buyAmount);
        quoteId = nextQuoteId++;
        quotes[quoteId] = FirmQuote({
            id: quoteId,
            rfqId: rfqId,
            provider: msg.sender,
            buyAmount: buyAmount,
            createdAt: uint64(block.timestamp),
            expiresAt: expiresAt,
            status: QuoteStatus.Active,
            providerReference: providerReference
        });
        activeQuoteByProvider[rfqId][msg.sender] = quoteId;
        rfqQuoteIds[rfqId].push(quoteId);
        providerRegistry.recordQuoteSubmitted(msg.sender);
        emit QuoteSubmitted(quoteId, rfqId, msg.sender, buyAmount, expiresAt, providerReference);
    }

    function replaceQuote(
        uint256 quoteId,
        uint256 newBuyAmount,
        uint64 newExpiresAt,
        bytes32 newReference
    ) external {
        FirmQuote storage quote = _activeQuote(quoteId);
        if (quote.provider != msg.sender) revert Unauthorized();
        RFQ storage rfq = _validQuoteTarget(quote.rfqId, msg.sender, newBuyAmount, newExpiresAt);

        uint256 previousBuyAmount = quote.buyAmount;
        liquidityVault.release(msg.sender, rfq.buyToken, previousBuyAmount);
        liquidityVault.reserve(msg.sender, rfq.buyToken, newBuyAmount);

        quote.buyAmount = newBuyAmount;
        quote.expiresAt = newExpiresAt;
        quote.providerReference = newReference;
        emit QuoteReplaced(quoteId, previousBuyAmount, newBuyAmount, newExpiresAt, newReference);
    }

    function cancelQuote(uint256 quoteId) external {
        FirmQuote storage quote = _activeQuote(quoteId);
        if (quote.provider != msg.sender) revert Unauthorized();
        RFQ storage rfq = rfqs[quote.rfqId];
        quote.status = QuoteStatus.Cancelled;
        activeQuoteByProvider[quote.rfqId][msg.sender] = 0;
        liquidityVault.release(msg.sender, rfq.buyToken, quote.buyAmount);
        providerRegistry.recordQuoteCancelled(msg.sender);
        emit QuoteCancelled(quoteId, quote.rfqId, msg.sender);
    }

    function releaseQuote(uint256 quoteId) external {
        FirmQuote storage quote = _activeQuote(quoteId);
        RFQ storage rfq = rfqs[quote.rfqId];
        bool releasable = quote.expiresAt <= block.timestamp || rfq.expiresAt <= block.timestamp
            || rfq.status == RFQStatus.Filled || rfq.status == RFQStatus.Cancelled
            || rfq.status == RFQStatus.Expired;
        if (!releasable) revert NotReleasable();

        quote.status = QuoteStatus.Released;
        activeQuoteByProvider[quote.rfqId][quote.provider] = 0;
        liquidityVault.release(quote.provider, rfq.buyToken, quote.buyAmount);
        emit QuoteReleased(quoteId, quote.rfqId, quote.provider, quote.buyAmount);
    }

    function acceptQuote(uint256 rfqId, uint256 quoteId, uint256 minimumExpectedBuyAmount)
        external
        returns (bytes32 tradeId)
    {
        RFQ storage rfq = _openRFQ(rfqId);
        FirmQuote storage quote = _activeQuote(quoteId);
        if (msg.sender != rfq.taker) revert Unauthorized();
        if (quote.rfqId != rfqId) revert QuoteMismatch();
        if (block.timestamp >= rfq.expiresAt || block.timestamp >= quote.expiresAt) {
            revert InvalidExpiry();
        }
        if (quote.buyAmount < rfq.minBuyAmount || quote.buyAmount < minimumExpectedBuyAmount) {
            revert StaleMinimum();
        }

        uint256 feeAmount = (rfq.sellAmount * protocolFeeBps) / 10_000;
        rfq.status = RFQStatus.Filled;
        quote.status = QuoteStatus.Filled;
        activeQuoteByProvider[rfqId][quote.provider] = 0;

        liquidityVault.settle(
            rfq.taker,
            quote.provider,
            rfq.sellToken,
            rfq.buyToken,
            rfq.sellAmount,
            quote.buyAmount,
            feeAmount,
            feeRecipient
        );

        tradeId = keccak256(
            abi.encode(block.chainid, address(this), rfqId, quoteId, rfq.taker, quote.provider)
        );
        settlementRegistry.recordSettlement(
            SettlementRegistry.SettlementReceipt({
                tradeId: tradeId,
                rfqId: rfqId,
                quoteId: quoteId,
                taker: rfq.taker,
                provider: quote.provider,
                sellToken: rfq.sellToken,
                buyToken: rfq.buyToken,
                sellAmount: rfq.sellAmount,
                buyAmount: quote.buyAmount,
                feeAmount: feeAmount,
                settledAt: uint64(block.timestamp)
            })
        );
        providerRegistry.recordTradeCompleted(quote.provider);
        emit TradeSettled(
            tradeId,
            rfqId,
            quoteId,
            rfq.taker,
            quote.provider,
            rfq.sellToken,
            rfq.buyToken,
            rfq.sellAmount,
            quote.buyAmount,
            feeAmount
        );
    }

    function getRFQ(uint256 rfqId) external view returns (RFQ memory) {
        return rfqs[rfqId];
    }

    function getQuote(uint256 quoteId) external view returns (FirmQuote memory) {
        return quotes[quoteId];
    }

    function getRFQQuotes(uint256 rfqId, uint256 offset, uint256 limit)
        external
        view
        returns (FirmQuote[] memory page)
    {
        uint256[] storage ids = rfqQuoteIds[rfqId];
        if (limit == 0 || limit > MAX_PAGE_SIZE || offset > ids.length) {
            revert InvalidPagination();
        }
        uint256 end = offset + limit;
        if (end > ids.length) end = ids.length;
        page = new FirmQuote[](end - offset);
        for (uint256 i; i < page.length; i++) {
            page[i] = quotes[ids[offset + i]];
        }
    }

    function getInvitedProviders(uint256 rfqId) external view returns (address[] memory) {
        return invitedProviders[rfqId];
    }

    function canSubmitQuote(uint256 rfqId, address provider) public view returns (bool) {
        RFQ storage rfq = rfqs[rfqId];
        if (
            rfq.status != RFQStatus.Open || rfq.expiresAt <= block.timestamp
                || !assetRegistry.isSupportedPair(rfq.sellToken, rfq.buyToken)
                || !providerRegistry.isActiveProvider(provider)
        ) return false;
        return rfq.accessMode == AccessMode.Public || invited[rfqId][provider];
    }

    function canAcceptQuote(uint256 rfqId, uint256 quoteId, address taker)
        external
        view
        returns (bool)
    {
        RFQ storage rfq = rfqs[rfqId];
        FirmQuote storage quote = quotes[quoteId];
        return rfq.status == RFQStatus.Open && quote.status == QuoteStatus.Active
            && quote.rfqId == rfqId && rfq.taker == taker && rfq.expiresAt > block.timestamp
            && quote.expiresAt > block.timestamp && quote.buyAmount >= rfq.minBuyAmount;
    }

    function _openRFQ(uint256 rfqId) private view returns (RFQ storage rfq) {
        rfq = rfqs[rfqId];
        if (rfq.status != RFQStatus.Open || rfq.id == 0) revert InvalidStatus();
    }

    function _activeQuote(uint256 quoteId) private view returns (FirmQuote storage quote) {
        quote = quotes[quoteId];
        if (quote.status != QuoteStatus.Active || quote.id == 0) revert InvalidStatus();
    }

    function _validQuoteTarget(uint256 rfqId, address provider, uint256 buyAmount, uint64 expiresAt)
        private
        view
        returns (RFQ storage rfq)
    {
        rfq = _openRFQ(rfqId);
        if (!canSubmitQuote(rfqId, provider)) revert ProviderNotAllowed();
        if (buyAmount < rfq.minBuyAmount) revert InvalidAmount();
        if (expiresAt <= block.timestamp || expiresAt > rfq.expiresAt) revert InvalidExpiry();
    }

    function _validateInvites(AccessMode accessMode, address[] calldata inviteList) private pure {
        if (
            inviteList.length > MAX_INVITED_PROVIDERS
                || (accessMode == AccessMode.InviteOnly && inviteList.length == 0)
                || (accessMode == AccessMode.Public && inviteList.length != 0)
        ) revert InvalidInvites();
    }
}
