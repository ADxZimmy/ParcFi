// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParcFiEscrow} from "./interfaces/IParcFiEscrow.sol";

/// @title ParcFiEscrow
/// @notice Line-item freight-invoice settlement in Arc USDC. One instance holds many
///         agreements; each agreement escrows 6-decimal USDC against a bounded set of
///         independent obligations. Undisputed obligations finalize into pull-based
///         claims; a challenged obligation is quarantined for its resolver without
///         blocking any sibling obligation.
/// @dev Acceptance spec: contracts/SPEC.md. No owner, admin, upgradeability, or pause.
///      The deployer holds no power over funds. All money paths are pull-based and
///      follow checks-effects-interactions; every state-mutating transfer is guarded
///      by `nonReentrant` and uses SafeERC20.
contract ParcFiEscrow is IParcFiEscrow, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Maximum obligations per agreement; bounds the O(n) loops in T1 and T8.
    uint16 public constant MAX_OBLIGATIONS = 16;
    /// @notice Minimum challenge window in seconds (short for testnet demos).
    uint64 public constant MIN_CHALLENGE = 1;
    /// @notice Maximum challenge window in seconds; prevents accidental multi-year locks.
    uint64 public constant MAX_CHALLENGE = 30 days;

    IERC20 private immutable _usdc;
    uint256 private _agreementCount;

    mapping(uint256 => Agreement) private _agreements;
    mapping(uint256 => Obligation[]) private _obligationsOf;
    mapping(uint256 => mapping(address => uint256)) private _claimable;
    mapping(uint256 => mapping(address => uint256)) private _refundable;

    constructor(address usdc_) {
        if (usdc_ == address(0)) revert ZeroAddress();
        _usdc = IERC20(usdc_);
    }

    // -------------------------------------------------------------- T1 create

    /// @inheritdoc IParcFiEscrow
    function createAgreement(
        bytes32 docHash,
        address attestor,
        address resolver,
        uint64 expiry,
        ObligationInput[] calldata obligations
    ) external override returns (uint256 agreementId) {
        uint256 n = obligations.length;
        if (n == 0) revert NoObligations();
        if (n > MAX_OBLIGATIONS) revert TooManyObligations();
        if (attestor == address(0) || resolver == address(0)) revert ZeroAddress();
        if (expiry <= block.timestamp) revert ExpiryNotInFuture();

        // Safe: n is bounded by MAX_OBLIGATIONS (16) directly above, well within uint16.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint16 count = uint16(n);

        agreementId = _agreementCount++;
        Agreement storage a = _agreements[agreementId];
        a.payer = msg.sender;
        a.attestor = attestor;
        a.resolver = resolver;
        a.docHash = docHash;
        a.expiry = expiry;
        a.obligationCount = count;

        Obligation[] storage obs = _obligationsOf[agreementId];
        uint256 requiredTotal;
        for (uint256 i = 0; i < n; ++i) {
            ObligationInput calldata line = obligations[i];
            if (line.beneficiary == address(0)) revert ZeroAddress();
            if (line.amount == 0) revert ZeroAmount();
            if (line.challengeDuration < MIN_CHALLENGE || line.challengeDuration > MAX_CHALLENGE) {
                revert DurationOutOfBounds();
            }
            requiredTotal += line.amount;
            obs.push(
                Obligation({
                    beneficiary: line.beneficiary,
                    amount: line.amount,
                    requiredEvidenceType: line.requiredEvidenceType,
                    challengeDuration: line.challengeDuration,
                    status: ObligationStatus.Pending,
                    evidenceHash: bytes32(0),
                    attestedAt: 0,
                    challengeDeadline: 0
                })
            );
            emit ObligationCreated(
                agreementId, i, line.beneficiary, line.amount, line.requiredEvidenceType, line.challengeDuration
            );
        }
        a.requiredTotal = requiredTotal;

        emit AgreementCreated(agreementId, msg.sender, attestor, resolver, docHash, expiry, requiredTotal, count);
    }

    // ---------------------------------------------------------------- T2 fund

    /// @inheritdoc IParcFiEscrow
    function fund(uint256 agreementId, uint256 amount) external override nonReentrant {
        Agreement storage a = _getAgreement(agreementId);
        if (msg.sender != a.payer) revert NotPayer();
        if (amount == 0) revert ZeroAmount();
        if (a.fullyFunded) revert AlreadyFullyFunded();
        // G1-F1: a reclaimed agreement (T8) must never accept new deposits — its
        // obligations are all terminally Expired, so any later latch would lock value
        // forever. Pre-full-funding T8 is the only status-flipping transition, so
        // obligation 0 is a sufficient sentinel.
        if (_obligationsOf[agreementId][0].status != ObligationStatus.Pending) revert InvalidStatus();

        uint256 newFunded = a.fundedTotal + amount;
        if (newFunded > a.requiredTotal) revert OverFunding();
        a.fundedTotal = newFunded;
        emit Funded(agreementId, amount, newFunded);

        if (newFunded == a.requiredTotal) {
            a.fullyFunded = true;
            a.locked = a.requiredTotal;
            emit FullyFunded(agreementId);
        }

        _usdc.safeTransferFrom(msg.sender, address(this), amount);
    }

    // -------------------------------------------------------------- T3 attest

    /// @inheritdoc IParcFiEscrow
    function attest(uint256 agreementId, uint256 obligationId, bytes32 evidenceHash, bytes32 evidenceType)
        external
        override
    {
        Agreement storage a = _getAgreement(agreementId);
        if (msg.sender != a.attestor) revert NotAttestor();
        if (!a.fullyFunded) revert NotFullyFunded();
        if (block.timestamp >= a.expiry) revert Expired();
        if (evidenceHash == bytes32(0)) revert ZeroEvidenceHash();

        Obligation storage o = _getObligation(agreementId, obligationId);
        if (o.status != ObligationStatus.Pending) revert InvalidStatus();
        if (evidenceType != o.requiredEvidenceType) revert EvidenceTypeMismatch();

        o.status = ObligationStatus.Attested;
        o.evidenceHash = evidenceHash;
        o.attestedAt = uint64(block.timestamp);
        uint64 deadline = uint64(block.timestamp) + o.challengeDuration;
        o.challengeDeadline = deadline;

        emit Attested(agreementId, obligationId, evidenceHash, evidenceType, deadline);
    }

    // ----------------------------------------------------------- T4 challenge

    /// @inheritdoc IParcFiEscrow
    function challenge(uint256 agreementId, uint256 obligationId) external override {
        Agreement storage a = _getAgreement(agreementId);
        if (msg.sender != a.payer) revert NotPayer();

        Obligation storage o = _getObligation(agreementId, obligationId);
        if (o.status != ObligationStatus.Attested) revert InvalidStatus();
        if (block.timestamp >= o.challengeDeadline) revert ChallengeWindowClosed();

        o.status = ObligationStatus.Challenged;
        emit Challenged(agreementId, obligationId);
    }

    // ------------------------------------------------------------ T5 finalize

    /// @inheritdoc IParcFiEscrow
    function finalizeObligation(uint256 agreementId, uint256 obligationId) external override {
        Agreement storage a = _getAgreement(agreementId);
        Obligation storage o = _getObligation(agreementId, obligationId);
        if (o.status != ObligationStatus.Attested) revert InvalidStatus();
        if (block.timestamp < o.challengeDeadline) revert ChallengeWindowOpen();

        o.status = ObligationStatus.Finalized;
        a.locked -= o.amount;
        _claimable[agreementId][o.beneficiary] += o.amount;

        emit ObligationFinalized(agreementId, obligationId, o.beneficiary, o.amount);
    }

    // ------------------------------------------------------------- T6 resolve

    /// @inheritdoc IParcFiEscrow
    function resolve(uint256 agreementId, uint256 obligationId, uint256 amountToBeneficiary) external override {
        Agreement storage a = _getAgreement(agreementId);
        if (msg.sender != a.resolver) revert NotResolver();

        Obligation storage o = _getObligation(agreementId, obligationId);
        if (o.status != ObligationStatus.Challenged) revert InvalidStatus();
        if (amountToBeneficiary > o.amount) revert SplitExceedsAmount();

        o.status = ObligationStatus.Resolved;
        a.locked -= o.amount;
        uint256 toPayer = o.amount - amountToBeneficiary;
        if (amountToBeneficiary > 0) _claimable[agreementId][o.beneficiary] += amountToBeneficiary;
        if (toPayer > 0) _refundable[agreementId][a.payer] += toPayer;

        emit ObligationResolved(agreementId, obligationId, amountToBeneficiary, toPayer);
    }

    // ------------------------------------------------------------- T7 expire

    /// @inheritdoc IParcFiEscrow
    function expireObligation(uint256 agreementId, uint256 obligationId) external override {
        Agreement storage a = _getAgreement(agreementId);
        if (!a.fullyFunded) revert NotFullyFunded();
        if (block.timestamp < a.expiry) revert NotYetExpired();

        Obligation storage o = _getObligation(agreementId, obligationId);
        if (o.status != ObligationStatus.Pending) revert InvalidStatus();

        o.status = ObligationStatus.Expired;
        a.locked -= o.amount;
        _refundable[agreementId][a.payer] += o.amount;

        emit ObligationExpired(agreementId, obligationId, o.amount);
    }

    // --------------------------------------------------- T8 reclaim unfunded

    /// @inheritdoc IParcFiEscrow
    function reclaimUnfunded(uint256 agreementId) external override nonReentrant {
        Agreement storage a = _getAgreement(agreementId);
        if (msg.sender != a.payer) revert NotPayer();
        if (a.fullyFunded) revert AlreadyFullyFunded();
        if (block.timestamp < a.expiry) revert NotYetExpired();

        uint256 amount = a.fundedTotal;
        if (amount == 0) revert NothingToWithdraw();

        Obligation[] storage obs = _obligationsOf[agreementId];
        // Before full funding every obligation is necessarily Pending, so obligation 0
        // is representative: after the first reclaim it is Expired and this reverts,
        // which — together with an unchanged fundedTotal — blocks any double payout.
        if (obs[0].status != ObligationStatus.Pending) revert InvalidStatus();

        uint256 n = obs.length;
        for (uint256 i = 0; i < n; ++i) {
            obs[i].status = ObligationStatus.Expired;
            emit ObligationExpired(agreementId, i, obs[i].amount);
        }
        a.cumulativeRefunded += amount;

        emit UnfundedReclaimed(agreementId, amount);
        _usdc.safeTransfer(a.payer, amount);
    }

    // ---------------------------------------------------------------- T9 claim

    /// @inheritdoc IParcFiEscrow
    function claim(uint256 agreementId) external override nonReentrant {
        Agreement storage a = _getAgreement(agreementId);
        uint256 amount = _claimable[agreementId][msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        _claimable[agreementId][msg.sender] = 0;
        a.cumulativeClaimed += amount;

        emit Claimed(agreementId, msg.sender, amount);
        _usdc.safeTransfer(msg.sender, amount);
    }

    // ------------------------------------------------------- T10 withdraw refund

    /// @inheritdoc IParcFiEscrow
    function withdrawRefund(uint256 agreementId) external override nonReentrant {
        Agreement storage a = _getAgreement(agreementId);
        uint256 amount = _refundable[agreementId][msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        _refundable[agreementId][msg.sender] = 0;
        a.cumulativeRefunded += amount;

        emit RefundWithdrawn(agreementId, msg.sender, amount);
        _usdc.safeTransfer(msg.sender, amount);
    }

    // ---------------------------------------------------------------- views

    /// @inheritdoc IParcFiEscrow
    function usdc() external view override returns (address) {
        return address(_usdc);
    }

    /// @inheritdoc IParcFiEscrow
    function agreementCount() external view override returns (uint256) {
        return _agreementCount;
    }

    /// @inheritdoc IParcFiEscrow
    function getAgreement(uint256 agreementId) external view override returns (Agreement memory) {
        return _getAgreement(agreementId);
    }

    /// @inheritdoc IParcFiEscrow
    function getObligation(uint256 agreementId, uint256 obligationId)
        external
        view
        override
        returns (Obligation memory)
    {
        return _getObligation(agreementId, obligationId);
    }

    /// @inheritdoc IParcFiEscrow
    function claimableOf(uint256 agreementId, address account) external view override returns (uint256) {
        return _claimable[agreementId][account];
    }

    /// @inheritdoc IParcFiEscrow
    function refundableOf(uint256 agreementId, address account) external view override returns (uint256) {
        return _refundable[agreementId][account];
    }

    // --------------------------------------------------------------- internal

    function _getAgreement(uint256 agreementId) private view returns (Agreement storage a) {
        if (agreementId >= _agreementCount) revert UnknownAgreement();
        a = _agreements[agreementId];
    }

    function _getObligation(uint256 agreementId, uint256 obligationId) private view returns (Obligation storage o) {
        Obligation[] storage obs = _obligationsOf[agreementId];
        if (obligationId >= obs.length) revert UnknownObligation();
        o = obs[obligationId];
    }
}
