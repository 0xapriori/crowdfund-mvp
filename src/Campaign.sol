// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Campaign - Crowdfunding with dominant assurance
/// @notice A 25bps fee is taken on every contribution. If the campaign succeeds,
///         fees go to the protocol treasury and the creator receives the raised funds.
///         If it fails, backers get their net contribution back PLUS a proportional
///         share of the fee pool as interest (dominant assurance).
contract Campaign is ReentrancyGuard {
    // ── Types ──────────────────────────────────────────────────────────
    enum State { Active, Successful, Failed, Cancelled }

    struct Contribution {
        uint256 amount;       // Net amount after fee
        uint256 timestamp;
        bool refundClaimed;
    }

    // ── Constants ──────────────────────────────────────────────────────
    uint256 public constant PROTOCOL_FEE_BPS = 25; // 0.25%

    // ── Immutables ─────────────────────────────────────────────────────
    uint256 public immutable campaignId;
    address public immutable creator;
    address public immutable factory;
    address public immutable treasury;
    uint256 public immutable fundingGoal;
    uint256 public immutable deadline;
    uint256 public immutable minContribution;
    uint256 public immutable createdAt;

    // ── Mutable State ──────────────────────────────────────────────────
    string public metadataURI;
    State public state;
    uint256 public totalRaised;   // Sum of net contributions (after fees)
    uint256 public feePool;       // Accumulated 25bps fees from all contributions
    uint256 public backerCount;
    bool public creatorWithdrawn;

    mapping(address => Contribution) public contributions;
    address[] public backers;

    // ── Events ─────────────────────────────────────────────────────────
    event ContributionMade(address indexed backer, uint256 netAmount, uint256 fee);
    event ContributionIncreased(address indexed backer, uint256 additionalNet, uint256 fee, uint256 newTotal);
    event CampaignSettled(State finalState, uint256 totalRaised, uint256 feePool);
    event RefundClaimed(address indexed backer, uint256 refund, uint256 interest);
    event CreatorWithdrawal(address indexed creator, uint256 amount);
    event FeesTransferred(address indexed treasury, uint256 amount);
    event CampaignCancelled();

    // ── Errors ─────────────────────────────────────────────────────────
    error CampaignNotActive();
    error DeadlineNotReached();
    error DeadlinePassed();
    error BelowMinContribution();
    error AlreadyContributed();
    error NothingToClaim();
    error AlreadyClaimed();
    error AlreadyWithdrawn();
    error NotCreator();
    error TransferFailed();
    error HasContributions();
    error WrongState();
    error ZeroAmount();

    // ── Constructor ────────────────────────────────────────────────────
    constructor(
        uint256 _campaignId,
        address _creator,
        address _treasury,
        uint256 _fundingGoal,
        uint256 _deadline,
        uint256 _minContribution,
        string memory _metadataURI
    ) {
        campaignId = _campaignId;
        creator = _creator;
        factory = msg.sender;
        treasury = _treasury;
        fundingGoal = _fundingGoal;
        deadline = _deadline;
        minContribution = _minContribution;
        metadataURI = _metadataURI;
        createdAt = block.timestamp;
        state = State.Active;
    }

    // ── Core Functions ─────────────────────────────────────────────────

    /// @notice Contribute ETH to this campaign. 25bps fee is deducted.
    function contribute() external payable nonReentrant {
        if (state != State.Active) revert CampaignNotActive();
        if (block.timestamp >= deadline) revert DeadlinePassed();
        if (msg.value < minContribution) revert BelowMinContribution();
        if (contributions[msg.sender].amount > 0) revert AlreadyContributed();

        uint256 fee = (msg.value * PROTOCOL_FEE_BPS) / 10_000;
        uint256 netAmount = msg.value - fee;

        contributions[msg.sender] = Contribution({
            amount: netAmount,
            timestamp: block.timestamp,
            refundClaimed: false
        });

        backers.push(msg.sender);
        totalRaised += netAmount;
        feePool += fee;
        backerCount++;

        emit ContributionMade(msg.sender, netAmount, fee);
    }

    /// @notice Increase an existing contribution. 25bps fee is deducted.
    function contributeMore() external payable nonReentrant {
        if (state != State.Active) revert CampaignNotActive();
        if (block.timestamp >= deadline) revert DeadlinePassed();
        if (msg.value == 0) revert ZeroAmount();
        if (contributions[msg.sender].amount == 0) revert NothingToClaim();

        uint256 fee = (msg.value * PROTOCOL_FEE_BPS) / 10_000;
        uint256 netAmount = msg.value - fee;

        contributions[msg.sender].amount += netAmount;
        totalRaised += netAmount;
        feePool += fee;

        emit ContributionIncreased(msg.sender, netAmount, fee, contributions[msg.sender].amount);
    }

    /// @notice Settle the campaign after the deadline. Permissionless.
    function settle() external {
        if (state != State.Active) revert WrongState();
        if (block.timestamp < deadline) revert DeadlineNotReached();

        if (totalRaised >= fundingGoal) {
            state = State.Successful;
        } else {
            state = State.Failed;
        }

        emit CampaignSettled(state, totalRaised, feePool);
    }

    /// @notice Creator withdraws raised funds from a successful campaign.
    ///         Fees are sent to the treasury.
    function creatorWithdraw() external nonReentrant {
        if (msg.sender != creator) revert NotCreator();
        if (state != State.Successful) revert WrongState();
        if (creatorWithdrawn) revert AlreadyWithdrawn();

        creatorWithdrawn = true;

        uint256 fees = feePool;
        uint256 creatorAmount = totalRaised;

        // Send fees to treasury
        if (fees > 0) {
            (bool feeSuccess,) = treasury.call{value: fees}("");
            if (!feeSuccess) revert TransferFailed();
            emit FeesTransferred(treasury, fees);
        }

        // Send raised funds to creator
        (bool success,) = creator.call{value: creatorAmount}("");
        if (!success) revert TransferFailed();

        emit CreatorWithdrawal(creator, creatorAmount);
    }

    /// @notice Backer claims refund + interest from a failed campaign.
    ///         Interest = proportional share of the fee pool (dominant assurance).
    function claimRefund() external nonReentrant {
        if (state != State.Failed) revert WrongState();

        Contribution storage c = contributions[msg.sender];
        if (c.amount == 0) revert NothingToClaim();
        if (c.refundClaimed) revert AlreadyClaimed();

        c.refundClaimed = true;

        // Interest: proportional share of fee pool
        uint256 interest = (c.amount * feePool) / totalRaised;
        uint256 payout = c.amount + interest;

        (bool success,) = msg.sender.call{value: payout}("");
        if (!success) revert TransferFailed();

        emit RefundClaimed(msg.sender, c.amount, interest);
    }

    /// @notice Creator can cancel only if no contributions received
    function cancel() external {
        if (msg.sender != creator) revert NotCreator();
        if (state != State.Active) revert WrongState();
        if (backerCount > 0) revert HasContributions();

        state = State.Cancelled;
        emit CampaignCancelled();
    }

    // ── View Functions ─────────────────────────────────────────────────

    /// @notice Get funding progress (net amounts after fees)
    function getFundingProgress() external view returns (uint256 raised, uint256 goal, uint256 percentage) {
        raised = totalRaised;
        goal = fundingGoal;
        percentage = fundingGoal > 0 ? (totalRaised * 100) / fundingGoal : 0;
    }

    /// @notice Get contribution details for a backer
    function getContribution(address backer) external view returns (uint256 amount, uint256 timestamp, bool claimed) {
        Contribution memory c = contributions[backer];
        return (c.amount, c.timestamp, c.refundClaimed);
    }

    /// @notice Get all backer addresses
    function getBackers() external view returns (address[] memory) {
        return backers;
    }

    /// @notice Calculate refund + interest for a backer (view only)
    function calculateRefund(address backer) external view returns (uint256 refund, uint256 interest) {
        Contribution memory c = contributions[backer];
        if (c.amount == 0 || c.refundClaimed) return (0, 0);
        refund = c.amount;
        interest = totalRaised > 0 ? (c.amount * feePool) / totalRaised : 0;
    }

    /// @notice Seconds remaining until deadline
    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    /// @notice Whether campaign is accepting contributions
    function isActive() external view returns (bool) {
        return state == State.Active && block.timestamp < deadline;
    }

    /// @notice Get campaign summary in one call
    function getSummary() external view returns (
        uint256 _campaignId,
        address _creator,
        uint256 _fundingGoal,
        uint256 _deadline,
        uint256 _minContribution,
        uint256 _feePool,
        uint256 _totalRaised,
        uint256 _backerCount,
        State _state,
        string memory _metadataURI
    ) {
        return (
            campaignId, creator, fundingGoal, deadline,
            minContribution, feePool, totalRaised,
            backerCount, state, metadataURI
        );
    }
}
