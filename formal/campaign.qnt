// Formal specification of the Crowdfund Campaign contract
// Models the Campaign.sol state machine with dominant assurance mechanics
module Campaign {

  // ── Types ──────────────────────────────────────────────────────────

  type State = Active | Successful | Failed | Cancelled

  // ── Constants ──────────────────────────────────────────────────────

  const PROTOCOL_FEE_BPS: int
  const FUNDING_GOAL: int
  const DEADLINE: int
  const MIN_CONTRIBUTION: int
  const CREATOR: str
  // Set of all possible addresses that can interact
  const ADDRESSES: Set[str]

  // ── State Variables ────────────────────────────────────────────────

  var campaignState: State
  var totalRaised: int          // Sum of net contributions (after fees)
  var feePool: int              // Accumulated 25bps fees
  var backerCount: int
  var creatorWithdrawn: bool
  var contributions: str -> int // address -> net contribution amount
  var refundsClaimed: str -> bool  // address -> whether refund claimed
  var blockTimestamp: int       // Model of block.timestamp
  var totalMsgValues: int       // Sum of all msg.values ever sent (for conservation check)
  var contractBalance: int      // ETH balance of the campaign contract

  // ── Helper Functions ───────────────────────────────────────────────

  // Pure function: compute fee from a msg.value
  pure def computeFee(msgValue: int): int = (msgValue * PROTOCOL_FEE_BPS) / 10000

  // Pure function: compute net amount from a msg.value
  pure def computeNet(msgValue: int): int = msgValue - computeFee(msgValue)

  // Check if an address has contributed
  def hasContributed(addr: str): bool = contributions.get(addr) > 0

  // Check if an address has claimed refund
  def hasClaimedRefund(addr: str): bool = refundsClaimed.get(addr)

  // ── Initialization ─────────────────────────────────────────────────

  action init = all {
    campaignState' = Active,
    totalRaised' = 0,
    feePool' = 0,
    backerCount' = 0,
    creatorWithdrawn' = false,
    contributions' = ADDRESSES.mapBy(_ => 0),
    refundsClaimed' = ADDRESSES.mapBy(_ => false),
    blockTimestamp' = 0,
    totalMsgValues' = 0,
    contractBalance' = 0,
  }

  // ── Actions ────────────────────────────────────────────────────────

  // contribute(): First-time contribution from a backer
  action contribute(sender: str, msgValue: int): bool = all {
    // Preconditions
    campaignState == Active,
    blockTimestamp < DEADLINE,
    msgValue >= MIN_CONTRIBUTION,
    not(hasContributed(sender)),
    sender != CREATOR,
    ADDRESSES.contains(sender),

    // Effects
    val fee = computeFee(msgValue)
    val netAmount = computeNet(msgValue)
    all {
      contributions' = contributions.set(sender, netAmount),
      totalRaised' = totalRaised + netAmount,
      feePool' = feePool + fee,
      backerCount' = backerCount + 1,
      totalMsgValues' = totalMsgValues + msgValue,
      contractBalance' = contractBalance + msgValue,
      // Unchanged
      campaignState' = campaignState,
      creatorWithdrawn' = creatorWithdrawn,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
    }
  }

  // contributeMore(): Additional contribution from existing backer
  action contributeMore(sender: str, msgValue: int): bool = all {
    // Preconditions
    campaignState == Active,
    blockTimestamp < DEADLINE,
    msgValue > 0,
    hasContributed(sender),
    ADDRESSES.contains(sender),

    // Effects
    val fee = computeFee(msgValue)
    val netAmount = computeNet(msgValue)
    all {
      contributions' = contributions.set(sender, contributions.get(sender) + netAmount),
      totalRaised' = totalRaised + netAmount,
      feePool' = feePool + fee,
      totalMsgValues' = totalMsgValues + msgValue,
      contractBalance' = contractBalance + msgValue,
      // Unchanged
      campaignState' = campaignState,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
    }
  }

  // settle(): Finalize campaign after deadline
  action settle: bool = all {
    // Preconditions
    campaignState == Active,
    blockTimestamp >= DEADLINE,

    // Effects
    if (totalRaised >= FUNDING_GOAL) all {
      campaignState' = Successful,
    } else all {
      campaignState' = Failed,
    },

    // Unchanged
    totalRaised' = totalRaised,
    feePool' = feePool,
    backerCount' = backerCount,
    creatorWithdrawn' = creatorWithdrawn,
    contributions' = contributions,
    refundsClaimed' = refundsClaimed,
    blockTimestamp' = blockTimestamp,
    totalMsgValues' = totalMsgValues,
    contractBalance' = contractBalance,
  }

  // creatorWithdraw(): Creator withdraws funds on success
  action creatorWithdraw(sender: str): bool = all {
    // Preconditions
    sender == CREATOR,
    campaignState == Successful,
    not(creatorWithdrawn),

    // Effects: totalRaised goes to creator, feePool goes to treasury
    creatorWithdrawn' = true,
    contractBalance' = contractBalance - totalRaised - feePool,

    // Unchanged
    campaignState' = campaignState,
    totalRaised' = totalRaised,
    feePool' = feePool,
    backerCount' = backerCount,
    contributions' = contributions,
    refundsClaimed' = refundsClaimed,
    blockTimestamp' = blockTimestamp,
    totalMsgValues' = totalMsgValues,
  }

