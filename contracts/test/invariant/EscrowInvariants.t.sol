// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ParcFiEscrow} from "../../src/ParcFiEscrow.sol";
import {IParcFiEscrow} from "../../src/interfaces/IParcFiEscrow.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

/// @title EscrowHandler — bounded, non-reverting action driver for invariant runs
/// @notice Exposes every T1–T10 transition as a fuzzed action over pools of payers and
///         beneficiaries, mirroring the contract's preconditions exactly so that any
///         unexpected revert is a real finding (the suite runs fail-on-revert). Ghost
///         variables track every unit of value that crossed the contract boundary and
///         every terminal status ever observed.
contract EscrowHandler is Test {
    ParcFiEscrow public immutable escrow;
    MockUSDC public immutable usdc;

    address public immutable attestor;
    address public immutable resolver;
    address[] internal _payers;
    address[] internal _beneficiaries;
    address[] internal _actors; // payers ++ beneficiaries: every address that can hold a ledger balance
    uint256[] internal _ids;

    uint256 public ghost_totalFunded; // Σ successful fund() amounts
    uint256 public ghost_totalClaimed; // Σ successful claim() transfers
    uint256 public ghost_totalRefunded; // Σ successful withdrawRefund() + reclaimUnfunded() transfers
    mapping(uint256 => bool) public ghost_reclaimed;
    mapping(uint256 => mapping(uint256 => bool)) public ghost_sawTerminal;
    mapping(uint256 => mapping(uint256 => IParcFiEscrow.ObligationStatus)) public ghost_terminalStatus;
    mapping(uint256 => uint256) internal _lastCumClaimed;
    mapping(uint256 => uint256) internal _lastCumRefunded;

    uint256 internal constant MAX_AMOUNT = 1e12; // $1M in 6-decimal units per line

    constructor(ParcFiEscrow escrow_, MockUSDC usdc_) {
        escrow = escrow_;
        usdc = usdc_;
        attestor = makeAddr("h_attestor");
        resolver = makeAddr("h_resolver");
        for (uint256 i = 0; i < 4; ++i) {
            address p = makeAddr(string.concat("h_payer", vm.toString(i)));
            _payers.push(p);
            _actors.push(p);
            usdc.mint(p, 1e24);
            vm.prank(p);
            usdc.approve(address(escrow), type(uint256).max);
        }
        for (uint256 i = 0; i < 6; ++i) {
            address b = makeAddr(string.concat("h_ben", vm.toString(i)));
            _beneficiaries.push(b);
            _actors.push(b);
        }
    }

    // ------------------------------------------------------------------ views

    function idCount() external view returns (uint256) {
        return _ids.length;
    }

    function idAt(uint256 i) external view returns (uint256) {
        return _ids[i];
    }

    function actorCount() external view returns (uint256) {
        return _actors.length;
    }

    function actorAt(uint256 i) external view returns (address) {
        return _actors[i];
    }

    // ---------------------------------------------------------------- actions

    function createAgreement(uint256 payerSeed, uint256 nSeed, uint256 amountSeed, uint256 durSeed, uint256 expirySeed)
        external
    {
        address payer = _payers[bound(payerSeed, 0, _payers.length - 1)];
        uint256 n = bound(nSeed, 1, 4);
        IParcFiEscrow.ObligationInput[] memory obs = new IParcFiEscrow.ObligationInput[](n);
        for (uint256 i = 0; i < n; ++i) {
            obs[i] = IParcFiEscrow.ObligationInput({
                beneficiary: _beneficiaries[bound(
                        uint256(keccak256(abi.encode(payerSeed, nSeed, i))), 0, _beneficiaries.length - 1
                    )],
                amount: bound(uint256(keccak256(abi.encode(amountSeed, i))), 1, MAX_AMOUNT),
                requiredEvidenceType: bytes32("EV"),
                challengeDuration: uint64(bound(uint256(keccak256(abi.encode(durSeed, i))), 1, 7 days))
            });
        }
        uint64 expiry = uint64(block.timestamp + bound(expirySeed, 1 hours, 30 days));
        vm.prank(payer);
        uint256 id = escrow.createAgreement(bytes32("DOC"), attestor, resolver, expiry, obs);
        _ids.push(id);
        _after(id);
    }

    function fund(uint256 idSeed, uint256 amtSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        if (a.fullyFunded) return;
        if (ghost_reclaimed[id]) {
            // G1-F1 probe: a reclaimed agreement MUST reject deposits. If the contract
            // ever accepts one here, expectRevert fails and the invariant run fails.
            vm.prank(a.payer);
            vm.expectRevert(IParcFiEscrow.InvalidStatus.selector);
            escrow.fund(id, 1);
            return;
        }
        uint256 remaining = a.requiredTotal - a.fundedTotal;
        uint256 amount = amtSeed % 4 == 0 ? remaining : bound(amtSeed, 1, remaining);
        vm.prank(a.payer);
        escrow.fund(id, amount);
        ghost_totalFunded += amount;
        _after(id);
    }

    function attest(uint256 idSeed, uint256 oidSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        if (!a.fullyFunded || block.timestamp >= a.expiry) return;
        uint256 oid = bound(oidSeed, 0, a.obligationCount - 1);
        IParcFiEscrow.Obligation memory o = escrow.getObligation(id, oid);
        if (o.status != IParcFiEscrow.ObligationStatus.Pending) return;
        vm.prank(attestor);
        escrow.attest(id, oid, keccak256(abi.encode(id, oid, block.timestamp)), o.requiredEvidenceType);
        _after(id);
    }

    function challenge(uint256 idSeed, uint256 oidSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        uint256 oid = bound(oidSeed, 0, a.obligationCount - 1);
        IParcFiEscrow.Obligation memory o = escrow.getObligation(id, oid);
        if (o.status != IParcFiEscrow.ObligationStatus.Attested || block.timestamp >= o.challengeDeadline) return;
        vm.prank(a.payer);
        escrow.challenge(id, oid);
        _after(id);
    }

    function finalizeObligation(uint256 idSeed, uint256 oidSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        uint256 oid = bound(oidSeed, 0, a.obligationCount - 1);
        IParcFiEscrow.Obligation memory o = escrow.getObligation(id, oid);
        if (o.status != IParcFiEscrow.ObligationStatus.Attested) return;
        if (block.timestamp < o.challengeDeadline) vm.warp(o.challengeDeadline);
        escrow.finalizeObligation(id, oid); // permissionless — no prank on purpose
        _after(id);
    }

    function resolve(uint256 idSeed, uint256 oidSeed, uint256 splitSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        uint256 oid = bound(oidSeed, 0, a.obligationCount - 1);
        IParcFiEscrow.Obligation memory o = escrow.getObligation(id, oid);
        if (o.status != IParcFiEscrow.ObligationStatus.Challenged) return;
        uint256 split = bound(splitSeed, 0, o.amount);
        vm.prank(resolver);
        escrow.resolve(id, oid, split);
        _after(id);
    }

    function expireObligation(uint256 idSeed, uint256 oidSeed, uint256 warpSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        if (!a.fullyFunded) return;
        uint256 oid = bound(oidSeed, 0, a.obligationCount - 1);
        if (escrow.getObligation(id, oid).status != IParcFiEscrow.ObligationStatus.Pending) return;
        if (block.timestamp < a.expiry) {
            if (warpSeed % 2 == 0) return; // half the time leave the agreement alive
            vm.warp(a.expiry);
        }
        escrow.expireObligation(id, oid); // permissionless
        _after(id);
    }

    function reclaimUnfunded(uint256 idSeed, uint256 warpSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        if (a.fullyFunded || ghost_reclaimed[id] || a.fundedTotal == 0) return;
        if (block.timestamp < a.expiry) {
            if (warpSeed % 2 == 0) return;
            vm.warp(a.expiry);
        }
        uint256 amount = a.fundedTotal;
        vm.prank(a.payer);
        escrow.reclaimUnfunded(id);
        ghost_totalRefunded += amount;
        ghost_reclaimed[id] = true;
        _after(id);
    }

    function claim(uint256 idSeed, uint256 actorSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        uint256 count = _actors.length;
        uint256 start = actorSeed % count; // reduce BEFORE adding j: seed can be ~2^256-1
        for (uint256 j = 0; j < count; ++j) {
            address actor = _actors[(start + j) % count];
            uint256 amount = escrow.claimableOf(id, actor);
            if (amount == 0) continue;
            vm.prank(actor);
            escrow.claim(id);
            ghost_totalClaimed += amount;
            _after(id);
            return;
        }
    }

    function withdrawRefund(uint256 idSeed, uint256 actorSeed) external {
        (bool ok, uint256 id) = _pickId(idSeed);
        if (!ok) return;
        uint256 count = _actors.length;
        uint256 start = actorSeed % count; // reduce BEFORE adding j: seed can be ~2^256-1
        for (uint256 j = 0; j < count; ++j) {
            address actor = _actors[(start + j) % count];
            uint256 amount = escrow.refundableOf(id, actor);
            if (amount == 0) continue;
            vm.prank(actor);
            escrow.withdrawRefund(id);
            ghost_totalRefunded += amount;
            _after(id);
            return;
        }
    }

    function warpTime(uint256 seed) external {
        vm.warp(block.timestamp + bound(seed, 1 hours, 3 days));
    }

    // -------------------------------------------------------------- internals

    function _pickId(uint256 seed) internal view returns (bool, uint256) {
        if (_ids.length == 0) return (false, 0);
        return (true, _ids[bound(seed, 0, _ids.length - 1)]);
    }

    /// @dev After every successful action: cumulative counters never decrease and any
    ///      terminal status observed once is recorded so the invariant contract can
    ///      assert it never changes again.
    function _after(uint256 id) internal {
        IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
        assertGe(a.cumulativeClaimed, _lastCumClaimed[id], "ghost: cumulativeClaimed decreased");
        assertGe(a.cumulativeRefunded, _lastCumRefunded[id], "ghost: cumulativeRefunded decreased");
        _lastCumClaimed[id] = a.cumulativeClaimed;
        _lastCumRefunded[id] = a.cumulativeRefunded;

        for (uint256 i = 0; i < a.obligationCount; ++i) {
            IParcFiEscrow.ObligationStatus s = escrow.getObligation(id, i).status;
            bool terminal = s == IParcFiEscrow.ObligationStatus.Finalized
                || s == IParcFiEscrow.ObligationStatus.Resolved || s == IParcFiEscrow.ObligationStatus.Expired;
            if (!ghost_sawTerminal[id][i] && terminal) {
                ghost_sawTerminal[id][i] = true;
                ghost_terminalStatus[id][i] = s;
            }
        }
    }
}

