// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ParcFiEscrow} from "../src/ParcFiEscrow.sol";
import {IParcFiEscrow} from "../src/interfaces/IParcFiEscrow.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @notice Shared fixtures for the ParcFiEscrow suites: actors, the synthetic
///         three-line invoice, and helpers to create/fund/attest.
abstract contract BaseTest is Test {
    ParcFiEscrow internal escrow;
    MockUSDC internal usdc;

    address internal payer;
    address internal attestor;
    address internal resolver;
    address internal carrier;
    address internal terminal;
    address internal forwarder;
    address internal outsider;

    uint256 internal constant BASE_FREIGHT = 7_500e6;
    uint256 internal constant PORT_HANDLING = 1_500e6;
    uint256 internal constant DEMURRAGE = 1_000e6;
    uint256 internal constant INVOICE_TOTAL = 10_000e6;

    bytes32 internal constant EV_POD = bytes32("SIGNED_POD");
    bytes32 internal constant EV_PORT = bytes32("PORT_RECEIPT");
    bytes32 internal constant EV_DEM = bytes32("DEMURRAGE_STATEMENT");

    uint64 internal constant CHALLENGE = 120;
    uint64 internal expiry;

    function setUp() public virtual {
        vm.warp(1_700_000_000);

        payer = makeAddr("payer");
        attestor = makeAddr("attestor");
        resolver = makeAddr("resolver");
        carrier = makeAddr("carrier");
        terminal = makeAddr("terminal");
        forwarder = makeAddr("forwarder");
        outsider = makeAddr("outsider");

        usdc = new MockUSDC();
        escrow = new ParcFiEscrow(address(usdc));
        expiry = uint64(block.timestamp + 30 days);

        usdc.mint(payer, 1_000_000e6);
        vm.prank(payer);
        usdc.approve(address(escrow), type(uint256).max);
    }

    function _threeLineInputs() internal view returns (IParcFiEscrow.ObligationInput[] memory obs) {
        obs = new IParcFiEscrow.ObligationInput[](3);
        obs[0] = IParcFiEscrow.ObligationInput(carrier, BASE_FREIGHT, EV_POD, CHALLENGE);
        obs[1] = IParcFiEscrow.ObligationInput(terminal, PORT_HANDLING, EV_PORT, CHALLENGE);
        obs[2] = IParcFiEscrow.ObligationInput(forwarder, DEMURRAGE, EV_DEM, CHALLENGE);
    }

    function _createGolden() internal returns (uint256 id) {
        vm.prank(payer);
        id = escrow.createAgreement(bytes32("INV-0001"), attestor, resolver, expiry, _threeLineInputs());
    }

    function _fundFully(uint256 id) internal {
        vm.prank(payer);
        escrow.fund(id, INVOICE_TOTAL);
    }

    function _createAndFund() internal returns (uint256 id) {
        id = _createGolden();
        _fundFully(id);
    }

    function _attest(uint256 id, uint256 oid, bytes32 evType) internal {
        vm.prank(attestor);
        escrow.attest(id, oid, keccak256(abi.encodePacked("evidence", oid)), evType);
    }

    function _attestAll(uint256 id) internal {
        _attest(id, 0, EV_POD);
        _attest(id, 1, EV_PORT);
        _attest(id, 2, EV_DEM);
    }

    function _status(uint256 id, uint256 oid) internal view returns (IParcFiEscrow.ObligationStatus) {
        return escrow.getObligation(id, oid).status;
    }

    /// @notice Targeted conservation + solvency check over the known actor set.
    ///         (The unbounded-actor invariant suite is the Phase 002 step-9 / G1 work.)
    function _assertConservationAndSolvency(uint256 id) internal view {
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        uint256 sumClaimable = escrow.claimableOf(id, carrier) + escrow.claimableOf(id, terminal)
            + escrow.claimableOf(id, forwarder) + escrow.claimableOf(id, outsider);
        uint256 sumRefundable = escrow.refundableOf(id, payer);

        if (a.fullyFunded) {
            assertEq(
                a.fundedTotal,
                a.locked + sumClaimable + sumRefundable + a.cumulativeClaimed + a.cumulativeRefunded,
                "INV-1 conservation"
            );
        }
        assertGe(
            usdc.balanceOf(address(escrow)),
            a.fundedTotal - a.cumulativeClaimed - a.cumulativeRefunded,
            "INV-2 solvency"
        );
    }
}
