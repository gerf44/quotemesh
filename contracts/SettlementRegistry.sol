// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SettlementRegistry is Ownable {
    struct SettlementReceipt {
        bytes32 tradeId;
        uint256 rfqId;
        uint256 quoteId;
        address taker;
        address provider;
        address sellToken;
        address buyToken;
        uint256 sellAmount;
        uint256 buyAmount;
        uint256 feeAmount;
        uint64 settledAt;
    }

    error InvalidAddress();
    error MarketAlreadySet();
    error UnauthorizedMarket();
    error DuplicateSettlement();
    error InvalidReceipt();
    error InvalidPagination();

    address public market;
    mapping(bytes32 => SettlementReceipt) private receipts;
    bytes32[] private tradeIds;
    mapping(address => bytes32[]) private takerTrades;
    mapping(address => bytes32[]) private providerTrades;

    event MarketConfigured(address indexed market);
    event SettlementRecorded(
        bytes32 indexed tradeId,
        uint256 indexed rfqId,
        uint256 indexed quoteId,
        address taker,
        address provider,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 buyAmount,
        uint256 feeAmount,
        uint64 settledAt
    );

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

    function recordSettlement(SettlementReceipt calldata receipt) external onlyMarket {
        if (
            receipt.tradeId == bytes32(0) || receipt.taker == address(0)
                || receipt.provider == address(0) || receipt.sellAmount == 0
                || receipt.buyAmount == 0
        ) revert InvalidReceipt();
        if (receipts[receipt.tradeId].tradeId != bytes32(0)) revert DuplicateSettlement();

        receipts[receipt.tradeId] = receipt;
        tradeIds.push(receipt.tradeId);
        takerTrades[receipt.taker].push(receipt.tradeId);
        providerTrades[receipt.provider].push(receipt.tradeId);
        emit SettlementRecorded(
            receipt.tradeId,
            receipt.rfqId,
            receipt.quoteId,
            receipt.taker,
            receipt.provider,
            receipt.sellToken,
            receipt.buyToken,
            receipt.sellAmount,
            receipt.buyAmount,
            receipt.feeAmount,
            receipt.settledAt
        );
    }

    function getSettlement(bytes32 tradeId) external view returns (SettlementReceipt memory) {
        return receipts[tradeId];
    }

    function settlementCount() external view returns (uint256) {
        return tradeIds.length;
    }

    function settlementAt(uint256 index) external view returns (SettlementReceipt memory) {
        if (index >= tradeIds.length) revert InvalidPagination();
        return receipts[tradeIds[index]];
    }

    function getSettlements(uint256 offset, uint256 limit)
        external
        view
        returns (SettlementReceipt[] memory)
    {
        return _page(tradeIds, offset, limit);
    }

    function getSettlementsByTaker(address taker, uint256 offset, uint256 limit)
        external
        view
        returns (SettlementReceipt[] memory)
    {
        return _page(takerTrades[taker], offset, limit);
    }

    function getSettlementsByProvider(address provider, uint256 offset, uint256 limit)
        external
        view
        returns (SettlementReceipt[] memory)
    {
        return _page(providerTrades[provider], offset, limit);
    }

    function _page(bytes32[] storage ids, uint256 offset, uint256 limit)
        private
        view
        returns (SettlementReceipt[] memory page)
    {
        if (limit == 0 || limit > 100 || offset > ids.length) revert InvalidPagination();
        uint256 end = offset + limit;
        if (end > ids.length) end = ids.length;
        page = new SettlementReceipt[](end - offset);
        for (uint256 i; i < page.length; i++) {
            page[i] = receipts[ids[offset + i]];
        }
    }
}
