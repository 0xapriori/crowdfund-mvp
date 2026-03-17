// Test scenarios for the Crowdfund Campaign specification
module CampaignTest {
  import Campaign(
    PROTOCOL_FEE_BPS = 25,
    FUNDING_GOAL = 5000,
    DEADLINE = 100,
    MIN_CONTRIBUTION = 100,
    CREATOR = "creator",
    ADDRESSES = Set("creator", "alice", "bob", "charlie")
  ).* from "./campaign"

  // ── Test 1: Basic contribution flow ──────────────────────────────
  // Alice contributes 1000 wei. Fee = (1000 * 25) / 10000 = 2. Net = 998.
  run contributeTest = {
    init
    .then(contribute("alice", 1000))
    .then(all {
      assert(totalRaised == 998),
      assert(feePool == 2),
      assert(backerCount == 1),
      assert(contributions.get("alice") == 998),
      assert(totalMsgValues == 1000),
      assert(contractBalance == 1000),
      assert(feeConservation),
      // Keep state unchanged for assertion step
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
  }

  // ── Test 2: Multiple contributions and fee conservation ──────────
  run multiContributeTest = {
    init
    .then(contribute("alice", 2000))
    .then(contribute("bob", 4000))
    .then(all {
      // Alice: fee = 5, net = 1995. Bob: fee = 10, net = 3990.
      assert(totalRaised == 1995 + 3990),
      assert(feePool == 5 + 10),
      assert(backerCount == 2),
      assert(feeConservation),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
  }

  // ── Test 3: contributeMore flow ──────────────────────────────────
  run contributeMoreTest = {
    init
    .then(contribute("alice", 1000))
    .then(contributeMore("alice", 2000))
    .then(all {
      // First: fee=2, net=998. Second: fee=5, net=1995. Total net=2993.
      assert(contributions.get("alice") == 2993),
      assert(totalRaised == 2993),
      assert(feePool == 7),
      assert(backerCount == 1),
      assert(feeConservation),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
  }

  // ── Test 4: Successful campaign path ─────────────────────────────
  run successPathTest = {
    init
    .then(contribute("alice", 3000))
    .then(contribute("bob", 4000))
    .then(advanceTime(100))
    .then(settle)
    .then(all {
      assert(campaignState == Successful),
      assert(totalRaised >= FUNDING_GOAL),
      assert(successRequiresGoal),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
    .then(creatorWithdraw("creator"))
    .then(all {
      assert(creatorWithdrawn == true),
      assert(contractBalance == 0),
      assert(successWithdrawDrainsContract),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
  }

  // ── Test 5: Failed campaign with refunds ─────────────────────────
  run failurePathTest = {
    init
    .then(contribute("alice", 2000))
    .then(contribute("bob", 1000))
    .then(advanceTime(100))
    .then(settle)
    .then(all {
      assert(campaignState == Failed),
      assert(totalRaised < FUNDING_GOAL),
      assert(failedRequiresGoalNotMet),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
    .then(claimRefund("alice"))
    .then(all {
      assert(refundsClaimed.get("alice") == true),
      assert(contractBalance >= 0),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
    .then(claimRefund("bob"))
    .then(all {
      assert(refundsClaimed.get("bob") == true),
      assert(contractBalance >= 0),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
  }

  // ── Test 6: Cancel with no backers ───────────────────────────────
  run cancelTest = {
    init
    .then(cancel("creator"))
    .then(all {
      assert(campaignState == Cancelled),
      assert(backerCount == 0),
      assert(totalRaised == 0),
      assert(feePool == 0),
      assert(cancelledMeansNoFunds),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
  }

  // ── Test 7: Cannot contribute after deadline ─────────────────────
  run noContributeAfterDeadlineTest = {
    init
    .then(advanceTime(100))
    .then(
      contribute("alice", 1000)
      .fail()
    )
  }

  // ── Test 8: Cannot contribute below minimum ──────────────────────
  run noContributeBelowMinTest = {
    init
    .then(
      contribute("alice", 50)
      .fail()
    )
  }

  // ── Test 9: Cannot double contribute ─────────────────────────────
  run noDoubleContributeTest = {
    init
    .then(contribute("alice", 1000))
    .then(
      contribute("alice", 2000)
      .fail()
    )
  }

  // ── Test 10: Cannot cancel with backers ──────────────────────────
  run noCancelWithBackersTest = {
    init
    .then(contribute("alice", 1000))
    .then(
      cancel("creator")
      .fail()
    )
  }

  // ── Test 11: Cannot settle before deadline ───────────────────────
  run noSettleBeforeDeadlineTest = {
    init
    .then(contribute("alice", 1000))
    .then(
      settle
      .fail()
    )
  }

  // ── Test 12: Cannot double-claim refund ──────────────────────────
  run noDoubleClaimTest = {
    init
    .then(contribute("alice", 2000))
    .then(advanceTime(100))
    .then(settle)
    .then(claimRefund("alice"))
    .then(
      claimRefund("alice")
      .fail()
    )
  }

  // ── Test 13: Cannot double-withdraw ──────────────────────────────
  run noDoubleWithdrawTest = {
    init
    .then(contribute("alice", 3000))
    .then(contribute("bob", 4000))
    .then(advanceTime(100))
    .then(settle)
    .then(creatorWithdraw("creator"))
    .then(
      creatorWithdraw("creator")
      .fail()
    )
  }

  // ── Test 14: Only creator can withdraw ───────────────────────────
  run onlyCreatorWithdrawTest = {
    init
    .then(contribute("alice", 3000))
    .then(contribute("bob", 4000))
    .then(advanceTime(100))
    .then(settle)
    .then(
      creatorWithdraw("alice")
      .fail()
    )
  }

  // ── Test 15: Only creator can cancel ─────────────────────────────
  run onlyCreatorCancelTest = {
    init
    .then(
      cancel("alice")
      .fail()
    )
  }

  // ── Test 16: Cannot claim refund on successful campaign ──────────
  run noRefundOnSuccessTest = {
    init
    .then(contribute("alice", 3000))
    .then(contribute("bob", 4000))
    .then(advanceTime(100))
    .then(settle)
    .then(
      claimRefund("alice")
      .fail()
    )
  }

  // ── Test 17: Cannot withdraw on failed campaign ──────────────────
  run noWithdrawOnFailureTest = {
    init
    .then(contribute("alice", 2000))
    .then(advanceTime(100))
    .then(settle)
    .then(
      creatorWithdraw("creator")
      .fail()
    )
  }

  // ── Test 18: Fee conservation across contribute + contributeMore ─
  run feeConservationTest = {
    init
    .then(contribute("alice", 4000))
    .then(contributeMore("alice", 2000))
    .then(contribute("bob", 3000))
    .then(all {
      assert(feeConservation),
      assert(totalMsgValues == 9000),
      assert(feePool == 10 + 5 + 7),
      assert(totalRaised == 3990 + 1995 + 2993),
      campaignState' = campaignState,
      totalRaised' = totalRaised,
      feePool' = feePool,
      backerCount' = backerCount,
      creatorWithdrawn' = creatorWithdrawn,
      contributions' = contributions,
      refundsClaimed' = refundsClaimed,
      blockTimestamp' = blockTimestamp,
      totalMsgValues' = totalMsgValues,
      contractBalance' = contractBalance,
    })
  }

  // ── Simulation run: random execution for invariant checking ──────
  run simulation = {
    init.then(50.reps(_ => step))
  }
}