/// @title EscrowInvariants — INV-1..INV-7 from contracts/SPEC.md under unbounded action sequences
/// @dev fail-on-revert is enabled: the handler mirrors contract preconditions exactly,
///      so any revert during a run is itself a finding.
/// forge-config: default.invariant.fail-on-revert = true
contract EscrowInvariants is Test {
    ParcFiEscrow internal escrow;
    MockUSDC internal usdc;
    EscrowHandler internal handler;

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC();
        escrow = new ParcFiEscrow(address(usdc));
        handler = new EscrowHandler(escrow, usdc);
        targetContract(address(handler));
    }

    /// INV-2 (strengthened to equality — the handler never donates): the contract's
    /// balance equals both the ghost ledger and the per-agreement accounting sum.
    function invariant_SolvencyExact() public view {
        uint256 ghostInside = handler.ghost_totalFunded() - handler.ghost_totalClaimed() - handler.ghost_totalRefunded();
        assertEq(usdc.balanceOf(address(escrow)), ghostInside, "balance != ghost boundary accounting");

        uint256 sum;
        uint256 n = handler.idCount();
        for (uint256 i = 0; i < n; ++i) {
            IParcFiEscrow.Agreement memory a = escrow.getAgreement(handler.idAt(i));
            sum += a.fundedTotal - a.cumulativeClaimed - a.cumulativeRefunded;
        }
        assertEq(usdc.balanceOf(address(escrow)), sum, "balance != per-agreement accounting");
    }

    /// INV-1 + INV-3: two-regime conservation per agreement, summing ledgers over every
    /// address that can ever hold a balance.
    function invariant_ConservationPerAgreement() public view {
        uint256 n = handler.idCount();
        uint256 actors = handler.actorCount();
        for (uint256 i = 0; i < n; ++i) {
            uint256 id = handler.idAt(i);
            IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
            uint256 sumClaimable;
            uint256 sumRefundable;
            for (uint256 j = 0; j < actors; ++j) {
                address actor = handler.actorAt(j);
                sumClaimable += escrow.claimableOf(id, actor);
                sumRefundable += escrow.refundableOf(id, actor);
            }

            if (a.fullyFunded) {
                assertEq(a.fundedTotal, a.requiredTotal, "funded regime: fundedTotal != requiredTotal");
                assertEq(
                    a.fundedTotal,
                    a.locked + sumClaimable + sumRefundable + a.cumulativeClaimed + a.cumulativeRefunded,
                    "INV-1 funded-regime conservation"
                );
            } else {
                assertLe(a.fundedTotal, a.requiredTotal, "INV-3 funding bound");
                assertEq(a.locked, 0, "underfunded: locked must be 0");
                assertEq(sumClaimable, 0, "underfunded: no claimables");
                assertEq(sumRefundable, 0, "underfunded: no refundables");
                assertEq(a.cumulativeClaimed, 0, "underfunded: nothing claimed");
                assertEq(
                    a.cumulativeRefunded,
                    handler.ghost_reclaimed(id) ? a.fundedTotal : 0,
                    "underfunded: cumulativeRefunded is 0 or the reclaimed fundedTotal"
                );
            }
        }
    }

    /// `locked` always equals the face value of non-terminal obligations once funded.
    function invariant_LockedMatchesOpenObligations() public view {
        uint256 n = handler.idCount();
        for (uint256 i = 0; i < n; ++i) {
            uint256 id = handler.idAt(i);
            IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
            if (!a.fullyFunded) {
                assertEq(a.locked, 0, "locked without full funding");
                continue;
            }
            uint256 open;
            for (uint256 oid = 0; oid < a.obligationCount; ++oid) {
                IParcFiEscrow.Obligation memory o = escrow.getObligation(id, oid);
                if (
                    o.status == IParcFiEscrow.ObligationStatus.Pending
                        || o.status == IParcFiEscrow.ObligationStatus.Attested
                        || o.status == IParcFiEscrow.ObligationStatus.Challenged
                ) open += o.amount;
            }
            assertEq(a.locked, open, "locked != sum of open obligation amounts");
        }
    }

    /// INV-5: a terminal status, once reached, never changes — checked across ALL
    /// agreements every step, so a transition on agreement X that illegally mutated
    /// agreement Y would be caught (obligation isolation, INV-4).
    function invariant_TerminalStatusesSticky() public view {
        uint256 n = handler.idCount();
        for (uint256 i = 0; i < n; ++i) {
            uint256 id = handler.idAt(i);
            IParcFiEscrow.Agreement memory a = escrow.getAgreement(id);
            for (uint256 oid = 0; oid < a.obligationCount; ++oid) {
                if (handler.ghost_sawTerminal(id, oid)) {
                    assertEq(
                        uint256(escrow.getObligation(id, oid).status),
                        uint256(handler.ghost_terminalStatus(id, oid)),
                        "terminal status mutated"
                    );
                }
            }
        }
    }
}
