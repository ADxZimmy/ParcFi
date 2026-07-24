// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./BaseTest.sol";
import {IParcFiEscrow} from "../src/interfaces/IParcFiEscrow.sol";
import {ParcFiEscrow} from "../src/ParcFiEscrow.sol";

/// @notice Unit and negative-path coverage for every authorized and unauthorized
///         transition, funding boundaries, challenge/finalize deadline boundaries,
///         replay protection, expiry semantics, and pull-payment isolation.
contract ParcFiEscrowTest is BaseTest {
    // ------------------------------------------------------------ construction

    function test_Constructor_RevertsOnZeroToken() public {
        vm.expectRevert(IParcFiEscrow.ZeroAddress.selector);
        new ParcFiEscrow(address(0));
    }

    function test_Constructor_SetsUsdc() public view {
        assertEq(escrow.usdc(), address(usdc));
    }

    // ----------------------------------------------------------------- T1 create

    function test_Create_StoresAgreementAndObligations() public {
        uint256 id = _createGolden();
        assertEq(id, 0);
        assertEq(escrow.agreementCount(), 1);

        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        assertEq(a.payer, payer);
        assertEq(a.attestor, attestor);
        assertEq(a.resolver, resolver);
        assertEq(a.expiry, expiry);
        assertEq(a.obligationCount, 3);
        assertEq(a.requiredTotal, INVOICE_TOTAL);
        assertEq(a.fundedTotal, 0);
        assertEq(a.locked, 0);
        assertFalse(a.fullyFunded);

        IParcFiEscrow.Obligation memory o0 = escrow.getObligation(id, 0);
        assertEq(o0.beneficiary, carrier);
        assertEq(o0.amount, BASE_FREIGHT);
        assertEq(uint256(o0.status), uint256(IParcFiEscrow.ObligationStatus.Pending));
    }

    function test_Create_IncrementsIds() public {
        assertEq(_createGolden(), 0);
        assertEq(_createGolden(), 1);
        assertEq(escrow.agreementCount(), 2);
    }

    function test_Create_RevertsOnNoObligations() public {
        IParcFiEscrow.ObligationInput[] memory empty = new IParcFiEscrow.ObligationInput[](0);
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.NoObligations.selector);
        escrow.createAgreement(bytes32("x"), attestor, resolver, expiry, empty);
    }

    function test_Create_RevertsOnTooManyObligations() public {
        IParcFiEscrow.ObligationInput[] memory many = new IParcFiEscrow.ObligationInput[](17);
        for (uint256 i = 0; i < 17; ++i) {
            many[i] = IParcFiEscrow.ObligationInput(carrier, 1e6, EV_POD, CHALLENGE);
        }
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.TooManyObligations.selector);
        escrow.createAgreement(bytes32("x"), attestor, resolver, expiry, many);
    }

    function test_Create_AllowsExactlyMaxObligations() public {
        IParcFiEscrow.ObligationInput[] memory many = new IParcFiEscrow.ObligationInput[](16);
        for (uint256 i = 0; i < 16; ++i) {
            many[i] = IParcFiEscrow.ObligationInput(carrier, 1e6, EV_POD, CHALLENGE);
        }
        vm.prank(payer);
        uint256 id = escrow.createAgreement(bytes32("x"), attestor, resolver, expiry, many);
        assertEq(escrow.getAgreement(id).obligationCount, 16);
    }

    function test_Create_RevertsOnZeroAttestor() public {
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.ZeroAddress.selector);
        escrow.createAgreement(bytes32("x"), address(0), resolver, expiry, _threeLineInputs());
    }

    function test_Create_RevertsOnZeroResolver() public {
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.ZeroAddress.selector);
        escrow.createAgreement(bytes32("x"), attestor, address(0), expiry, _threeLineInputs());
    }

    function test_Create_RevertsOnZeroBeneficiary() public {
        IParcFiEscrow.ObligationInput[] memory obs = _threeLineInputs();
        obs[1].beneficiary = address(0);
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.ZeroAddress.selector);
        escrow.createAgreement(bytes32("x"), attestor, resolver, expiry, obs);
    }

    function test_Create_RevertsOnZeroAmount() public {
        IParcFiEscrow.ObligationInput[] memory obs = _threeLineInputs();
        obs[2].amount = 0;
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.ZeroAmount.selector);
        escrow.createAgreement(bytes32("x"), attestor, resolver, expiry, obs);
    }

    function test_Create_RevertsOnExpiryNotInFuture() public {
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.ExpiryNotInFuture.selector);
        escrow.createAgreement(bytes32("x"), attestor, resolver, uint64(block.timestamp), _threeLineInputs());
    }

    function test_Create_RevertsOnChallengeDurationTooShort() public {
        IParcFiEscrow.ObligationInput[] memory obs = _threeLineInputs();
        obs[0].challengeDuration = 0;
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.DurationOutOfBounds.selector);
        escrow.createAgreement(bytes32("x"), attestor, resolver, expiry, obs);
    }

    function test_Create_RevertsOnChallengeDurationTooLong() public {
        IParcFiEscrow.ObligationInput[] memory obs = _threeLineInputs();
        obs[0].challengeDuration = uint64(30 days) + 1;
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.DurationOutOfBounds.selector);
        escrow.createAgreement(bytes32("x"), attestor, resolver, expiry, obs);
    }

    // ------------------------------------------------------------------- T2 fund

    function test_Fund_Partial_DoesNotLatch() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        escrow.fund(id, BASE_FREIGHT);

        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        assertEq(a.fundedTotal, BASE_FREIGHT);
        assertFalse(a.fullyFunded);
        assertEq(a.locked, 0);
        assertEq(usdc.balanceOf(address(escrow)), BASE_FREIGHT);
    }

    function test_Fund_Incremental_ReachesFull() public {
        uint256 id = _createGolden();
        vm.startPrank(payer);
        escrow.fund(id, BASE_FREIGHT);
        escrow.fund(id, PORT_HANDLING);
        escrow.fund(id, DEMURRAGE);
        vm.stopPrank();

        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        assertTrue(a.fullyFunded);
        assertEq(a.fundedTotal, INVOICE_TOTAL);
        assertEq(a.locked, INVOICE_TOTAL);
    }

    function test_Fund_ExactLatchesFullyFunded() public {
        uint256 id = _createGolden();
        vm.expectEmit(true, false, false, false);
        emit IParcFiEscrow.FullyFunded(id);
        _fundFully(id);
        assertTrue(escrow.getAgreement(id).fullyFunded);
    }

    function test_Fund_RevertsOnOverFunding() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.OverFunding.selector);
        escrow.fund(id, INVOICE_TOTAL + 1);
    }

    function test_Fund_RevertsOnIncrementalOverFunding() public {
        uint256 id = _createGolden();
        vm.startPrank(payer);
        escrow.fund(id, INVOICE_TOTAL - 1);
        vm.expectRevert(IParcFiEscrow.OverFunding.selector);
        escrow.fund(id, 2);
        vm.stopPrank();
    }

    function test_Fund_RevertsWhenAlreadyFullyFunded() public {
        uint256 id = _createAndFund();
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.AlreadyFullyFunded.selector);
        escrow.fund(id, 1);
    }

    function test_Fund_RevertsOnZeroAmount() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.ZeroAmount.selector);
        escrow.fund(id, 0);
    }

    function test_Fund_RevertsWhenNotPayer() public {
        uint256 id = _createGolden();
        usdc.mint(outsider, INVOICE_TOTAL);
        vm.startPrank(outsider);
        usdc.approve(address(escrow), type(uint256).max);
        vm.expectRevert(IParcFiEscrow.NotPayer.selector);
        escrow.fund(id, INVOICE_TOTAL);
        vm.stopPrank();
    }

    function test_Fund_RevertsOnUnknownAgreement() public {
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.UnknownAgreement.selector);
        escrow.fund(99, 1);
    }

    // ----------------------------------------------------------------- T3 attest

    function test_Attest_OpensChallengeWindow() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);

        IParcFiEscrow.Obligation memory o = escrow.getObligation(id, 0);
        assertEq(uint256(o.status), uint256(IParcFiEscrow.ObligationStatus.Attested));
        assertEq(o.attestedAt, uint64(block.timestamp));
        assertEq(o.challengeDeadline, uint64(block.timestamp) + CHALLENGE);
        assertTrue(o.evidenceHash != bytes32(0));
    }

    function test_Attest_RevertsWhenNotAttestor() public {
        uint256 id = _createAndFund();
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.NotAttestor.selector);
        escrow.attest(id, 0, keccak256("e"), EV_POD);
    }

    function test_Attest_RevertsWhenNotFullyFunded() public {
        uint256 id = _createGolden();
        vm.prank(attestor);
        vm.expectRevert(IParcFiEscrow.NotFullyFunded.selector);
        escrow.attest(id, 0, keccak256("e"), EV_POD);
    }

    function test_Attest_RevertsAfterExpiry() public {
        uint256 id = _createAndFund();
        vm.warp(expiry);
        vm.prank(attestor);
        vm.expectRevert(IParcFiEscrow.Expired.selector);
        escrow.attest(id, 0, keccak256("e"), EV_POD);
    }

    function test_Attest_RevertsOnZeroHash() public {
        uint256 id = _createAndFund();
        vm.prank(attestor);
        vm.expectRevert(IParcFiEscrow.ZeroEvidenceHash.selector);
        escrow.attest(id, 0, bytes32(0), EV_POD);
    }

    function test_Attest_RevertsOnEvidenceTypeMismatch() public {
        uint256 id = _createAndFund();
        vm.prank(attestor);
        vm.expectRevert(IParcFiEscrow.EvidenceTypeMismatch.selector);
        escrow.attest(id, 0, keccak256("e"), EV_PORT); // wrong type for obligation 0
    }

    function test_Attest_RevertsOnReplay() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);
        vm.prank(attestor);
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.attest(id, 0, keccak256("different"), EV_POD);
    }

    function test_Attest_RevertsOnUnknownObligation() public {
        uint256 id = _createAndFund();
        vm.prank(attestor);
        vm.expectRevert(IParcFiEscrow.UnknownObligation.selector);
        escrow.attest(id, 3, keccak256("e"), EV_POD);
    }

    // -------------------------------------------------------------- T4 challenge

    function test_Challenge_MarksChallenged() public {
        uint256 id = _createAndFund();
        _attest(id, 2, EV_DEM);
        vm.prank(payer);
        escrow.challenge(id, 2);
        assertEq(uint256(_status(id, 2)), uint256(IParcFiEscrow.ObligationStatus.Challenged));
    }

    function test_Challenge_RevertsWhenNotPayer() public {
        uint256 id = _createAndFund();
        _attest(id, 2, EV_DEM);
        vm.prank(outsider);
        vm.expectRevert(IParcFiEscrow.NotPayer.selector);
        escrow.challenge(id, 2);
    }

    function test_Challenge_RevertsWhenNotAttested() public {
        uint256 id = _createAndFund();
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.challenge(id, 2);
    }

    function test_Challenge_SucceedsOneSecondBeforeDeadline() public {
        uint256 id = _createAndFund();
        _attest(id, 2, EV_DEM);
        uint64 deadline = escrow.getObligation(id, 2).challengeDeadline;
        vm.warp(deadline - 1);
        vm.prank(payer);
        escrow.challenge(id, 2);
        assertEq(uint256(_status(id, 2)), uint256(IParcFiEscrow.ObligationStatus.Challenged));
    }

    function test_Challenge_RevertsAtDeadline() public {
        uint256 id = _createAndFund();
        _attest(id, 2, EV_DEM);
        uint64 deadline = escrow.getObligation(id, 2).challengeDeadline;
        vm.warp(deadline);
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.ChallengeWindowClosed.selector);
        escrow.challenge(id, 2);
    }

    // --------------------------------------------------------------- T5 finalize

    function test_Finalize_CreditsClaimableAndIsPermissionless() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);
        uint64 deadline = escrow.getObligation(id, 0).challengeDeadline;
        vm.warp(deadline);

        vm.prank(outsider); // anyone can finalize
        escrow.finalizeObligation(id, 0);

        assertEq(uint256(_status(id, 0)), uint256(IParcFiEscrow.ObligationStatus.Finalized));
        assertEq(escrow.claimableOf(id, carrier), BASE_FREIGHT);
        assertEq(escrow.getAgreement(id).locked, INVOICE_TOTAL - BASE_FREIGHT);
    }

    function test_Finalize_RevertsBeforeDeadline() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);
        uint64 deadline = escrow.getObligation(id, 0).challengeDeadline;
        vm.warp(deadline - 1);
        vm.expectRevert(IParcFiEscrow.ChallengeWindowOpen.selector);
        escrow.finalizeObligation(id, 0);
    }

    function test_Finalize_RevertsWhenChallenged() public {
        uint256 id = _createAndFund();
        _attest(id, 2, EV_DEM);
        vm.prank(payer);
        escrow.challenge(id, 2);
        vm.warp(escrow.getObligation(id, 2).challengeDeadline);
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.finalizeObligation(id, 2);
    }

    function test_Finalize_RevertsWhenNotAttested() public {
        uint256 id = _createAndFund();
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.finalizeObligation(id, 0);
    }

    // ------------------------------------------------------------------ T9 claim

    function test_Claim_TransfersAndZeroesBalance() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);
        vm.warp(escrow.getObligation(id, 0).challengeDeadline);
        escrow.finalizeObligation(id, 0);

        vm.prank(carrier);
        escrow.claim(id);

        assertEq(usdc.balanceOf(carrier), BASE_FREIGHT);
        assertEq(escrow.claimableOf(id, carrier), 0);
        assertEq(escrow.getAgreement(id).cumulativeClaimed, BASE_FREIGHT);
    }

    function test_Claim_RevertsWhenNothingToWithdraw() public {
        uint256 id = _createAndFund();
        vm.prank(carrier);
        vm.expectRevert(IParcFiEscrow.NothingToWithdraw.selector);
        escrow.claim(id);
    }

    function test_Claim_CannotDoubleClaim() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);
        vm.warp(escrow.getObligation(id, 0).challengeDeadline);
        escrow.finalizeObligation(id, 0);

        vm.startPrank(carrier);
        escrow.claim(id);
        vm.expectRevert(IParcFiEscrow.NothingToWithdraw.selector);
        escrow.claim(id);
        vm.stopPrank();
    }

    /// @notice F-07: a blocked beneficiary strands only its own claim.
    function test_Claim_BlockedBeneficiaryDoesNotBlockSibling() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);
        _attest(id, 1, EV_PORT);
        vm.warp(escrow.getObligation(id, 0).challengeDeadline);
        escrow.finalizeObligation(id, 0);
        escrow.finalizeObligation(id, 1);

        usdc.setBlocked(carrier, true);

        // carrier's own claim fails while blocked...
        vm.prank(carrier);
        vm.expectRevert(bytes("USDC: blocked"));
        escrow.claim(id);

        // ...but the terminal claims unaffected.
        vm.prank(terminal);
        escrow.claim(id);
        assertEq(usdc.balanceOf(terminal), PORT_HANDLING);

        // and once unblocked the carrier still recovers its full entitlement.
        usdc.setBlocked(carrier, false);
        vm.prank(carrier);
        escrow.claim(id);
        assertEq(usdc.balanceOf(carrier), BASE_FREIGHT);
    }

    // ---------------------------------------------------------------- T6 resolve

    function _challengeDemurrage(uint256 id) internal {
        _attest(id, 2, EV_DEM);
        vm.prank(payer);
        escrow.challenge(id, 2);
    }

    function test_Resolve_SplitsSixtyForty() public {
        uint256 id = _createAndFund();
        _challengeDemurrage(id);

        vm.prank(resolver);
        escrow.resolve(id, 2, 600e6);

        assertEq(uint256(_status(id, 2)), uint256(IParcFiEscrow.ObligationStatus.Resolved));
        assertEq(escrow.claimableOf(id, forwarder), 600e6);
        assertEq(escrow.refundableOf(id, payer), 400e6);
        assertEq(escrow.getAgreement(id).locked, INVOICE_TOTAL - DEMURRAGE);
    }

    function test_Resolve_FullToBeneficiary() public {
        uint256 id = _createAndFund();
        _challengeDemurrage(id);
        vm.prank(resolver);
        escrow.resolve(id, 2, DEMURRAGE);
        assertEq(escrow.claimableOf(id, forwarder), DEMURRAGE);
        assertEq(escrow.refundableOf(id, payer), 0);
    }

    function test_Resolve_FullRefundToPayer() public {
        uint256 id = _createAndFund();
        _challengeDemurrage(id);
        vm.prank(resolver);
        escrow.resolve(id, 2, 0);
        assertEq(escrow.claimableOf(id, forwarder), 0);
        assertEq(escrow.refundableOf(id, payer), DEMURRAGE);
    }

    function test_Resolve_RevertsWhenNotResolver() public {
        uint256 id = _createAndFund();
        _challengeDemurrage(id);
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.NotResolver.selector);
        escrow.resolve(id, 2, 600e6);
    }

    function test_Resolve_RevertsWhenNotChallenged() public {
        uint256 id = _createAndFund();
        _attest(id, 2, EV_DEM);
        vm.prank(resolver);
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.resolve(id, 2, 600e6);
    }

    function test_Resolve_RevertsWhenSplitExceedsAmount() public {
        uint256 id = _createAndFund();
        _challengeDemurrage(id);
        vm.prank(resolver);
        vm.expectRevert(IParcFiEscrow.SplitExceedsAmount.selector);
        escrow.resolve(id, 2, DEMURRAGE + 1);
    }

    // ----------------------------------------------------------------- T7 expire

    function test_Expire_RefundsPendingAfterExpiry() public {
        uint256 id = _createAndFund();
        vm.warp(expiry);
        vm.prank(outsider); // permissionless
        escrow.expireObligation(id, 0);

        assertEq(uint256(_status(id, 0)), uint256(IParcFiEscrow.ObligationStatus.Expired));
        assertEq(escrow.refundableOf(id, payer), BASE_FREIGHT);
        assertEq(escrow.getAgreement(id).locked, INVOICE_TOTAL - BASE_FREIGHT);
    }

    function test_Expire_RevertsBeforeExpiry() public {
        uint256 id = _createAndFund();
        vm.expectRevert(IParcFiEscrow.NotYetExpired.selector);
        escrow.expireObligation(id, 0);
    }

    function test_Expire_RevertsWhenNotFullyFunded() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        escrow.fund(id, BASE_FREIGHT); // partial
        vm.warp(expiry);
        vm.expectRevert(IParcFiEscrow.NotFullyFunded.selector);
        escrow.expireObligation(id, 0);
    }

    function test_Expire_RevertsWhenNotPending() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);
        vm.warp(expiry);
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.expireObligation(id, 0);
    }

    /// @notice Expiry gates the START of a lifecycle; an already-attested obligation
    ///         still finalizes normally after expiry (F-09 no silent voiding).
    function test_Expire_AttestedObligationStillFinalizesAfterExpiry() public {
        uint256 id = _createAndFund();
        _attest(id, 0, EV_POD);
        vm.warp(expiry + 1);

        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.expireObligation(id, 0); // cannot be expired — it is Attested

        escrow.finalizeObligation(id, 0); // but finalizes fine
        assertEq(escrow.claimableOf(id, carrier), BASE_FREIGHT);
    }

    // -------------------------------------------------------- T8 reclaim unfunded

    function test_Reclaim_RefundsPartialFundingAfterExpiry() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        escrow.fund(id, BASE_FREIGHT); // partial
        uint256 balBefore = usdc.balanceOf(payer);

        vm.warp(expiry);
        vm.prank(payer);
        escrow.reclaimUnfunded(id);

        assertEq(usdc.balanceOf(payer), balBefore + BASE_FREIGHT);
        assertEq(uint256(_status(id, 0)), uint256(IParcFiEscrow.ObligationStatus.Expired));
        assertEq(uint256(_status(id, 2)), uint256(IParcFiEscrow.ObligationStatus.Expired));
        assertEq(escrow.getAgreement(id).cumulativeRefunded, BASE_FREIGHT);
    }

    function test_Reclaim_RevertsBeforeExpiry() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        escrow.fund(id, BASE_FREIGHT);
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.NotYetExpired.selector);
        escrow.reclaimUnfunded(id);
    }

    function test_Reclaim_RevertsWhenFullyFunded() public {
        uint256 id = _createAndFund();
        vm.warp(expiry);
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.AlreadyFullyFunded.selector);
        escrow.reclaimUnfunded(id);
    }

    function test_Reclaim_RevertsWhenNotPayer() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        escrow.fund(id, BASE_FREIGHT);
        vm.warp(expiry);
        vm.prank(outsider);
        vm.expectRevert(IParcFiEscrow.NotPayer.selector);
        escrow.reclaimUnfunded(id);
    }

    function test_Reclaim_RevertsWhenNothingFunded() public {
        uint256 id = _createGolden();
        vm.warp(expiry);
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.NothingToWithdraw.selector);
        escrow.reclaimUnfunded(id);
    }

    /// @notice G1-F1 regression: a reclaimed agreement must never accept deposits again.
    ///         Without the guard, fund() could latch fullyFunded against terminally
    ///         Expired obligations and strand the new deposit forever.
    function test_Fund_RevertsAfterReclaim() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        escrow.fund(id, BASE_FREIGHT); // partial: 7,500 of 10,000
        vm.warp(expiry);
        vm.prank(payer);
        escrow.reclaimUnfunded(id);

        // Topping up to the exact required total must revert...
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.fund(id, PORT_HANDLING + DEMURRAGE);

        // ...as must any other deposit.
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.fund(id, 1);

        // The agreement stays in its reclaimed terminal shape: nothing latched,
        // nothing locked, conservation intact, no value inside the contract.
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        assertFalse(a.fullyFunded);
        assertEq(a.locked, 0);
        assertEq(a.cumulativeRefunded, BASE_FREIGHT);
        assertEq(usdc.balanceOf(address(escrow)), 0);
    }

    function test_Reclaim_CannotBeCalledTwice() public {
        uint256 id = _createGolden();
        vm.prank(payer);
        escrow.fund(id, BASE_FREIGHT);
        vm.warp(expiry);
        vm.startPrank(payer);
        escrow.reclaimUnfunded(id);
        vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
        escrow.reclaimUnfunded(id);
        vm.stopPrank();
    }

    // ------------------------------------------------------- T10 withdraw refund

    function test_WithdrawRefund_TransfersResolvedShare() public {
        uint256 id = _createAndFund();
        _challengeDemurrage(id);
        vm.prank(resolver);
        escrow.resolve(id, 2, 600e6);

        uint256 balBefore = usdc.balanceOf(payer);
        vm.prank(payer);
        escrow.withdrawRefund(id);

        assertEq(usdc.balanceOf(payer), balBefore + 400e6);
        assertEq(escrow.refundableOf(id, payer), 0);
        assertEq(escrow.getAgreement(id).cumulativeRefunded, 400e6);
    }

    function test_WithdrawRefund_RevertsWhenNothing() public {
        uint256 id = _createAndFund();
        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.NothingToWithdraw.selector);
        escrow.withdrawRefund(id);
    }

    // ---------------------------------------------------- isolation & accounting

    /// @notice F-06: a disputed line never blocks finalizing an unrelated line.
    function test_DisputedLineDoesNotBlockSiblingFinalization() public {
        uint256 id = _createAndFund();
        _attestAll(id);
        vm.prank(payer);
        escrow.challenge(id, 2); // dispute demurrage only

        vm.warp(escrow.getObligation(id, 0).challengeDeadline);
        escrow.finalizeObligation(id, 0);
        escrow.finalizeObligation(id, 1);

        assertEq(escrow.claimableOf(id, carrier), BASE_FREIGHT);
        assertEq(escrow.claimableOf(id, terminal), PORT_HANDLING);
        assertEq(uint256(_status(id, 2)), uint256(IParcFiEscrow.ObligationStatus.Challenged));
        _assertConservationAndSolvency(id);
    }
}
