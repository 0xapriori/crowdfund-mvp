// Verification module: instantiates Campaign with concrete values
// and exposes invariants for quint verify / quint run
module CampaignVerify {
  import Campaign(
    PROTOCOL_FEE_BPS = 25,
    FUNDING_GOAL = 5000,
    DEADLINE = 100,
    MIN_CONTRIBUTION = 100,
    CREATOR = "creator",
    ADDRESSES = Set("creator", "alice", "bob", "charlie")
  ).* from "./campaign"

  // The main invariant to verify across all reachable states
  val inv = safetyInvariant
}
