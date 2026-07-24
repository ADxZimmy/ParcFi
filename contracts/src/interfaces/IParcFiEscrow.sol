// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IParcFiEscrow — line-item freight-invoice settlement in Arc USDC
/// @notice One contract holds many agreements. An agreement escrows 6-decimal USDC
///         against a bounded set of independent line-item obligations. Undisputed
///         obligations finalize into pull-based claims; a challenged obligation is
///         quarantined for its resolver without blocking any sibling obligation.
/// @dev Full acceptance spec: contracts/SPEC.md. No owner, no admin, no upgrades.
interface IParcFiEscrow {
    // ---------------------------------------------------------------- types

    enum ObligationStatus {
        Pending,
        Attested,
        Challenged,
        Finalized,
        Resolved,
        Expired
    }

    struct ObligationInput {
        address beneficiary;
        uint256 amount; // 6-decimal USDC units
        bytes32 requiredEvidenceType; // typed metadata label, never a document body
        uint64 challengeDuration; // seconds, within [MIN_CHALLENGE, MAX_CHALLENGE]
    }

    struct Obligation {
        address beneficiary;
        uint256 amount;
        bytes32 requiredEvidenceType;
        uint64 challengeDuration;
        ObligationStatus status;
        bytes32 evidenceHash;
        uint64 attestedAt;
        uint64 challengeDeadline;
    }

    struct Agreement {
        address payer;
        address attestor;
        address resolver;
        bytes32 docHash;
        uint64 expiry;
        uint16 obligationCount;
        bool fullyFunded;
        uint256 requiredTotal;
        uint256 fundedTotal;
        uint256 locked;
        uint256 cumulativeClaimed;
        uint256 cumulativeRefunded;
    }

    // --------------------------------------------------------------- events

    event AgreementCreated(
        uint256 indexed agreementId,
        address indexed payer,
        address attestor,
        address resolver,
        bytes32 docHash,
        uint64 expiry,
        uint256 requiredTotal,
        uint16 obligationCount
    );
    event ObligationCreated(
        uint256 indexed agreementId,
        uint256 indexed obligationId,
        address indexed beneficiary,
        uint256 amount,
        bytes32 requiredEvidenceType,
        uint64 challengeDuration
    );
    event Funded(uint256 indexed agreementId, uint256 amount, uint256 fundedTotal);
    event FullyFunded(uint256 indexed agreementId);
    event Attested(
        uint256 indexed agreementId,
        uint256 indexed obligationId,
        bytes32 evidenceHash,
        bytes32 evidenceType,
        uint64 challengeDeadline
    );
    event Challenged(uint256 indexed agreementId, uint256 indexed obligationId);
    event ObligationFinalized(
        uint256 indexed agreementId, uint256 indexed obligationId, address indexed beneficiary, uint256 amount
    );
    event ObligationResolved(
        uint256 indexed agreementId, uint256 indexed obligationId, uint256 amountToBeneficiary, uint256 amountToPayer
    );
    event ObligationExpired(uint256 indexed agreementId, uint256 indexed obligationId, uint256 amount);
    event Claimed(uint256 indexed agreementId, address indexed beneficiary, uint256 amount);
    event RefundWithdrawn(uint256 indexed agreementId, address indexed payer, uint256 amount);
    event UnfundedReclaimed(uint256 indexed agreementId, uint256 amount);

    // --------------------------------------------------------------- errors

    error NotPayer();
    error NotAttestor();
    error NotResolver();
    error UnknownAgreement();
    error UnknownObligation();
    error InvalidStatus();
    error NotFullyFunded();
    error OverFunding();
    error AlreadyFullyFunded();
    error ChallengeWindowOpen();
    error ChallengeWindowClosed();
    error Expired();
    error NotYetExpired();
    error EvidenceTypeMismatch();
    error ZeroAmount();
    error ZeroAddress();
    error ZeroEvidenceHash();
    error TooManyObligations();
    error NoObligations();
    error DurationOutOfBounds();
    error ExpiryNotInFuture();
    error SplitExceedsAmount();
    error NothingToWithdraw();

    // ------------------------------------------------------------ mutations

    /// @notice T1 — create an agreement; caller becomes the payer.
    function createAgreement(
        bytes32 docHash,
        address attestor,
        address resolver,
        uint64 expiry,
        ObligationInput[] calldata obligations
    ) external returns (uint256 agreementId);

    /// @notice T2 — payer deposits USDC; cumulative deposits may never exceed requiredTotal.
    function fund(uint256 agreementId, uint256 amount) external;

    /// @notice T3 — attestor submits the typed evidence hash, opening the challenge window.
    function attest(uint256 agreementId, uint256 obligationId, bytes32 evidenceHash, bytes32 evidenceType) external;

    /// @notice T4 — payer disputes one attested obligation strictly before its deadline.
    function challenge(uint256 agreementId, uint256 obligationId) external;

    /// @notice T5 — anyone finalizes an unchallenged obligation at/after its deadline.
    function finalizeObligation(uint256 agreementId, uint256 obligationId) external;

    /// @notice T6 — resolver splits a challenged obligation between beneficiary and payer.
    function resolve(uint256 agreementId, uint256 obligationId, uint256 amountToBeneficiary) external;

    /// @notice T7 — anyone expires a still-pending obligation at/after agreement expiry.
    function expireObligation(uint256 agreementId, uint256 obligationId) external;

    /// @notice T8 — payer reclaims the whole deposit of a never-fully-funded agreement after expiry.
    function reclaimUnfunded(uint256 agreementId) external;

    /// @notice T9 — caller withdraws their entire claimable balance for one agreement.
    function claim(uint256 agreementId) external;

    /// @notice T10 — caller withdraws their entire refundable balance for one agreement.
    function withdrawRefund(uint256 agreementId) external;

    // ---------------------------------------------------------------- views

    function usdc() external view returns (address);
    function agreementCount() external view returns (uint256);
    function getAgreement(uint256 agreementId) external view returns (Agreement memory);
    function getObligation(uint256 agreementId, uint256 obligationId) external view returns (Obligation memory);
    function claimableOf(uint256 agreementId, address account) external view returns (uint256);
    function refundableOf(uint256 agreementId, address account) external view returns (uint256);
}