  // claimRefund(): Backer claims refund + interest on failure
  action claimRefund(sender: str): bool = all {
    // Preconditions
    campaignState == Failed,
    hasContributed(sender),
    not(hasClaimedRefund(sender)),
    ADDRESSES.contains(sender),

    // Effects
    val backerAmount = contributions.get(sender)
    val interest = (backerAmount * feePool) / totalRaised
    val payout = backerAmount + interest
    all {
      refundsClaimed' = refundsClaimed.set(sender, true),
      contractBalance' = contractBalance - payout,
      // Unchanged
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
    }
  }

  // cancel(): Creator cancels campaign with 0 backers
  action cancel(sender: str): bool = all {
    // Preconditions
    sender == CREATOR,
    campaignState == Active,
    backerCount == 0,

    // Effects
    campaignState' = Cancelled,

    // Unchanged
    totalRaised' = totalRaised,
    feePool' = feePool,
    backerCount' = backerCount,
    creatorWithdrawn' = creatorWithdrawn,
    contributions' = contributions,
    refundsClaimed' = refundsClaimed,
    blockTimestamp' = blockTimestamp,
    totalMsgValues' = totalMsgValues,
    contractBalance' = contractBalance,
  }

  // advanceTime(): Model time progression
  action advanceTime(delta: int): bool = all {
    delta > 0,
    blockTimestamp' = blockTimestamp + delta,
    // Unchanged
    campaignState' = campaignState,
    totalRaised' = totalRaised,
    feePool' = feePool,
    backerCount' = backerCount,
    creatorWithdrawn' = creatorWithdrawn,
    contributions' = contributions,
    refundsClaimed' = refundsClaimed,
    totalMsgValues' = totalMsgValues,
    contractBalance' = contractBalance,
  }

  // Non-deterministic step: any valid action can happen
  action step = any {
    nondet sender = ADDRESSES.oneOf()
    nondet msgValue = 1.to(10000).oneOf()
    contribute(sender, msgValue),

    nondet sender = ADDRESSES.oneOf()
    nondet msgValue = 1.to(5000).oneOf()
    contributeMore(sender, msgValue),

    settle,

    nondet sender = ADDRESSES.oneOf()
    creatorWithdraw(sender),

    nondet sender = ADDRESSES.oneOf()
    claimRefund(sender),

    nondet sender = ADDRESSES.oneOf()
    cancel(sender),

    nondet delta = 1.to(200).oneOf()
    advanceTime(delta),
  }

  // ── Invariants ─────────────────────────────────────────────────────

  // Fee Conservation: feePool + totalRaised == sum of all msg.values
  val feeConservation: bool = feePool + totalRaised == totalMsgValues

  // Contract balance is always non-negative
  val contractBalanceNonNegative: bool = contractBalance >= 0

  // Successful requires funding goal met
  val successRequiresGoal: bool =
    (campaignState == Successful) implies (totalRaised >= FUNDING_GOAL)

  // Failed requires goal not met
  val failedRequiresGoalNotMet: bool =
    (campaignState == Failed) implies (totalRaised < FUNDING_GOAL)

  // Cancelled requires no backers
  val cancelledRequiresNoBackers: bool =
    (campaignState == Cancelled) implies (backerCount == 0)

  // Creator withdraw only possible on success
  val creatorWithdrawOnlyOnSuccess: bool =
    creatorWithdrawn implies (campaignState == Successful)

  // Refund claims only happen in Failed state
  val refundClaimsOnlyOnFailure: bool =
    ADDRESSES.forall(addr =>
      refundsClaimed.get(addr) implies (campaignState == Failed)
    )

  // backerCount matches addresses with non-zero contributions
  val backerCountConsistency: bool =
    backerCount == ADDRESSES.filter(addr => contributions.get(addr) > 0).size()

  // totalRaised matches sum of all contributions
  val totalRaisedMatchesContributions: bool =
    totalRaised == ADDRESSES.fold(0, (acc, addr) => acc + contributions.get(addr))

  // Settle only after deadline (non-Active non-Cancelled implies deadline reached)
  val settleOnlyAfterDeadline: bool = and {
    (campaignState == Successful) implies (blockTimestamp >= DEADLINE),
    (campaignState == Failed) implies (blockTimestamp >= DEADLINE),
  }

  // Fee pool bounded by protocol fee rate
  val feePoolBounded: bool = and {
    feePool * 10000 <= totalMsgValues * PROTOCOL_FEE_BPS,
    feePool >= 0,
  }

  // After creator withdraw on success, contract balance == 0
  val successWithdrawDrainsContract: bool =
    (campaignState == Successful and creatorWithdrawn) implies (contractBalance == 0)

  // Cancelled means no funds in contract
  val cancelledMeansNoFunds: bool =
    (campaignState == Cancelled) implies (totalRaised == 0 and feePool == 0 and contractBalance == 0)

  // Combined safety invariant
  val safetyInvariant: bool = and {
    feeConservation,
    contractBalanceNonNegative,
    successRequiresGoal,
    failedRequiresGoalNotMet,
    cancelledRequiresNoBackers,
    creatorWithdrawOnlyOnSuccess,
    refundClaimsOnlyOnFailure,
    backerCountConsistency,
    totalRaisedMatchesContributions,
    settleOnlyAfterDeadline,
    feePoolBounded,
    successWithdrawDrainsContract,
    cancelledMeansNoFunds,
  }
}
