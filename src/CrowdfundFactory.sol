// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Campaign.sol";

/// @title CrowdfundFactory - Deploys and indexes crowdfunding campaigns
/// @notice Permissionless, immutable factory. Anyone can create a campaign.
///         No upfront cost to create — fees are collected from backer contributions.
contract CrowdfundFactory {
    // ── Constants ──────────────────────────────────────────────────────
    uint256 public constant PROTOCOL_FEE_BPS = 25;       // 0.25%
    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MAX_DURATION = 90 days;

    // ── State ──────────────────────────────────────────────────────────
    address public immutable treasury;
    uint256 public nextCampaignId;
    mapping(uint256 => address) public campaigns; // campaignId → Campaign address

    // ── Events ─────────────────────────────────────────────────────────
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed campaignAddress,
        address indexed creator,
        uint256 fundingGoal,
        uint256 deadline
    );

    // ── Errors ─────────────────────────────────────────────────────────
    error ZeroGoal();
    error InvalidDeadline();
    error InvalidMinContribution();
    error EmptyMetadata();

    // ── Constructor ────────────────────────────────────────────────────
    constructor(address _treasury) {
        treasury = _treasury;
    }

    // ── Campaign Creation ──────────────────────────────────────────────

    /// @notice Create a new crowdfunding campaign. No ETH required.
    /// @param _fundingGoal Target amount in wei (net, after fees)
    /// @param _deadline Unix timestamp for campaign end
    /// @param _minContribution Minimum contribution per backer in wei
    /// @param _metadataURI IPFS hash or URL for campaign metadata JSON
    function createCampaign(
        uint256 _fundingGoal,
        uint256 _deadline,
        uint256 _minContribution,
        string calldata _metadataURI
    ) external returns (uint256 campaignId, address campaignAddress) {
        if (_fundingGoal == 0) revert ZeroGoal();

        uint256 duration = _deadline - block.timestamp;
        if (_deadline <= block.timestamp || duration < MIN_DURATION || duration > MAX_DURATION) {
            revert InvalidDeadline();
        }

        if (_minContribution == 0 || _minContribution > _fundingGoal) {
            revert InvalidMinContribution();
        }

        if (bytes(_metadataURI).length == 0) revert EmptyMetadata();

        campaignId = nextCampaignId++;

        Campaign campaign = new Campaign(
            campaignId,
            msg.sender,
            treasury,
            _fundingGoal,
            _deadline,
            _minContribution,
            _metadataURI
        );

        campaignAddress = address(campaign);
        campaigns[campaignId] = campaignAddress;

        emit CampaignCreated(
            campaignId,
            campaignAddress,
            msg.sender,
            _fundingGoal,
            _deadline
        );
    }

    // ── View Functions ─────────────────────────────────────────────────

    function getCampaign(uint256 _campaignId) external view returns (address) {
        return campaigns[_campaignId];
    }

    function getCampaignCount() external view returns (uint256) {
        return nextCampaignId;
    }

    function getCampaigns(uint256 _start, uint256 _count) external view returns (address[] memory) {
        uint256 total = nextCampaignId;
        if (_start >= total) {
            return new address[](0);
        }

        uint256 end = _start + _count;
        if (end > total) end = total;
        uint256 length = end - _start;

        address[] memory result = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = campaigns[_start + i];
        }
        return result;
    }
}
