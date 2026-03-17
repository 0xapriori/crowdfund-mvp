// Bounded verification module with smaller state space for exhaustive checking
module CampaignVerifyBounded {
  import Campaign(
    PROTOCOL_FEE_BPS = 25,
    FUNDING_GOAL = 500,
    DEADLINE = 5,
    MIN_CONTRIBUTION = 100,
    CREATOR = "creator",
    ADDRESSES = Set("creator", "alice", "bob")
  ).* from "./campaign"

  // Bounded step: constrain nondeterministic values to small ranges
  action boundedStep = any {
    nondet sender = ADDRESSES.oneOf()
    nondet msgValue = Set(100, 200, 300, 500).oneOf()
    contribute(sender, msgValue),

    nondet sender = ADDRESSES.oneOf()
    nondet msgValue = Set(100, 200).oneOf()
    contributeMore(sender, msgValue),

    settle,

    nondet sender = ADDRESSES.oneOf()
    creatorWithdraw(sender),

    nondet sender = ADDRESSES.oneOf()
    claimRefund(sender),

    nondet sender = ADDRESSES.oneOf()
    cancel(sender),

    nondet delta = Set(1, 2, 3, 5).oneOf()
    advanceTime(delta),
  }

  val inv = safetyInvariant
}
