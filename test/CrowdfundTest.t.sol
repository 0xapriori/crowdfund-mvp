// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Treasury.sol";
import "../src/Campaign.sol";
import "../src/CrowdfundFactory.sol";

contract CrowdfundTest is Test {
    Treasury treasury;
    CrowdfundFactory factory;

    address admin = makeAddr("admin");
    address creator = makeAddr("creator");
    address backer1 = makeAddr("backer1");
    address backer2 = makeAddr("backer2");
    address backer3 = makeAddr("backer3");
    address nobody = makeAddr("nobody");

    uint256 constant GOAL = 10 ether;
    uint256 constant MIN_CONTRIBUTION = 0.1 ether;
    uint256 constant FEE_BPS = 25;
    string constant METADATA = "ipfs://QmTest";

    function setUp() public {
        treasury = new Treasury(admin);
        factory = new CrowdfundFactory(address(treasury));

        vm.deal(creator, 100 ether);
        vm.deal(backer1, 100 ether);
        vm.deal(backer2, 100 ether);
        vm.deal(backer3, 100 ether);
        vm.deal(admin, 10 ether);
    }

    // ─── Helpers ────────────────────────────────────────────────────────

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 7 days;
    }

    function _fee(uint256 amount) internal pure returns (uint256) {
        return (amount * FEE_BPS) / 10_000;
    }

    function _net(uint256 amount) internal pure returns (uint256) {
        return amount - _fee(amount);
    }

    function _createCampaign() internal returns (Campaign campaign) {
        vm.prank(creator);
        (, address addr) = factory.createCampaign(
            GOAL, _deadline(), MIN_CONTRIBUTION, METADATA
        );
        campaign = Campaign(payable(addr));
    }

    // ═════════════════════════════════════════════════════════════════════
    //  TREASURY TESTS
    // ═════════════════════════════════════════════════════════════════════

    function test_Treasury_constructorSetsAdmin() public view {
        assertEq(treasury.admin(), admin);
    }

    function test_Treasury_constructorRevertsZeroAddress() public {
        vm.expectRevert(Treasury.ZeroAddress.selector);
        new Treasury(address(0));
    }

    function test_Treasury_receiveETH() public {
        vm.expectEmit(true, false, false, true, address(treasury));
        emit Treasury.FeeReceived(address(this), 1 ether);
        (bool ok,) = address(treasury).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(treasury.getBalance(), 1 ether);
    }

    function test_Treasury_withdrawByAdmin() public {
        vm.deal(address(treasury), 5 ether);

        uint256 balBefore = nobody.balance;
        vm.prank(admin);
        treasury.withdraw(nobody, 2 ether);
        assertEq(nobody.balance, balBefore + 2 ether);
        assertEq(treasury.getBalance(), 3 ether);
    }

    function test_Treasury_withdrawRevertsForNonAdmin() public {
        vm.deal(address(treasury), 5 ether);
        vm.prank(nobody);
        vm.expectRevert(Treasury.NotAdmin.selector);
        treasury.withdraw(nobody, 1 ether);
    }

    function test_Treasury_withdrawRevertsZeroAddress() public {
        vm.deal(address(treasury), 5 ether);
        vm.prank(admin);
        vm.expectRevert(Treasury.ZeroAddress.selector);
        treasury.withdraw(address(0), 1 ether);
    }

    function test_Treasury_withdrawRevertsZeroAmount() public {
        vm.deal(address(treasury), 5 ether);
        vm.prank(admin);
        vm.expectRevert(Treasury.ZeroAmount.selector);
        treasury.withdraw(nobody, 0);
    }

    function test_Treasury_withdrawRevertsExceedsBalance() public {
        vm.deal(address(treasury), 1 ether);
        vm.prank(admin);
        vm.expectRevert(Treasury.ZeroAmount.selector);
        treasury.withdraw(nobody, 2 ether);
    }

    function test_Treasury_transferAdmin() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, false, address(treasury));
        emit Treasury.AdminTransferred(admin, nobody);
        treasury.transferAdmin(nobody);
        assertEq(treasury.admin(), nobody);
    }

    function test_Treasury_transferAdminRevertsNonAdmin() public {
        vm.prank(nobody);
        vm.expectRevert(Treasury.NotAdmin.selector);
        treasury.transferAdmin(nobody);
    }

    function test_Treasury_transferAdminRevertsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(Treasury.ZeroAddress.selector);
        treasury.transferAdmin(address(0));
    }

    // ═════════════════════════════════════════════════════════════════════
    //  FACTORY TESTS
    // ═════════════════════════════════════════════════════════════════════

    function test_Factory_createCampaignNoETHRequired() public {
        vm.prank(creator);
        (uint256 id, address addr) = factory.createCampaign(
            GOAL, _deadline(), MIN_CONTRIBUTION, METADATA
        );
        assertEq(id, 0);
        assertTrue(addr != address(0));
        assertEq(factory.getCampaign(0), addr);

        // Verify campaign was initialized correctly
        Campaign c = Campaign(payable(addr));
        assertEq(c.creator(), creator);
        assertEq(c.fundingGoal(), GOAL);
        assertEq(c.minContribution(), MIN_CONTRIBUTION);
        assertEq(c.treasury(), address(treasury));
        assertEq(uint256(c.state()), uint256(Campaign.State.Active));
    }

    function test_Factory_revertZeroGoal() public {
        vm.prank(creator);
        vm.expectRevert(CrowdfundFactory.ZeroGoal.selector);
        factory.createCampaign(0, _deadline(), MIN_CONTRIBUTION, METADATA);
    }

    function test_Factory_revertInvalidDeadlinePast() public {
        vm.prank(creator);
        vm.expectRevert(CrowdfundFactory.InvalidDeadline.selector);
        factory.createCampaign(GOAL, block.timestamp, MIN_CONTRIBUTION, METADATA);
    }

    function test_Factory_revertInvalidDeadlineTooShort() public {
        vm.prank(creator);
        vm.expectRevert(CrowdfundFactory.InvalidDeadline.selector);
        factory.createCampaign(GOAL, block.timestamp + 1 hours, MIN_CONTRIBUTION, METADATA);
    }

    function test_Factory_revertInvalidDeadlineTooLong() public {
        vm.prank(creator);
        vm.expectRevert(CrowdfundFactory.InvalidDeadline.selector);
        factory.createCampaign(GOAL, block.timestamp + 91 days, MIN_CONTRIBUTION, METADATA);
    }

    function test_Factory_revertInvalidMinContributionZero() public {
        vm.prank(creator);
        vm.expectRevert(CrowdfundFactory.InvalidMinContribution.selector);
        factory.createCampaign(GOAL, _deadline(), 0, METADATA);
    }

    function test_Factory_revertMinContributionExceedsGoal() public {
        vm.prank(creator);
        vm.expectRevert(CrowdfundFactory.InvalidMinContribution.selector);
        factory.createCampaign(GOAL, _deadline(), GOAL + 1, METADATA);
    }

    function test_Factory_revertEmptyMetadata() public {
        vm.prank(creator);
        vm.expectRevert(CrowdfundFactory.EmptyMetadata.selector);
        factory.createCampaign(GOAL, _deadline(), MIN_CONTRIBUTION, "");
    }

    function test_Factory_campaignCountIncrements() public {
        assertEq(factory.getCampaignCount(), 0);

        vm.prank(creator);
        factory.createCampaign(GOAL, _deadline(), MIN_CONTRIBUTION, METADATA);
        assertEq(factory.getCampaignCount(), 1);

        vm.prank(creator);
        factory.createCampaign(GOAL, _deadline(), MIN_CONTRIBUTION, METADATA);
        assertEq(factory.getCampaignCount(), 2);
    }

    function test_Factory_getCampaignsPagination() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(creator);
            factory.createCampaign(GOAL, _deadline(), MIN_CONTRIBUTION, METADATA);
        }

        // Get first 3
        address[] memory page1 = factory.getCampaigns(0, 3);
        assertEq(page1.length, 3);

        // Get next 3 (only 2 remain)
        address[] memory page2 = factory.getCampaigns(3, 3);
        assertEq(page2.length, 2);

        // Out of range
        address[] memory page3 = factory.getCampaigns(10, 5);
        assertEq(page3.length, 0);
    }

    // ═════════════════════════════════════════════════════════════════════
    //  CAMPAIGN TESTS
    // ═════════════════════════════════════════════════════════════════════

    // ─── Contribute ─────────────────────────────────────────────────────

    function test_Campaign_contributeDeductsFeeAndStoresNet() public {
        Campaign c = _createCampaign();

        uint256 grossAmount = 1 ether;
        uint256 expectedFee = _fee(grossAmount);    // 0.0025 ETH
        uint256 expectedNet = _net(grossAmount);     // 0.9975 ETH

        vm.prank(backer1);
        c.contribute{value: grossAmount}();

        assertEq(c.totalRaised(), expectedNet);
        assertEq(c.feePool(), expectedFee);
        assertEq(c.backerCount(), 1);

        (uint256 amt,,) = c.getContribution(backer1);
        assertEq(amt, expectedNet);
    }

    function test_Campaign_contributeEmitsCorrectEvent() public {
        Campaign c = _createCampaign();

        uint256 grossAmount = 2 ether;
        uint256 expectedFee = _fee(grossAmount);
        uint256 expectedNet = _net(grossAmount);

        vm.prank(backer1);
        vm.expectEmit(true, false, false, true, address(c));
        emit Campaign.ContributionMade(backer1, expectedNet, expectedFee);
        c.contribute{value: grossAmount}();
    }

    function test_Campaign_contributeRevertBelowMin() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        vm.expectRevert(Campaign.BelowMinContribution.selector);
        c.contribute{value: 0.01 ether}();
    }

    function test_Campaign_contributeRevertAlreadyContributed() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.prank(backer1);
        vm.expectRevert(Campaign.AlreadyContributed.selector);
        c.contribute{value: 1 ether}();
    }

    function test_Campaign_contributeRevertAfterDeadline() public {
        Campaign c = _createCampaign();
        vm.warp(block.timestamp + 8 days);

        vm.prank(backer1);
        vm.expectRevert(Campaign.DeadlinePassed.selector);
        c.contribute{value: 1 ether}();
    }

    function test_Campaign_contributeRevertWhenNotActive() public {
        Campaign c = _createCampaign();

        // Cancel to make it not active
        vm.prank(creator);
        c.cancel();

        vm.prank(backer1);
        vm.expectRevert(Campaign.CampaignNotActive.selector);
        c.contribute{value: 1 ether}();
    }

    // ─── ContributeMore ─────────────────────────────────────────────────

    function test_Campaign_contributeMoreDeductsFee() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        uint256 moreGross = 0.5 ether;
        uint256 moreFee = _fee(moreGross);
        uint256 moreNet = _net(moreGross);

        uint256 feePoolBefore = c.feePool();
        uint256 totalBefore = c.totalRaised();

        vm.prank(backer1);
        c.contributeMore{value: moreGross}();

        assertEq(c.totalRaised(), totalBefore + moreNet);
        assertEq(c.feePool(), feePoolBefore + moreFee);

        (uint256 amt,,) = c.getContribution(backer1);
        assertEq(amt, _net(1 ether) + moreNet);
    }

    function test_Campaign_contributeMoreRevertNoExistingContribution() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        vm.expectRevert(Campaign.NothingToClaim.selector);
        c.contributeMore{value: 0.5 ether}();
    }

    function test_Campaign_contributeMoreRevertZeroAmount() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.prank(backer1);
        vm.expectRevert(Campaign.ZeroAmount.selector);
        c.contributeMore{value: 0}();
    }

    function test_Campaign_contributeMoreRevertAfterDeadline() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.warp(block.timestamp + 8 days);

        vm.prank(backer1);
        vm.expectRevert(Campaign.DeadlinePassed.selector);
        c.contributeMore{value: 0.5 ether}();
    }

    function test_Campaign_contributeMoreRevertWhenNotActive() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        // Settle as failed
        vm.warp(block.timestamp + 8 days);
        c.settle();

        vm.prank(backer1);
        vm.expectRevert(Campaign.CampaignNotActive.selector);
        c.contributeMore{value: 0.5 ether}();
    }

    // ─── Settle ─────────────────────────────────────────────────────────

    function test_Campaign_settleSuccessful() public {
        Campaign c = _createCampaign();

        // Need enough net contributions to meet the goal (10 ETH).
        // net = gross - 25bps. We need net >= 10 ETH.
        // gross * 9975/10000 >= 10 ETH → gross >= 10.025... ETH
        // Use 10.03 ETH to be safe.
        vm.prank(backer1);
        c.contribute{value: 10.03 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle();

        assertEq(uint256(c.state()), uint256(Campaign.State.Successful));
    }

    function test_Campaign_settleFailed() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle();

        assertEq(uint256(c.state()), uint256(Campaign.State.Failed));
    }

    function test_Campaign_settleRevertBeforeDeadline() public {
        Campaign c = _createCampaign();

        vm.expectRevert(Campaign.DeadlineNotReached.selector);
        c.settle();
    }

    function test_Campaign_settleRevertAlreadySettled() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle();

        vm.expectRevert(Campaign.WrongState.selector);
        c.settle();
    }

    // ─── Creator Withdraw ───────────────────────────────────────────────

    function test_Campaign_creatorWithdrawSendsFundsAndFees() public {
        Campaign c = _createCampaign();

        // Contribute enough to succeed
        vm.prank(backer1);
        c.contribute{value: 10.03 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle();

        uint256 expectedFeePool = c.feePool();
        uint256 expectedTotalRaised = c.totalRaised();

        uint256 creatorBalBefore = creator.balance;
        uint256 treasuryBalBefore = address(treasury).balance;

        vm.prank(creator);
        c.creatorWithdraw();

        assertEq(creator.balance, creatorBalBefore + expectedTotalRaised);
        assertEq(address(treasury).balance, treasuryBalBefore + expectedFeePool);
        assertTrue(c.creatorWithdrawn());
    }

    function test_Campaign_creatorWithdrawRevertNotCreator() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 10.03 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle();

        vm.prank(nobody);
        vm.expectRevert(Campaign.NotCreator.selector);
        c.creatorWithdraw();
    }

    function test_Campaign_creatorWithdrawRevertWrongState() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle(); // Failed

        vm.prank(creator);
        vm.expectRevert(Campaign.WrongState.selector);
        c.creatorWithdraw();
    }

    function test_Campaign_creatorWithdrawRevertAlreadyWithdrawn() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 10.03 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle();

        vm.prank(creator);
        c.creatorWithdraw();

        vm.prank(creator);
        vm.expectRevert(Campaign.AlreadyWithdrawn.selector);
        c.creatorWithdraw();
    }

    // ─── Claim Refund ───────────────────────────────────────────────────

    function test_Campaign_claimRefundNetPlusInterest() public {
        Campaign c = _createCampaign();

        uint256 grossContribution = 2 ether;
        vm.prank(backer1);
        c.contribute{value: grossContribution}();

        vm.warp(block.timestamp + 8 days);
        c.settle();
        assertEq(uint256(c.state()), uint256(Campaign.State.Failed));

        uint256 netAmount = c.totalRaised();
        uint256 feePoolAmount = c.feePool();

        // Single backer gets all the feePool as interest
        // interest = (netAmount * feePool) / totalRaised = feePool (single backer)
        uint256 expectedPayout = netAmount + feePoolAmount;

        uint256 balBefore = backer1.balance;
        vm.prank(backer1);
        c.claimRefund();

        assertEq(backer1.balance, balBefore + expectedPayout);
    }

    function test_Campaign_claimRefundRevertWrongState() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 10.03 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle(); // Successful

        vm.prank(backer1);
        vm.expectRevert(Campaign.WrongState.selector);
        c.claimRefund();
    }

    function test_Campaign_claimRefundRevertNothingToClaim() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle(); // Failed

        vm.prank(nobody); // never contributed
        vm.expectRevert(Campaign.NothingToClaim.selector);
        c.claimRefund();
    }

    function test_Campaign_claimRefundRevertAlreadyClaimed() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle();

        vm.prank(backer1);
        c.claimRefund();

        vm.prank(backer1);
        vm.expectRevert(Campaign.AlreadyClaimed.selector);
        c.claimRefund();
    }

    // ─── Cancel ─────────────────────────────────────────────────────────

    function test_Campaign_cancelNoETHToReturn() public {
        Campaign c = _createCampaign();

        uint256 creatorBalBefore = creator.balance;
        vm.prank(creator);
        c.cancel();

        assertEq(uint256(c.state()), uint256(Campaign.State.Cancelled));
        // No ETH returned — creator balance unchanged
        assertEq(creator.balance, creatorBalBefore);
    }

    function test_Campaign_cancelRevertHasContributions() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 1 ether}();

        vm.prank(creator);
        vm.expectRevert(Campaign.HasContributions.selector);
        c.cancel();
    }

    function test_Campaign_cancelRevertNotCreator() public {
        Campaign c = _createCampaign();

        vm.prank(nobody);
        vm.expectRevert(Campaign.NotCreator.selector);
        c.cancel();
    }

    function test_Campaign_cancelRevertWrongState() public {
        Campaign c = _createCampaign();

        vm.prank(creator);
        c.cancel();

        // Try to cancel again
        vm.prank(creator);
        vm.expectRevert(Campaign.WrongState.selector);
        c.cancel();
    }

    // ─── View Functions ─────────────────────────────────────────────────

    function test_Campaign_getSummaryReturnsFeePool() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 4 ether}();

        (
            uint256 _campaignId,
            address _creator,
            uint256 _fundingGoal,
            uint256 _deadline,
            uint256 _minContribution,
            uint256 _feePool,
            uint256 _totalRaised,
            uint256 _backerCount,
            Campaign.State _state,
            string memory _metadataURI
        ) = c.getSummary();

        assertEq(_campaignId, 0);
        assertEq(_creator, creator);
        assertEq(_fundingGoal, GOAL);
        assertEq(_minContribution, MIN_CONTRIBUTION);
        assertEq(_feePool, _fee(4 ether));
        assertEq(_totalRaised, _net(4 ether));
        assertEq(_backerCount, 1);
        assertEq(uint256(_state), uint256(Campaign.State.Active));
        assertEq(keccak256(bytes(_metadataURI)), keccak256(bytes(METADATA)));
        assertTrue(_deadline > block.timestamp);
    }

    function test_Campaign_calculateRefund() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 2 ether}();
        vm.prank(backer2);
        c.contribute{value: 3 ether}();

        vm.warp(block.timestamp + 8 days);
        c.settle();

        (uint256 refund1, uint256 interest1) = c.calculateRefund(backer1);
        (uint256 refund2, uint256 interest2) = c.calculateRefund(backer2);

        assertEq(refund1, _net(2 ether));
        assertEq(refund2, _net(3 ether));

        uint256 totalFeePool = c.feePool();
        uint256 totalNet = c.totalRaised();

        assertEq(interest1, (_net(2 ether) * totalFeePool) / totalNet);
        assertEq(interest2, (_net(3 ether) * totalFeePool) / totalNet);
    }

    function test_Campaign_getFundingProgress() public {
        Campaign c = _createCampaign();

        vm.prank(backer1);
        c.contribute{value: 5 ether}();

        (uint256 raised, uint256 goal, uint256 pct) = c.getFundingProgress();
        assertEq(raised, _net(5 ether));
        assertEq(goal, GOAL);
        assertEq(pct, (_net(5 ether) * 100) / GOAL);
    }

    function test_Campaign_isActive() public {
        Campaign c = _createCampaign();
        assertTrue(c.isActive());

        vm.warp(block.timestamp + 8 days);
        assertFalse(c.isActive());
    }

    function test_Campaign_timeRemaining() public {
        Campaign c = _createCampaign();
        uint256 remaining = c.timeRemaining();
        assertTrue(remaining > 0 && remaining <= 7 days);

        vm.warp(block.timestamp + 8 days);
        assertEq(c.timeRemaining(), 0);
    }

    // ═════════════════════════════════════════════════════════════════════
    //  INTEGRATION TESTS
    // ═════════════════════════════════════════════════════════════════════

    function test_Integration_fullSuccessLifecycle() public {
        // Create campaign (no ETH needed)
        vm.prank(creator);
        (, address addr) = factory.createCampaign(
            GOAL, _deadline(), MIN_CONTRIBUTION, METADATA
        );
        Campaign c = Campaign(payable(addr));

        // Two backers contribute. Need net >= 10 ETH.
        // 5.02 ETH each → net ≈ 5.0074 each → total ≈ 10.0149 ≥ 10
        vm.prank(backer1);
        c.contribute{value: 5.02 ether}();
        vm.prank(backer2);
        c.contribute{value: 5.02 ether}();

        uint256 totalNet = c.totalRaised();
        uint256 totalFees = c.feePool();
        assertTrue(totalNet >= GOAL, "Should meet goal");

        // Verify fee math: total ETH in contract = totalNet + totalFees = sum of gross contributions
        assertEq(address(c).balance, totalNet + totalFees);
        assertEq(totalNet + totalFees, 10.04 ether);

        // Settle
        vm.warp(block.timestamp + 8 days);
        c.settle();
        assertEq(uint256(c.state()), uint256(Campaign.State.Successful));

        // Creator withdraw
        uint256 creatorBalBefore = creator.balance;
        uint256 treasuryBalBefore = address(treasury).balance;

        vm.prank(creator);
        c.creatorWithdraw();

        // Creator gets totalRaised (net), treasury gets feePool
        assertEq(creator.balance, creatorBalBefore + totalNet);
        assertEq(address(treasury).balance, treasuryBalBefore + totalFees);

        // Campaign contract should be empty
        assertEq(address(c).balance, 0);
    }

    function test_Integration_fullFailureLifecycleWithInterest() public {
        // Create campaign
        vm.prank(creator);
        (, address addr) = factory.createCampaign(
            GOAL, _deadline(), MIN_CONTRIBUTION, METADATA
        );
        Campaign c = Campaign(payable(addr));

        // Contribute below goal
        uint256 grossContribution = 3 ether;
        vm.prank(backer1);
        c.contribute{value: grossContribution}();

        uint256 netAmount = c.totalRaised();
        uint256 feePoolAmount = c.feePool();

        assertEq(netAmount, _net(grossContribution));
        assertEq(feePoolAmount, _fee(grossContribution));

        // Settle as failed
        vm.warp(block.timestamp + 8 days);
        c.settle();
        assertEq(uint256(c.state()), uint256(Campaign.State.Failed));

        // Claim refund: backer gets netContribution + proportional feePool (all of it, single backer)
        uint256 interest = (netAmount * feePoolAmount) / netAmount; // = feePoolAmount
        uint256 expectedPayout = netAmount + interest;

        uint256 balBefore = backer1.balance;
        vm.prank(backer1);
        c.claimRefund();

        assertEq(backer1.balance, balBefore + expectedPayout);
        // Backer gets back MORE than they put in (dominant assurance)
        assertTrue(expectedPayout > netAmount, "Payout should exceed net contribution");
    }

    function test_Integration_multipleBackersProportionalInterest() public {
        // Create campaign
        vm.prank(creator);
        (, address addr) = factory.createCampaign(
            GOAL, _deadline(), MIN_CONTRIBUTION, METADATA
        );
        Campaign c = Campaign(payable(addr));

        // backer1: 2 ETH gross, backer2: 3 ETH gross (total 5 ETH < 10 ETH goal)
        vm.prank(backer1);
        c.contribute{value: 2 ether}();
        vm.prank(backer2);
        c.contribute{value: 3 ether}();

        uint256 net1 = _net(2 ether);
        uint256 net2 = _net(3 ether);
        uint256 totalFeePool = c.feePool();
        uint256 totalNet = c.totalRaised();

        assertEq(totalNet, net1 + net2);
        assertEq(totalFeePool, _fee(2 ether) + _fee(3 ether));

        // Settle as failed
        vm.warp(block.timestamp + 8 days);
        c.settle();
        assertEq(uint256(c.state()), uint256(Campaign.State.Failed));

        // Interest is proportional to net contribution
        uint256 interest1 = (net1 * totalFeePool) / totalNet;
        uint256 interest2 = (net2 * totalFeePool) / totalNet;

        uint256 payout1 = net1 + interest1;
        uint256 payout2 = net2 + interest2;

        // Backer1 claims
        uint256 bal1Before = backer1.balance;
        vm.prank(backer1);
        c.claimRefund();
        assertEq(backer1.balance, bal1Before + payout1);

        // Backer2 claims
        uint256 bal2Before = backer2.balance;
        vm.prank(backer2);
        c.claimRefund();
        assertEq(backer2.balance, bal2Before + payout2);

        // Verify proportionality: interest1/interest2 ≈ net1/net2 = 2/3
        // Cross-multiply: interest1 * net2 == interest2 * net1
        assertEq(interest1 * net2, interest2 * net1, "Interest should be proportional to contribution");
    }

    function test_Integration_threeBackersFailureDistribution() public {
        vm.prank(creator);
        (, address addr) = factory.createCampaign(
            GOAL, _deadline(), MIN_CONTRIBUTION, METADATA
        );
        Campaign c = Campaign(payable(addr));

        // Three backers contribute different amounts
        vm.prank(backer1);
        c.contribute{value: 1 ether}();
        vm.prank(backer2);
        c.contribute{value: 2 ether}();
        vm.prank(backer3);
        c.contribute{value: 3 ether}();

        uint256 totalFeePool = c.feePool();
        uint256 totalNet = c.totalRaised();

        // Settle as failed
        vm.warp(block.timestamp + 8 days);
        c.settle();

        // All three claim
        uint256 bal1Before = backer1.balance;
        vm.prank(backer1);
        c.claimRefund();
        uint256 got1 = backer1.balance - bal1Before;

        uint256 bal2Before = backer2.balance;
        vm.prank(backer2);
        c.claimRefund();
        uint256 got2 = backer2.balance - bal2Before;

        uint256 bal3Before = backer3.balance;
        vm.prank(backer3);
        c.claimRefund();
        uint256 got3 = backer3.balance - bal3Before;

        // Each gets net + proportional interest
        assertEq(got1, _net(1 ether) + (_net(1 ether) * totalFeePool) / totalNet);
        assertEq(got2, _net(2 ether) + (_net(2 ether) * totalFeePool) / totalNet);
        assertEq(got3, _net(3 ether) + (_net(3 ether) * totalFeePool) / totalNet);

        // Each payout is greater than net contribution (dominant assurance)
        assertTrue(got1 > _net(1 ether));
        assertTrue(got2 > _net(2 ether));
        assertTrue(got3 > _net(3 ether));
    }

    function test_Integration_contributeMoreThenSuccess() public {
        vm.prank(creator);
        (, address addr) = factory.createCampaign(
            GOAL, _deadline(), MIN_CONTRIBUTION, METADATA
        );
        Campaign c = Campaign(payable(addr));

        // Backer contributes then tops up
        vm.prank(backer1);
        c.contribute{value: 5 ether}();
        vm.prank(backer1);
        c.contributeMore{value: 5.03 ether}();

        assertTrue(c.totalRaised() >= GOAL, "Should meet goal after top-up");

        vm.warp(block.timestamp + 8 days);
        c.settle();
        assertEq(uint256(c.state()), uint256(Campaign.State.Successful));

        // Verify fee pool accumulated from both contributions
        uint256 expectedFees = _fee(5 ether) + _fee(5.03 ether);
        assertEq(c.feePool(), expectedFees);

        // Creator can withdraw
        uint256 creatorBalBefore = creator.balance;
        vm.prank(creator);
        c.creatorWithdraw();
        assertEq(creator.balance, creatorBalBefore + c.totalRaised());
    }
}
