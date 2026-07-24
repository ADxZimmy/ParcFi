// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./BaseTest.sol";
import {IParcFiEscrow} from "../src/interfaces/IParcFiEscrow.sol";

/// @title Golden-path scenario (Phase 002 implementation of the Phase 001 scaffold)
/// @notice Synthetic $10,000 freight invoice, three obligations:
///   #0 Base ocean freight  $7,500 -> carrier    (SIGNED_POD)
///   #1 Port handling       $1,500 -> terminal   (PORT_RECEIPT)
///   #2 Demurrage           $1,000 -> forwarder  (DEMURRAGE_STATEMENT)
/// The payer funds 10,000 USDC, all three are attested, the payer challenges only
/// demurrage, base freight and port handling finalize and are claimed independently,
/// and the resolver splits demurrage 60/40 (600 to forwarder, 400 refunded to payer).
contract GoldenPathTest is BaseTest {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _createGolden();
    }

    function test_GoldenPath_EndToEnd() public {
        // 1. Payer funds the exact invoice total.
        _fundFully(id);
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        assertTrue(a.fullyFunded);
        assertEq(a.locked, INVOICE_TOTAL);

        // 2. Attestor submits typed evidence for all three lines; windows open.
        _attestAll(id);
        assertEq(uint256(_status(id, 0)), uint256(IParcFiEscrow.ObligationStatus.Attested));

        // 3. Payer challenges ONLY demurrage.
        vm.prank(payer);
        escrow.challenge(id, 2);
        assertEq(uint256(_status(id, 2)), uint256(IParcFiEscrow.ObligationStatus.Challenged));

        // 4. After the window, base freight and port handling finalize independently.
        vm.warp(escrow.getObligation(id, 0).challengeDeadline);
        escrow.finalizeObligation(id, 0);
        escrow.finalizeObligation(id, 1);

        // The carrier and terminal each pull their own funds, in either order.
        vm.prank(terminal);
        escrow.claim(id);
        vm.prank(carrier);
        escrow.claim(id);
        assertEq(usdc.balanceOf(carrier), BASE_FREIGHT);
        assertEq(usdc.balanceOf(terminal), PORT_HANDLING);

        // Demurrage is still quarantined; the disputed line blocked no one.
        assertEq(uint256(_status(id, 2)), uint256(IParcFiEscrow.ObligationStatus.Challenged));

        // 5. The resolver splits demurrage 60/40.
        vm.prank(resolver);
        escrow.resolve(id, 2, 600e6);

        vm.prank(forwarder);
        escrow.claim(id);
        vm.prank(payer);
        escrow.withdrawRefund(id);

        assertEq(usdc.balanceOf(forwarder), 600e6);

        // Final accounting: everything conserved, nothing left locked, contract drained.
        a = escrow.getAgreement(id);
        assertEq(a.locked, 0);
        assertEq(a.cumulativeClaimed, BASE_FREIGHT + PORT_HANDLING + 600e6);
        assertEq(a.cumulativeRefunded, 400e6);
        assertEq(a.cumulativeClaimed + a.cumulativeRefunded, INVOICE_TOTAL);
        assertEq(usdc.balanceOf(address(escrow)), 0);
        _assertConservationAndSolvency(id);
    }

    function test_GoldenPath_ClaimsAreIndependentAndOrderInsensitive() public {
        _fundFully(id);
        _attestAll(id);
        vm.warp(escrow.getObligation(id, 0).challengeDeadline);
        escrow.finalizeObligation(id, 0);
        escrow.finalizeObligation(id, 1);

        // Carrier claims; terminal's entitlement is untouched and still fully claimable.
        vm.prank(carrier);
        escrow.claim(id);
        assertEq(usdc.balanceOf(carrier), BASE_FREIGHT);
        assertEq(escrow.claimableOf(id, terminal), PORT_HANDLING);

        vm.prank(terminal);
        escrow.claim(id);
        assertEq(usdc.balanceOf(terminal), PORT_HANDLING);
    }
}
