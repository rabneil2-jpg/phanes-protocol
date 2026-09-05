// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title PHANES RC10 v0.8 Production Candidate — fixed issuance with permanent secondary transferability after the 48-hour KHAOS opening
/// @dev NOT the frozen RC7 baseline. NOT AUDITED. NOT DEPLOYED. Fresh Solidity/EVM reproduction is mandatory before promotion.

/// @notice Minimal payment-token interface used by PHANES public issuance.
interface IERC20Payment {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Narrow interface exposed to the protocol-owned founder/rewards vaults.
interface IPHANESCore {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function protocolRewardTransfer(address to, uint256 value) external;
    function protocolReserveTransfer(address to, uint256 value) external;
    function protocolLaunchPartnerTransfer(address to, uint256 value) external;
    function protocolLaunchReturnToRewards(uint256 value) external;
    function protocolFounderTransfer(address to, uint256 value) external;
}

/// @notice Test-only USDC analogue. NOT FOR MAINNET.
contract MockUSDC {
    string public constant name = "Mock USDC";
    string public constant symbol = "mUSDC";
    uint8 public constant decimals = 6;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "mUSDC: allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "mUSDC: zero");
        uint256 bal = balanceOf[from];
        require(bal >= value, "mUSDC: balance");
        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }
}

/// @notice Protocol capital vault. It receives the 2m PHN liquidity allocation, all issuance USDC, and future protocol-liquidity PHN.
/// @dev This candidate intentionally does NOT yet implement the final concentrated-liquidity adapter.
///      Exact DEX/tick implementation remains a separately gated EVM/audit task.
contract PHANESLiquidityVault {
    address public immutable phanes;
    address public immutable paymentToken;
    /// @notice Normal PHN transfer/approval compatibility begins once the KHAOS 48-hour fair-access window completes.
    uint64 public constant PUBLIC_TRANSFER_RELEASE_START = 1_798_059_000; // 23 Dec 2026 20:50 UTC
    uint64 public constant FULL_PUBLIC_TRANSFERABILITY_TIME = 1_798_059_000; // full and permanent from opening

    /// @dev Transferability does not itself deploy the 2m PHN held here to a DEX.
    ///      The final concentrated-liquidity adapter remains a separate release-gated engineering task.

    constructor(address phanes_, address paymentToken_) {
        require(phanes_ != address(0) && paymentToken_ != address(0), "LiquidityVault: zero");
        phanes = phanes_;
        paymentToken = paymentToken_;
    }

    // Deliberately no withdraw(), rescue(), sweep(), arbitrary call(), delegatecall or upgrade path.
}

/// @notice Holds all public PHN still unsold when OION closes.
/// @dev The Reserve retains RC7's fixed 2040 long-term gate. Thereafter, only a
///      continuously increasing ceiling may move permissionlessly to the protocol liquidity vault.
///      Eligibility is NOT a market sale and this contract has no arbitrary recipient path.
contract PHANESReserveVault {
    IPHANESCore public immutable phanes;
    address public immutable liquidityVault;

    uint256 public constant WAD = 1e18;
    uint64 public constant FULL_PUBLIC_TRANSFERABILITY_TIME = 1_798_059_000; // 23 Dec 2026 20:50 UTC — holder transfers fully open
    uint64 public constant ELIGIBILITY_START = 2_215_864_260; // 20 Mar 2040 13:51 UTC
    uint64 public constant FIFTY_PERCENT_TIME = 2_373_630_660; // 20 Mar 2045 13:51 UTC
    uint64 public constant SEVENTY_FIVE_PERCENT_TIME = 2_531_397_060; // 20 Mar 2050 13:51 UTC
    uint64 public constant FULL_ELIGIBILITY_TIME = 2_689_163_460; // 20 Mar 2055 13:51 UTC

    uint256 public originalReserve;
    uint256 public releasedToLiquidity;
    bool public isSealed;

    event ReserveSealed(uint256 originalReserve);
    event ReserveLiquidityReleased(uint256 amount, uint256 cumulativeReleased, uint256 stillSealed);

    constructor(address phanes_, address liquidityVault_) {
        require(phanes_ != address(0) && liquidityVault_ != address(0), "Reserve: zero");
        phanes = IPHANESCore(phanes_);
        liquidityVault = liquidityVault_;
    }

    /// @notice Called once by the PHANES core after OION closes and the unsold inventory is transferred here.
    function sealReserve(uint256 amount) external {
        require(msg.sender == address(phanes), "Reserve: PHANES only");
        require(!isSealed, "Reserve: isSealed");
        require(phanes.balanceOf(address(this)) == amount, "Reserve: balance mismatch");
        isSealed = true;
        originalReserve = amount;
        emit ReserveSealed(amount);
    }

    function eligibilityFractionWad(uint64 timestamp) public pure returns (uint256) {
        if (timestamp < ELIGIBILITY_START) return 0;
        if (timestamp < FIFTY_PERCENT_TIME) {
            return (uint256(timestamp - ELIGIBILITY_START) * (WAD / 2)) /
                uint256(FIFTY_PERCENT_TIME - ELIGIBILITY_START);
        }
        if (timestamp < SEVENTY_FIVE_PERCENT_TIME) {
            return (WAD / 2) +
                (uint256(timestamp - FIFTY_PERCENT_TIME) * (WAD / 4)) /
                uint256(SEVENTY_FIVE_PERCENT_TIME - FIFTY_PERCENT_TIME);
        }
        if (timestamp < FULL_ELIGIBILITY_TIME) {
            return (3 * WAD / 4) +
                (uint256(timestamp - SEVENTY_FIVE_PERCENT_TIME) * (WAD / 4)) /
                uint256(FULL_ELIGIBILITY_TIME - SEVENTY_FIVE_PERCENT_TIME);
        }
        return WAD;
    }

    function eligibleAmount(uint64 timestamp) public view returns (uint256) {
        return (originalReserve * eligibilityFractionWad(timestamp)) / WAD;
    }

    function releasableToLiquidity() public view returns (uint256) {
        if (!isSealed) return 0;
        uint256 eligible = eligibleAmount(uint64(block.timestamp));
        return eligible > releasedToLiquidity ? eligible - releasedToLiquidity : 0;
    }

    /// @notice Permissionless execution. Eligible PHN can move only to the immutable protocol liquidity vault.
    function releaseEligibleToLiquidity() external returns (uint256 amount) {
        amount = releasableToLiquidity();
        require(amount != 0, "Reserve: none");
        releasedToLiquidity += amount;
        phanes.protocolReserveTransfer(liquidityVault, amount);
        emit ReserveLiquidityReleased(amount, releasedToLiquidity, originalReserve - releasedToLiquidity);
    }

    function reserveTransparencyStatus() external view returns (
        uint256 original,
        uint256 eligibleNow,
        uint256 released,
        uint256 releasableNow,
        uint256 stillInReserve,
        uint64 nextMilestone
    ) {
        original = originalReserve;
        eligibleNow = eligibleAmount(uint64(block.timestamp));
        released = releasedToLiquidity;
        releasableNow = eligibleNow > released ? eligibleNow - released : 0;
        stillInReserve = phanes.balanceOf(address(this));

        if (block.timestamp < ELIGIBILITY_START) nextMilestone = ELIGIBILITY_START;
        else if (block.timestamp < FIFTY_PERCENT_TIME) nextMilestone = FIFTY_PERCENT_TIME;
        else if (block.timestamp < SEVENTY_FIVE_PERCENT_TIME) nextMilestone = SEVENTY_FIVE_PERCENT_TIME;
        else if (block.timestamp < FULL_ELIGIBILITY_TIME) nextMilestone = FULL_ELIGIBILITY_TIME;
        else nextMilestone = 0;
    }

    // Deliberately no founder withdrawal, arbitrary recipient, acceleration, governance override or upgrade path.
}

contract PHANESFounderVault {
    IPHANESCore public immutable phanes;
    address public immutable beneficiary;

    uint256 public constant UNIT = 10_000;
    uint256 public constant ALLOCATION = 1_000_000 * UNIT;
    /// @notice 200,000 PHN at each of the five issuance epoch opens (KHAOS→OION).
    uint256 public constant TRANCHE = 200_000 * UNIT;

    // Epoch-aligned founder unlocks (matches protocol epoch opens on Base production design).
    uint64 public constant RELEASE_1 = 1_797_886_200; // KHAOS  21 Dec 2026 20:50 UTC
    uint64 public constant RELEASE_2 = 1_808_427_000; // CHRONOS 22 Apr 2027 20:50 UTC
    uint64 public constant RELEASE_3 = 1_819_054_200; // ANANKE 23 Aug 2027 20:50 UTC
    uint64 public constant RELEASE_4 = 1_829_508_600; // AITHER 22 Dec 2027 20:50 UTC
    uint64 public constant RELEASE_5 = 1_840_049_400; // OION   22 Apr 2028 20:50 UTC

    uint256 public released;

    event FounderReleased(uint256 amount, uint256 cumulativeReleased, uint256 stillLocked);

    constructor(address phanes_, address beneficiary_) {
        require(phanes_ != address(0) && beneficiary_ != address(0), "FounderVault: zero");
        phanes = IPHANESCore(phanes_);
        beneficiary = beneficiary_;
    }

    function availableAmount(uint64 timestamp) public pure returns (uint256) {
        if (timestamp < RELEASE_1) return 0;
        if (timestamp < RELEASE_2) return TRANCHE;
        if (timestamp < RELEASE_3) return 2 * TRANCHE;
        if (timestamp < RELEASE_4) return 3 * TRANCHE;
        if (timestamp < RELEASE_5) return 4 * TRANCHE;
        return ALLOCATION;
    }

    function releasable() public view returns (uint256) {
        uint256 available = availableAmount(uint64(block.timestamp));
        return available > released ? available - released : 0;
    }

    /// @notice Permissionless execution; unlocked PHN can only go to the immutable beneficiary.
    function release() external returns (uint256 amount) {
        amount = releasable();
        require(amount != 0, "FounderVault: none");
        released += amount;
        // Bypass public transfer lock via narrow core path; beneficiary is immutable.
        phanes.protocolFounderTransfer(beneficiary, amount);
        emit FounderReleased(amount, released, ALLOCATION - released);
    }

    function founderTransparencyStatus() external view returns (
        uint256 allocation,
        uint256 available,
        uint256 releasedAmount,
        uint256 releasableNow,
        uint256 locked
    ) {
        allocation = ALLOCATION;
        available = availableAmount(uint64(block.timestamp));
        releasedAmount = released;
        releasableNow = available > released ? available - released : 0;
        locked = ALLOCATION - available;
    }

    // Deliberately no acceleration, beneficiary change, approval, loan or arbitrary-call path.
}

/// @notice Temporary 250k PHN Launch Enablement Vault.
/// @dev Exists only to replace otherwise-required cash for essential launch services.
///      Every allocation requires the primary approver plus BOTH independent reviewers,
///      an agreement hash and an evidence hash, and must be claimed before KHAOS opens.
///      Unclaimed allocations may be cancelled before KHAOS without moving PHN, restoring capacity.
///      At KHAOS, every unclaimed PHN becomes permanently unavailable for launch use and
///      may only move one-way into the Rewards Vault. Recipients remain subject to the
///      shared PHANES 48-hour KHAOS transfer gate; after 23 Dec 2026 20:50 UTC transfers remain permanently open.
contract PHANESLaunchEnablementVault {
    enum Purpose { RegulatedDistribution, LegalCompliance, SecurityAudit, TechnicalInfrastructure, LaunchOperations }

    struct Allocation {
        address recipient;
        uint128 amount;
        Purpose purpose;
        bytes32 agreementHash;
        bytes32 evidenceHash;
        uint8 reviewerMask;
        bool primaryApproved;
        bool claimed;
        bool cancelled;
    }

    IPHANESCore public immutable phanes;
    address public immutable primaryApprover;
    address public immutable reviewerOne;
    address public immutable reviewerTwo;

    uint256 public constant UNIT = 10_000;
    uint256 public constant TOTAL_LAUNCH_ENABLEMENT = 250_000 * UNIT;
    uint64 public constant KHAOS_START = 1_797_886_200; // 21 Dec 2026 20:50 UTC

    uint64 public allocationCount;
    uint256 public totalApproved;
    uint256 public totalClaimed;
    uint256 public totalCancelled;
    bool public unusedReturned;
    mapping(uint64 => Allocation) public allocations;

    event LaunchAllocationApproved(
        uint64 indexed allocationId,
        address indexed recipient,
        Purpose indexed purpose,
        uint256 amount,
        bytes32 agreementHash,
        bytes32 evidenceHash
    );
    event LaunchAllocationReviewed(uint64 indexed allocationId, address indexed reviewer, uint8 resultingMask);
    event LaunchAllocationCancelled(uint64 indexed allocationId, address indexed recipient, uint256 amount);
    event LaunchAllocationClaimed(uint64 indexed allocationId, address indexed recipient, uint256 amount);
    event LaunchUnusedReturnedToRewards(uint256 amount);

    modifier onlyPrimary() {
        require(msg.sender == primaryApprover, "Launch: primary only");
        _;
    }

    modifier onlyReviewer() {
        require(msg.sender == reviewerOne || msg.sender == reviewerTwo, "Launch: reviewer only");
        _;
    }

    constructor(address phanes_, address primaryApprover_, address reviewerOne_, address reviewerTwo_) {
        require(
            phanes_ != address(0) &&
            primaryApprover_ != address(0) &&
            reviewerOne_ != address(0) &&
            reviewerTwo_ != address(0),
            "Launch: zero"
        );
        require(primaryApprover_ != reviewerOne_, "Launch: reviewer one must differ");
        require(primaryApprover_ != reviewerTwo_, "Launch: reviewer two must differ");
        require(reviewerOne_ != reviewerTwo_, "Launch: reviewers must differ");
        phanes = IPHANESCore(phanes_);
        primaryApprover = primaryApprover_;
        reviewerOne = reviewerOne_;
        reviewerTwo = reviewerTwo_;
    }

    function approveAllocation(
        address recipient,
        uint128 amount,
        Purpose purpose,
        bytes32 agreementHash,
        bytes32 evidenceHash
    ) external onlyPrimary returns (uint64 allocationId) {
        require(block.timestamp < KHAOS_START, "Launch: closed");
        require(!unusedReturned, "Launch: returned");
        require(
            recipient != address(0) &&
            recipient != address(phanes) &&
            recipient != address(this) &&
            recipient != primaryApprover &&
            recipient != reviewerOne &&
            recipient != reviewerTwo,
            "Launch: blocked recipient"
        );
        require(amount != 0, "Launch: zero amount");
        require(agreementHash != bytes32(0), "Launch: agreement hash required");
        require(evidenceHash != bytes32(0), "Launch: evidence hash required");
        uint256 nextApproved = totalApproved + amount;
        require(nextApproved <= TOTAL_LAUNCH_ENABLEMENT, "Launch: allocation cap");
        require(nextApproved <= phanes.balanceOf(address(this)) + totalClaimed, "Launch: balance cap");

        allocationId = ++allocationCount;
        allocations[allocationId] = Allocation({
            recipient: recipient,
            amount: amount,
            purpose: purpose,
            agreementHash: agreementHash,
            evidenceHash: evidenceHash,
            reviewerMask: 0,
            primaryApproved: true,
            claimed: false,
            cancelled: false
        });
        totalApproved = nextApproved;
        emit LaunchAllocationApproved(allocationId, recipient, purpose, amount, agreementHash, evidenceHash);
    }

    function reviewAllocation(uint64 allocationId) external onlyReviewer {
        require(block.timestamp < KHAOS_START, "Launch: closed");
        Allocation storage a = allocations[allocationId];
        require(a.primaryApproved && !a.claimed && !a.cancelled, "Launch: bad allocation");
        uint8 bit = msg.sender == reviewerOne ? 1 : 2;
        require((a.reviewerMask & bit) == 0, "Launch: already reviewed");
        a.reviewerMask |= bit;
        emit LaunchAllocationReviewed(allocationId, msg.sender, a.reviewerMask);
    }

    /// @notice Before KHAOS, the primary approver may cancel an unclaimed allocation without moving PHN.
    /// @dev This restores Launch Enablement capacity. Any replacement is a fresh allocation requiring fresh hashes and both reviews.
    function cancelAllocation(uint64 allocationId) external onlyPrimary returns (uint256 amount) {
        require(block.timestamp < KHAOS_START, "Launch: closed");
        require(!unusedReturned, "Launch: returned");
        Allocation storage a = allocations[allocationId];
        require(a.primaryApproved && !a.claimed && !a.cancelled, "Launch: not cancellable");
        a.cancelled = true;
        amount = a.amount;
        totalApproved -= amount;
        totalCancelled += amount;
        emit LaunchAllocationCancelled(allocationId, a.recipient, amount);
    }

    function claimAllocation(uint64 allocationId) external returns (uint256 amount) {
        require(block.timestamp < KHAOS_START, "Launch: claim expired");
        require(!unusedReturned, "Launch: returned");
        Allocation storage a = allocations[allocationId];
        require(a.primaryApproved && !a.claimed && !a.cancelled, "Launch: not claimable");
        require(msg.sender == a.recipient, "Launch: recipient only");
        require(a.reviewerMask == 3, "Launch: both reviews required");
        a.claimed = true;
        amount = a.amount;
        totalClaimed += amount;
        phanes.protocolLaunchPartnerTransfer(a.recipient, amount);
        emit LaunchAllocationClaimed(allocationId, a.recipient, amount);
    }

    /// @notice Permissionless after KHAOS. All remaining balance goes to Rewards and can never be reclaimed for launch use.
    function returnUnusedToRewards() external returns (uint256 amount) {
        require(block.timestamp >= KHAOS_START, "Launch: too early");
        require(!unusedReturned, "Launch: returned");
        unusedReturned = true;
        amount = phanes.balanceOf(address(this));
        if (amount != 0) phanes.protocolLaunchReturnToRewards(amount);
        emit LaunchUnusedReturnedToRewards(amount);
    }

    function status() external view returns (
        uint256 vaultBalance,
        uint256 approved,
        uint256 claimed,
        uint256 unclaimedBalance,
        uint64 deadline,
        bool returned
    ) {
        vaultBalance = phanes.balanceOf(address(this));
        approved = totalApproved;
        claimed = totalClaimed;
        unclaimedBalance = vaultBalance;
        deadline = KHAOS_START;
        returned = unusedReturned;
    }
}

interface IPHANESLaunchSweep {
    function unusedReturned() external view returns (bool);
    function returnUnusedToRewards() external returns (uint256);
}

/// @notice Purpose-restricted 750k PHN initial Security & Ecosystem Rewards Vault.
/// @dev This candidate implements the agreed hard caps and approval-without-custody model.
///      Operational signer recovery and the final rewards sunset date remain explicit pre-mainnet items.
contract PHANESRewardsVault {
    enum Category { Technical, Research, Ecosystem, Promotion }

    struct Campaign {
        Category category;
        uint128 budget;
        uint128 approved;
        uint128 paid;
        uint128 maxPerClaim;
        uint16 maxClaimsPerWallet;
        uint64 startTime;
        uint64 endTime;
        bytes32 metadataHash;
        bool finalized;
    }

    struct Claim {
        uint64 campaignId;
        address recipient;
        uint128 amount;
        bytes32 evidenceHash;
        uint8 reviewerMask;
        bool primaryApproved;
        bool claimed;
    }

    IPHANESCore public immutable phanes;
    address public immutable primaryApprover;
    address public immutable reviewerOne;
    address public immutable reviewerTwo;
    uint64 public immutable rewardsExpiryTime;
    address public immutable liquidityVault;
    IPHANESLaunchSweep public immutable launchEnablementVault;

    uint256 public constant UNIT = 10_000;
    uint256 public constant INITIAL_REWARDS = 750_000 * UNIT;
    uint256 public constant MAX_REWARDS_CAPACITY = 1_000_000 * UNIT;
    uint256 public constant TECHNICAL_MAX_PER_CLAIM = 50_000 * UNIT;
    uint256 public constant ABSOLUTE_MAX_PER_CLAIM = 100_000 * UNIT;
    uint256 public constant ENHANCED_REVIEW_THRESHOLD = 50_000 * UNIT;

    uint64 public campaignCount;
    uint256 public totalCampaignBudgetCommitted;
    bool public sunsetProcessed;
    mapping(uint64 => Campaign) public campaigns;
    mapping(bytes32 => Claim) public claims;
    mapping(bytes32 => bool) public claimIdUsed;
    mapping(uint64 => mapping(address => uint16)) public walletClaimsInCampaign;
    mapping(address => bool) public blockedRecipient;

    event CampaignCreated(
        uint64 indexed campaignId,
        Category indexed category,
        uint256 budget,
        uint256 maxPerClaim,
        uint16 maxClaimsPerWallet,
        uint64 startTime,
        uint64 endTime,
        bytes32 metadataHash
    );
    event CampaignFinalized(uint64 indexed campaignId, uint256 unusedBudgetReleased, uint256 outstandingApproved);
    event RewardApproved(bytes32 indexed claimId, uint64 indexed campaignId, address indexed recipient, uint256 amount, bytes32 evidenceHash);
    event RewardReviewed(bytes32 indexed claimId, address indexed reviewer, uint8 resultingMask);
    event RewardClaimed(bytes32 indexed claimId, address indexed recipient, uint256 amount);
    event RewardsSunsetLiquidity(uint256 movedToLiquidity);

    modifier onlyPrimary() {
        require(msg.sender == primaryApprover, "Rewards: primary only");
        _;
    }

    modifier onlyReviewer() {
        require(msg.sender == reviewerOne || msg.sender == reviewerTwo, "Rewards: reviewer only");
        _;
    }

    constructor(
        address phanes_,
        address primaryApprover_,
        address reviewerOne_,
        address reviewerTwo_,
        uint64 rewardsExpiryTime_,
        address founderVault_,
        address liquidityVault_,
        address reserveVault_,
        address launchEnablementVault_
    ) {
        require(
            phanes_ != address(0) &&
            primaryApprover_ != address(0) &&
            reviewerOne_ != address(0) &&
            reviewerTwo_ != address(0) &&
            founderVault_ != address(0) &&
            liquidityVault_ != address(0) &&
            reserveVault_ != address(0) &&
            launchEnablementVault_ != address(0),
            "Rewards: zero"
        );
        require(primaryApprover_ != reviewerOne_, "Rewards: reviewer one must differ");
        require(primaryApprover_ != reviewerTwo_, "Rewards: reviewer two must differ");
        require(reviewerOne_ != reviewerTwo_, "Rewards: reviewers must differ");
        require(rewardsExpiryTime_ > 1_900_245_060, "Rewards: expiry too early");

        phanes = IPHANESCore(phanes_);
        primaryApprover = primaryApprover_;
        reviewerOne = reviewerOne_;
        reviewerTwo = reviewerTwo_;
        rewardsExpiryTime = rewardsExpiryTime_;
        liquidityVault = liquidityVault_;
        launchEnablementVault = IPHANESLaunchSweep(launchEnablementVault_);

        blockedRecipient[phanes_] = true;
        blockedRecipient[primaryApprover_] = true;
        blockedRecipient[reviewerOne_] = true;
        blockedRecipient[reviewerTwo_] = true;
        blockedRecipient[founderVault_] = true;
        blockedRecipient[liquidityVault_] = true;
        blockedRecipient[reserveVault_] = true;
        blockedRecipient[launchEnablementVault_] = true;
        blockedRecipient[address(this)] = true;
    }

    function createCampaign(
        Category category,
        uint128 budget,
        uint128 maxPerClaim,
        uint16 maxClaimsPerWallet,
        uint64 startTime,
        uint64 endTime,
        bytes32 metadataHash
    ) external onlyPrimary returns (uint64 campaignId) {
        require(block.timestamp < rewardsExpiryTime, "Rewards: expired");
        require(startTime < endTime && endTime <= rewardsExpiryTime, "Rewards: schedule");
        require(budget != 0 && maxPerClaim != 0, "Rewards: zero amount");
        require(maxPerClaim <= ABSOLUTE_MAX_PER_CLAIM, "Rewards: absolute claim cap");
        if (category == Category.Technical) {
            require(maxPerClaim <= TECHNICAL_MAX_PER_CLAIM, "Rewards: technical claim cap");
        }
        require(maxPerClaim <= budget, "Rewards: cap > budget");
        require(maxClaimsPerWallet != 0, "Rewards: wallet claim cap zero");
        require(metadataHash != bytes32(0), "Rewards: metadata hash required");

        uint256 nextCommitted = totalCampaignBudgetCommitted + budget;
        require(nextCommitted <= phanes.balanceOf(address(this)), "Rewards: insufficient uncommitted balance");
        totalCampaignBudgetCommitted = nextCommitted;

        campaignId = ++campaignCount;
        campaigns[campaignId] = Campaign({
            category: category,
            budget: budget,
            approved: 0,
            paid: 0,
            maxPerClaim: maxPerClaim,
            maxClaimsPerWallet: maxClaimsPerWallet,
            startTime: startTime,
            endTime: endTime,
            metadataHash: metadataHash,
            finalized: false
        });

        emit CampaignCreated(campaignId, category, budget, maxPerClaim, maxClaimsPerWallet, startTime, endTime, metadataHash);
    }

    /// @notice Founder/project human approval. Approval grants no custody or generic transfer power.
    function approveClaim(
        uint64 campaignId,
        address recipient,
        bytes32 claimId,
        uint128 amount,
        bytes32 evidenceHash
    ) external onlyPrimary {
        require(block.timestamp < rewardsExpiryTime, "Rewards: expired");
        require(campaignId != 0 && campaignId <= campaignCount, "Rewards: campaign");
        Campaign storage c = campaigns[campaignId];
        require(block.timestamp >= c.startTime && block.timestamp <= c.endTime, "Rewards: inactive");
        require(recipient != address(0) && !blockedRecipient[recipient], "Rewards: blocked recipient");
        require(amount != 0 && amount <= c.maxPerClaim, "Rewards: amount");
        require(uint256(c.approved) + amount <= c.budget, "Rewards: campaign budget");
        if (c.category == Category.Technical) {
            require(amount <= TECHNICAL_MAX_PER_CLAIM, "Rewards: technical claim cap");
        }
        require(amount <= ABSOLUTE_MAX_PER_CLAIM, "Rewards: absolute claim cap");
        require(claimId != bytes32(0), "Rewards: claim id required");
        require(evidenceHash != bytes32(0), "Rewards: evidence hash required");
        require(!claimIdUsed[claimId], "Rewards: claim id used");

        uint16 priorClaims = walletClaimsInCampaign[campaignId][recipient];
        require(priorClaims < c.maxClaimsPerWallet, "Rewards: wallet claim cap");

        claimIdUsed[claimId] = true;
        walletClaimsInCampaign[campaignId][recipient] = priorClaims + 1;
        c.approved += amount;

        claims[claimId] = Claim({
            campaignId: campaignId,
            recipient: recipient,
            amount: amount,
            evidenceHash: evidenceHash,
            reviewerMask: 0,
            primaryApproved: true,
            claimed: false
        });

        emit RewardApproved(claimId, campaignId, recipient, amount, evidenceHash);
    }

    /// @notice Permissionlessly releases only unused campaign capacity after the campaign window ends.
    /// @dev Approved but unclaimed awards remain reserved and claimable until the immutable Rewards sunset.
    function finalizeCampaign(uint64 campaignId) external returns (uint256 unusedReleased) {
        require(!sunsetProcessed && block.timestamp < rewardsExpiryTime, "Rewards: programme ended");
        require(campaignId != 0 && campaignId <= campaignCount, "Rewards: campaign");
        Campaign storage c = campaigns[campaignId];
        require(block.timestamp > c.endTime, "Rewards: campaign active");
        require(!c.finalized, "Rewards: finalized");

        c.finalized = true;
        unusedReleased = uint256(c.budget) - uint256(c.approved);
        if (unusedReleased != 0) {
            totalCampaignBudgetCommitted -= unusedReleased;
        }

        uint256 outstandingApproved = uint256(c.approved) - uint256(c.paid);
        emit CampaignFinalized(campaignId, unusedReleased, outstandingApproved);
    }

    /// @notice Technical claims require reviewerOne; >50k non-technical awards require both independent reviewers.
    function requiredReviewerMask(bytes32 claimId) public view returns (uint8) {
        Claim storage cl = claims[claimId];
        if (!cl.primaryApproved) return type(uint8).max;
        Campaign storage c = campaigns[cl.campaignId];
        if (uint256(cl.amount) > ENHANCED_REVIEW_THRESHOLD) return 3; // reviewerOne + reviewerTwo
        if (c.category == Category.Technical) return 1; // reviewerOne
        return 0;
    }

    function reviewClaim(bytes32 claimId) external onlyReviewer {
        require(!sunsetProcessed && block.timestamp < rewardsExpiryTime, "Rewards: programme ended");
        Claim storage cl = claims[claimId];
        require(cl.primaryApproved && !cl.claimed, "Rewards: bad claim");
        uint8 required = requiredReviewerMask(claimId);
        require(required != 0 && required != type(uint8).max, "Rewards: review not required");

        uint8 bit = msg.sender == reviewerOne ? 1 : 2;
        require((required & bit) != 0, "Rewards: reviewer not required");
        require((cl.reviewerMask & bit) == 0, "Rewards: already reviewed");
        cl.reviewerMask |= bit;
        emit RewardReviewed(claimId, msg.sender, cl.reviewerMask);
    }

    function claimReward(bytes32 claimId) external {
        require(block.timestamp < rewardsExpiryTime, "Rewards: expired");
        Claim storage cl = claims[claimId];
        require(cl.primaryApproved && !cl.claimed, "Rewards: not claimable");
        require(msg.sender == cl.recipient, "Rewards: recipient only");
        uint8 required = requiredReviewerMask(claimId);
        require((cl.reviewerMask & required) == required, "Rewards: reviewer approvals missing");

        cl.claimed = true;
        Campaign storage c = campaigns[cl.campaignId];
        c.paid += cl.amount;
        totalCampaignBudgetCommitted -= cl.amount;
        phanes.protocolRewardTransfer(cl.recipient, cl.amount);
        emit RewardClaimed(claimId, cl.recipient, cl.amount);
    }

    /// @notice After the predetermined sunset, anyone may move all remaining Rewards PHN to protocol liquidity.
    /// @dev This is a one-way protocol destination, never a founder/public-sale path.
    function moveRemainingToLiquidityAfterExpiry() external returns (uint256 amount) {
        require(block.timestamp >= rewardsExpiryTime, "Rewards: not expired");
        require(!sunsetProcessed, "Rewards: sunset processed");

        // Defensive lifecycle closure: even if nobody triggered the permissionless
        // KHAOS Launch Vault sweep, force it home before Rewards itself sunsets.
        if (!launchEnablementVault.unusedReturned()) {
            launchEnablementVault.returnUnusedToRewards();
        }

        sunsetProcessed = true;
        totalCampaignBudgetCommitted = 0;
        amount = phanes.balanceOf(address(this));
        if (amount != 0) phanes.protocolRewardTransfer(liquidityVault, amount);
        emit RewardsSunsetLiquidity(amount);
    }

    function rewardTransparencyStatus() external view returns (
        uint256 vaultBalance,
        uint64 campaignsCreated,
        uint256 campaignBudgetCommitted,
        uint256 uncommittedVaultBalance,
        uint64 expiryTime
    ) {
        vaultBalance = phanes.balanceOf(address(this));
        campaignsCreated = campaignCount;
        campaignBudgetCommitted = totalCampaignBudgetCommitted;
        uint256 balance = phanes.balanceOf(address(this));
        uncommittedVaultBalance = balance > totalCampaignBudgetCommitted ? balance - totalCampaignBudgetCommitted : 0;
        expiryTime = rewardsExpiryTime;
    }

    // Deliberately no general withdrawal, rescue, sweep, delegatecall, upgrade or arbitrary-call function.
}

/// @title PHANES Core — production candidate
/// @notice Final pre-launch architecture: no buyer purchase cap, fixed issuance curve, 48-hour KHAOS transfer lock, then permanent full transferability.
/// @dev PRE-MAINNET PRODUCTION CANDIDATE. NOT AUDITED. DO NOT DEPLOY UNTIL RELEASE GATES ARE GREEN.
contract PHANES {
    string public constant name = "PHANES";
    string public constant symbol = "PHN";
    uint8 public constant decimals = 4;
    string public constant CONSTITUTION_VERSION = "PHANES-RC10-V0.8-2026-09-05";
    bytes32 public constant CONSTITUTION_SHA256 = 0x6c5f96f410cc3c84cf1e9dec8016de7e8c8efe59396e45db25c962c08b20808f;
    bytes32 public constant PARENT_RC7_CONSTITUTION_SHA256 = 0x3faccb66f3cd0c8e4c512cf0c4e7eb2b7511518da42acc2cbb88eb55eff5a01a;
    bytes32 public constant FROZEN_RC7_SOURCE_SHA256 = 0x541980787467de64d621299257d295d0a73847a1d08fe899d453e0bf53e84127;
    bytes32 public constant PARENT_RC8_SOURCE_SHA256 = 0xafc7f1a2898988af1209db65d9f0738d148255b53f7adcf6b74cee9b326e58e8;

    uint256 public constant UNIT = 10 ** decimals;
    uint256 public constant MAX_SUPPLY = 21_000_000 * UNIT;
    uint256 public constant PUBLIC_ALLOCATION = 17_000_000 * UNIT;
    uint256 public constant LIQUIDITY_ALLOCATION = 2_000_000 * UNIT;
    uint256 public constant FOUNDER_ALLOCATION = 1_000_000 * UNIT;
    uint256 public constant REWARDS_ALLOCATION = 750_000 * UNIT;
    uint256 public constant LAUNCH_ENABLEMENT_ALLOCATION = 250_000 * UNIT;

    uint256 public constant KHAOS_ALLOCATION = 5_000_000 * UNIT;
    uint256 public constant CHRONOS_ALLOCATION = 4_500_000 * UNIT;
    uint256 public constant ANANKE_ALLOCATION = 4_000_000 * UNIT;
    uint256 public constant AITHER_ALLOCATION = 3_500_000 * UNIT;

    // Global fair-access envelope: 20% immediately, 80% linear over 48 hours.
    // No per-transaction or cumulative per-wallet public purchase cap.
    uint256 public constant OPENING_FRACTION_NUMERATOR = 1;
    uint256 public constant OPENING_FRACTION_DENOMINATOR = 5;
    uint256 public constant FAIR_ACCESS_STREAM_DURATION = 48 hours;

    // Production UTC gates: about 17.4 months of primary issuance, anchored to KHAOS on 21 Dec 2026.
    uint64 public constant KHAOS_START = 1_797_886_200;    // 21 Dec 2026 20:50
    uint64 public constant CHRONOS_START = 1_808_427_000;  // 22 Apr 2027 20:50
    uint64 public constant ANANKE_START = 1_819_054_200;   // 23 Aug 2027 20:50
    uint64 public constant AITHER_START = 1_829_508_600;   // 22 Dec 2027 20:50
    uint64 public constant OION_START = 1_840_049_400;     // 22 Apr 2028 20:50
    uint64 public constant OION_CLOSE = 1_843_714_740;     // 04 Jun 2028 06:59

    // Secondary-transfer gate is deliberately separate from primary issuance.
    // PHN is non-transferable only for the first 48 hours of KHAOS. At the boundary,
    // transfer(), approve() and transferFrom() become fully and permanently available.
    uint64 public constant TRANSFER_RELEASE_START = 1_798_059_000; // 23 Dec 2026 20:50 UTC
    uint64 public constant SECONDARY_TRADING_START = TRANSFER_RELEASE_START;
    uint64 public constant FULL_TRANSFERABILITY_TIME = TRANSFER_RELEASE_START;

    // Mythic state sequencing continues after primary issuance, but this is NOT a holder unlock.
    uint64 public constant FINAL_SEAL_START = OION_CLOSE;               // 04 Jun 2028 06:59 UTC
    uint64 public constant EMERGENCE_TIME = 1_853_268_600;              // 22 Sep 2028 20:50 UTC
    uint256 public constant BPS = 10_000;
    uint256 private constant TRANSFER_SCALE = 1e18;

    // P(x) = 0.01 + 0.023820x + 0.086180x^2; price units are micro-USDC per whole PHN.
    // The terminal primary-issuance quote is $0.12 when x = 1 (17m public PHN acquired).
    uint256 private constant PRICE_A = 10_000;
    uint256 private constant PRICE_B = 23_820;
    uint256 private constant PRICE_C = 86_180;
    uint256 private constant WAD = 1e18;

    enum PublicState {
        PRELAUNCH,
        ACTIVE,
        SEALED,
        OION_ACTIVE,
        OION_SEALED,
        FINAL_SEAL,
        EMERGED,
        ABORTED
    }

    IERC20Payment public immutable paymentToken;
    address public immutable founder;
    address public immutable releaseReviewerOne;
    address public immutable releaseReviewerTwo;
    PHANESLiquidityVault public immutable liquidityVault;
    PHANESReserveVault public immutable reserveVault;
    PHANESFounderVault public immutable founderVault;
    PHANESLaunchEnablementVault public immutable launchEnablementVault;
    PHANESRewardsVault public immutable rewardsVault;

    uint256 public totalSupply;
    uint256 public publicSold;
    uint256 public totalPaymentCommitted;
    uint256[4] public normalEpochSold;
    uint256 public oionSold;
    uint256 public finalPublicReserve;
    bool public publicIssuanceFinalized;
    bool private entered;

    // One-way pre-KHAOS release safety. A deployment is inert unless explicitly sealed for release.
    bool public launchArmed;
    bool public launchAborted;
    bytes32 public releaseManifestHash;
    uint8 public releaseApprovalMask;
    bytes32 public abortReasonHash;
    uint8 public abortApprovalMask;
    uint8 private constant RELEASE_ALL_APPROVALS = 7; // founder + reviewerOne + reviewerTwo

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice Transparency ledger of PHN delivered before the 23 Dec 2026 transfer opening.
    /// @dev It no longer imposes staged vesting after the gate opens; all wallet balance becomes transferable at once.
    mapping(address => uint256) public scheduledAllocation;
    /// @notice Retained for interface/history compatibility; v0.8 does not consume staged allocation after the gate opens.
    mapping(address => uint256) public scheduledAllocationSpent;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Purchased(
        address indexed buyer,
        uint8 indexed issuanceStage,
        uint256 paymentSpent,
        uint256 phanesReceived,
        uint256 cumulativePublicSold,
        uint256 newIssuancePrice
    );
    event ScheduledAllocationRecorded(address indexed wallet, uint256 amount, uint256 cumulativeAllocation);
    event ScheduledAllocationSpent(address indexed wallet, uint256 amount, uint256 cumulativeSpent);
    event PublicIssuanceFinalized(uint256 unsoldPublicReserved, uint256 finalTotalSupply, uint256 finalPublicSold);
    event ConstitutionDeclared(
        bytes32 indexed sha256,
        string version,
        uint256 maxSupply,
        uint256 publicAllocation,
        uint256 liquidityAllocation,
        uint256 founderAllocation,
        uint256 rewardsAllocation,
        uint256 launchEnablementAllocation
    );
    event ReleaseManifestApproved(bytes32 indexed manifestHash, address indexed signer, uint8 resultingMask);
    event LaunchArmed(bytes32 indexed manifestHash);
    event LaunchAbortApproved(bytes32 indexed reasonHash, address indexed signer, uint8 resultingMask);
    event LaunchAborted(bytes32 indexed reasonHash);

    error TransfersLocked();
    error SaleNotOpen();
    error SaleClosed();
    error PaymentTooSmall();
    error Reentrancy();
    error ZeroAddress();
    error TransferFailed();
    error PaymentMismatch();
    error PaymentTokenHasNoCode();
    error QuoteExpired();
    error SlippageExceeded();
    error InvalidIssuanceStage();
    error TransferAmountLocked(uint256 requested, uint256 transferable);
    error RewardsOnly();
    error FounderOnly();
    error ReserveOnly();
    error LaunchOnly();
    error InventoryInvariant();
    error IssuanceStageChanged();
    error ReleaseSignerOnly();
    error ReleaseSafetyClosed();
    error ReleaseManifestMismatch();
    error ReleaseAlreadyApproved();
    error ReleaseNotArmed();
    error ReleaseAborted();
    error ReleaseApprovalIncomplete();
    error ZeroFingerprint();

    modifier nonReentrant() {
        if (entered) revert Reentrancy();
        entered = true;
        _;
        entered = false;
    }

    constructor(
        address paymentToken_,
        address founder_,
        address reviewerOne_,
        address reviewerTwo_,
        uint64 rewardsExpiryTime_
    ) {
        if (
            paymentToken_ == address(0) ||
            founder_ == address(0) ||
            reviewerOne_ == address(0) ||
            reviewerTwo_ == address(0)
        ) revert ZeroAddress();
        if (paymentToken_.code.length == 0) revert PaymentTokenHasNoCode();
        if (founder_ == reviewerOne_ || founder_ == reviewerTwo_ || reviewerOne_ == reviewerTwo_) revert ReleaseSignerOnly();

        paymentToken = IERC20Payment(paymentToken_);
        founder = founder_;
        releaseReviewerOne = reviewerOne_;
        releaseReviewerTwo = reviewerTwo_;

        PHANESLiquidityVault lq = new PHANESLiquidityVault(address(this), paymentToken_);
        PHANESReserveVault rs = new PHANESReserveVault(address(this), address(lq));
        PHANESFounderVault fv = new PHANESFounderVault(address(this), founder_);
        PHANESLaunchEnablementVault lv = new PHANESLaunchEnablementVault(
            address(this),
            founder_,
            reviewerOne_,
            reviewerTwo_
        );
        PHANESRewardsVault rv = new PHANESRewardsVault(
            address(this),
            founder_,
            reviewerOne_,
            reviewerTwo_,
            rewardsExpiryTime_,
            address(fv),
            address(lq),
            address(rs),
            address(lv)
        );

        liquidityVault = lq;
        reserveVault = rs;
        founderVault = fv;
        launchEnablementVault = lv;
        rewardsVault = rv;

        totalSupply = MAX_SUPPLY;
        balanceOf[address(this)] = PUBLIC_ALLOCATION;
        balanceOf[address(lq)] = LIQUIDITY_ALLOCATION;
        balanceOf[address(fv)] = FOUNDER_ALLOCATION;
        balanceOf[address(rv)] = REWARDS_ALLOCATION;
        balanceOf[address(lv)] = LAUNCH_ENABLEMENT_ALLOCATION;

        emit Transfer(address(0), address(this), PUBLIC_ALLOCATION);
        emit Transfer(address(0), address(lq), LIQUIDITY_ALLOCATION);
        emit Transfer(address(0), address(fv), FOUNDER_ALLOCATION);
        emit Transfer(address(0), address(rv), REWARDS_ALLOCATION);
        emit Transfer(address(0), address(lv), LAUNCH_ENABLEMENT_ALLOCATION);
        emit ConstitutionDeclared(
            CONSTITUTION_SHA256,
            CONSTITUTION_VERSION,
            MAX_SUPPLY,
            PUBLIC_ALLOCATION,
            LIQUIDITY_ALLOCATION,
            FOUNDER_ALLOCATION,
            REWARDS_ALLOCATION,
            LAUNCH_ENABLEMENT_ALLOCATION
        );
    }

    // -------------------------------------------------------------------------
    // One-way pre-KHAOS release safety
    // -------------------------------------------------------------------------

    function _releaseSignerBit(address signer) internal view returns (uint8 bit) {
        if (signer == founder) return 1;
        if (signer == releaseReviewerOne) return 2;
        if (signer == releaseReviewerTwo) return 4;
        revert ReleaseSignerOnly();
    }

    function approveReleaseManifest(bytes32 manifestHash) external {
        if (block.timestamp >= KHAOS_START || launchArmed || launchAborted) revert ReleaseSafetyClosed();
        if (manifestHash == bytes32(0)) revert ZeroFingerprint();
        if (releaseManifestHash == bytes32(0)) releaseManifestHash = manifestHash;
        else if (releaseManifestHash != manifestHash) revert ReleaseManifestMismatch();

        uint8 bit = _releaseSignerBit(msg.sender);
        if ((releaseApprovalMask & bit) != 0) revert ReleaseAlreadyApproved();
        releaseApprovalMask |= bit;
        emit ReleaseManifestApproved(manifestHash, msg.sender, releaseApprovalMask);
    }

    /// @notice Permissionless execution once all three independent release signers approved one exact manifest.
    /// @dev Arming is irreversible. No signer can alter economics, timestamps, supply or payment destinations.
    function armLaunch(bytes32 manifestHash) external {
        if (block.timestamp >= KHAOS_START || launchArmed || launchAborted) revert ReleaseSafetyClosed();
        if (manifestHash == bytes32(0) || releaseManifestHash != manifestHash) revert ReleaseManifestMismatch();
        if (releaseApprovalMask != RELEASE_ALL_APPROVALS) revert ReleaseApprovalIncomplete();
        launchArmed = true;
        emit LaunchArmed(manifestHash);
    }

    function approveLaunchAbort(bytes32 reasonHash) external {
        if (block.timestamp >= KHAOS_START || launchAborted) revert ReleaseSafetyClosed();
        if (reasonHash == bytes32(0)) revert ZeroFingerprint();
        if (abortReasonHash == bytes32(0)) abortReasonHash = reasonHash;
        else if (abortReasonHash != reasonHash) revert ReleaseManifestMismatch();

        uint8 bit = _releaseSignerBit(msg.sender);
        if ((abortApprovalMask & bit) != 0) revert ReleaseAlreadyApproved();
        abortApprovalMask |= bit;
        emit LaunchAbortApproved(reasonHash, msg.sender, abortApprovalMask);
    }

    /// @notice Permanently kills this deployment before KHAOS after any two release signers approve one reason hash.
    /// @dev Moves no PHN or payment token, cannot be reversed, and cannot execute at/after KHAOS.
    function executeLaunchAbort(bytes32 reasonHash) external {
        if (block.timestamp >= KHAOS_START || launchAborted) revert ReleaseSafetyClosed();
        if (reasonHash == bytes32(0) || abortReasonHash != reasonHash) revert ReleaseManifestMismatch();
        uint8 mask = abortApprovalMask;
        uint8 approvals = (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1);
        if (approvals < 2) revert ReleaseApprovalIncomplete();
        launchAborted = true;
        launchArmed = false;
        emit LaunchAborted(reasonHash);
    }

    function releaseSafetyStatus() external view returns (
        bool armed,
        bool aborted,
        bytes32 manifestHash,
        uint8 manifestApprovals,
        bytes32 reasonHash,
        uint8 abortApprovals
    ) {
        return (launchArmed, launchAborted, releaseManifestHash, releaseApprovalMask, abortReasonHash, abortApprovalMask);
    }

    function _requireLiveDeployment() internal view {
        if (launchAborted) revert ReleaseAborted();
        if (!launchArmed) revert ReleaseNotArmed();
    }

    // -------------------------------------------------------------------------
    // ERC-20 style public interface
    // -------------------------------------------------------------------------

    function approve(address spender, uint256 value) external returns (bool) {
        _requireLiveDeployment();
        if (block.timestamp < TRANSFER_RELEASE_START) revert TransfersLocked();
        if (block.timestamp >= OION_CLOSE) _finalizeIfNeeded();
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _requireLiveDeployment();
        if (block.timestamp < TRANSFER_RELEASE_START) revert TransfersLocked();
        if (block.timestamp >= OION_CLOSE) _finalizeIfNeeded();
        _consumeTransferable(msg.sender, value);
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        _requireLiveDeployment();
        if (block.timestamp < TRANSFER_RELEASE_START) revert TransfersLocked();
        if (block.timestamp >= OION_CLOSE) _finalizeIfNeeded();
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "PHN: allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _consumeTransferable(from, value);
        _transfer(from, to, value);
        return true;
    }

    /// @notice Cumulative holder-transfer fraction, scaled to 1e18.
    /// @dev v0.8 deliberately has one transfer boundary: 0 before 23 Dec 2026 20:50 UTC, 100% at/after it.
    function transferUnlockWadAt(uint256 timestamp) public pure returns (uint256) {
        return timestamp < TRANSFER_RELEASE_START ? 0 : TRANSFER_SCALE;
    }

    function transferUnlockWad() public view returns (uint256) {
        return transferUnlockWadAt(block.timestamp);
    }

    function transferUnlockBpsAt(uint256 timestamp) public pure returns (uint256) {
        return timestamp < TRANSFER_RELEASE_START ? 0 : BPS;
    }

    function transferUnlockBps() public view returns (uint256) {
        return transferUnlockBpsAt(block.timestamp);
    }

    /// @notice Returns the only holder-transfer gate while it is still in the future.
    function nextTransferMilestoneTimestamp() public view returns (uint64) {
        return block.timestamp < TRANSFER_RELEASE_START ? TRANSFER_RELEASE_START : 0;
    }

    function nextTransferUnlockTimestamp() public view returns (uint64) {
        return nextTransferMilestoneTimestamp();
    }

    /// @notice Amount from the pre-opening allocation ledger that is transfer-eligible at a timestamp.
    function scheduledVestedAmount(address wallet, uint256 timestamp) public view returns (uint256) {
        return timestamp < TRANSFER_RELEASE_START ? 0 : scheduledAllocation[wallet];
    }

    /// @notice Amount a wallet can transfer now. Once the 48-hour KHAOS gate ends, the full balance is transferable.
    function transferableBalance(address wallet) public view returns (uint256) {
        if (block.timestamp < TRANSFER_RELEASE_START) return 0;
        return balanceOf[wallet];
    }

    function _recordScheduledAllocation(address wallet, uint256 value) internal {
        if (value == 0 || block.timestamp >= TRANSFER_RELEASE_START) return;
        uint256 cumulative = scheduledAllocation[wallet] + value;
        scheduledAllocation[wallet] = cumulative;
        emit ScheduledAllocationRecorded(wallet, value, cumulative);
    }

    function _consumeTransferable(address wallet, uint256 value) internal view {
        uint256 available = transferableBalance(wallet);
        if (value > available) revert TransferAmountLocked(value, available);
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf[from];
        require(bal >= value, "PHN: balance");
        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }

    // -------------------------------------------------------------------------
    // Narrow Rewards Vault bypass
    // -------------------------------------------------------------------------

    function protocolRewardTransfer(address to, uint256 value) external {
        if (msg.sender != address(rewardsVault)) revert RewardsOnly();
        _requireLiveDeployment();
        if (to != address(liquidityVault)) _recordScheduledAllocation(to, value);
        _transfer(address(rewardsVault), to, value);
    }

    function protocolFounderTransfer(address to, uint256 value) external {
        if (msg.sender != address(founderVault)) revert FounderOnly();
        _requireLiveDeployment();
        if (to != founder) revert FounderOnly();
        // Founder tranche delivery follows the epoch schedule. The wallet cannot transfer before the shared 23 Dec 2026 gate.
        _transfer(address(founderVault), to, value);
    }

    function protocolReserveTransfer(address to, uint256 value) external {
        if (msg.sender != address(reserveVault)) revert ReserveOnly();
        _requireLiveDeployment();
        if (to != address(liquidityVault)) revert ReserveOnly();
        _transfer(address(reserveVault), to, value);
    }

    // -------------------------------------------------------------------------
    // Narrow Launch Enablement Vault bypass
    // -------------------------------------------------------------------------

    function protocolLaunchPartnerTransfer(address to, uint256 value) external {
        if (msg.sender != address(launchEnablementVault)) revert LaunchOnly();
        if (launchAborted) revert ReleaseAborted();
        if (block.timestamp >= KHAOS_START) revert LaunchOnly();
        if (to == address(0) || to == founder || to == address(launchEnablementVault)) revert LaunchOnly();
        _recordScheduledAllocation(to, value);
        _transfer(address(launchEnablementVault), to, value);
    }

    function protocolLaunchReturnToRewards(uint256 value) external {
        if (msg.sender != address(launchEnablementVault)) revert LaunchOnly();
        if (block.timestamp < KHAOS_START) revert LaunchOnly();
        _transfer(address(launchEnablementVault), address(rewardsVault), value);
    }

    function _sweepLaunchUnusedIfNeeded() internal {
        if (block.timestamp >= KHAOS_START && !launchEnablementVault.unusedReturned()) {
            launchEnablementVault.returnUnusedToRewards();
        }
    }

    // -------------------------------------------------------------------------
    // Inherited state machine + fair-access envelope
    // -------------------------------------------------------------------------

    function normalEpochAllocation(uint8 epoch) public pure returns (uint256) {
        if (epoch == 0) return KHAOS_ALLOCATION;
        if (epoch == 1) return CHRONOS_ALLOCATION;
        if (epoch == 2) return ANANKE_ALLOCATION;
        if (epoch == 3) return AITHER_ALLOCATION;
        revert("PHN: epoch");
    }

    function normalEpochStart(uint8 epoch) public pure returns (uint64) {
        if (epoch == 0) return KHAOS_START;
        if (epoch == 1) return CHRONOS_START;
        if (epoch == 2) return ANANKE_START;
        if (epoch == 3) return AITHER_START;
        revert("PHN: epoch");
    }

    function normalEpochEnd(uint8 epoch) public pure returns (uint64) {
        if (epoch == 0) return CHRONOS_START;
        if (epoch == 1) return ANANKE_START;
        if (epoch == 2) return AITHER_START;
        if (epoch == 3) return OION_START;
        revert("PHN: epoch");
    }

    /// @notice Maximum amount of a normal epoch that time has made purchasable.
    /// @dev 20% is available at the opening block; the remaining 80% accrues linearly for 48 hours.
    ///      After 48 hours the full unsold epoch inventory remains available until the exact epoch boundary.
    function normalEpochTimeEligible(uint8 epoch, uint256 timestamp) public pure returns (uint256) {
        uint256 start = normalEpochStart(epoch);
        uint256 allocation = normalEpochAllocation(epoch);
        if (timestamp < start) return 0;

        uint256 opening = (allocation * OPENING_FRACTION_NUMERATOR) / OPENING_FRACTION_DENOMINATOR;
        uint256 elapsed = timestamp - start;
        if (elapsed >= FAIR_ACCESS_STREAM_DURATION) return allocation;

        uint256 streamed = allocation - opening;
        return opening + (streamed * elapsed) / FAIR_ACCESS_STREAM_DURATION;
    }

    function normalEpochCurrentlyPurchasable(uint8 epoch) public view returns (uint256) {
        if (block.timestamp < normalEpochStart(epoch) || block.timestamp >= normalEpochEnd(epoch)) return 0;
        uint256 eligible = normalEpochTimeEligible(epoch, block.timestamp);
        uint256 sold = normalEpochSold[epoch];
        return eligible > sold ? eligible - sold : 0;
    }

    function activeNormalEpoch() public view returns (uint8) {
        uint256 t = block.timestamp;
        if (t >= KHAOS_START && t < CHRONOS_START) return 0;
        if (t >= CHRONOS_START && t < ANANKE_START) return 1;
        if (t >= ANANKE_START && t < AITHER_START) return 2;
        if (t >= AITHER_START && t < OION_START) return 3;
        return type(uint8).max;
    }

    function oionAccumulated() public view returns (uint256 amount) {
        uint256 t = block.timestamp;
        for (uint8 i = 0; i < 4; ++i) {
            if (t >= normalEpochEnd(i)) {
                amount += normalEpochAllocation(i) - normalEpochSold[i];
            }
        }
    }

    function finalOionAllocation() public view returns (uint256) {
        if (block.timestamp < OION_START) return 0;
        return
            (KHAOS_ALLOCATION - normalEpochSold[0]) +
            (CHRONOS_ALLOCATION - normalEpochSold[1]) +
            (ANANKE_ALLOCATION - normalEpochSold[2]) +
            (AITHER_ALLOCATION - normalEpochSold[3]);
    }

    function oionRemaining() public view returns (uint256) {
        uint256 allocation = finalOionAllocation();
        return allocation > oionSold ? allocation - oionSold : 0;
    }

    function protocolState() public view returns (PublicState) {
        uint256 t = block.timestamp;
        if (launchAborted) return PublicState.ABORTED;
        if (t < KHAOS_START) return PublicState.PRELAUNCH;
        if (!launchArmed) return PublicState.ABORTED;

        uint8 e = activeNormalEpoch();
        if (e != type(uint8).max) {
            return normalEpochSold[e] < normalEpochAllocation(e) ? PublicState.ACTIVE : PublicState.SEALED;
        }

        if (t >= OION_START && t < OION_CLOSE) {
            uint256 allocation = finalOionAllocation();
            if (allocation == 0 || oionSold >= allocation) return PublicState.OION_SEALED;
            return PublicState.OION_ACTIVE;
        }

        if (t >= OION_CLOSE && t < EMERGENCE_TIME) return PublicState.FINAL_SEAL;
        return PublicState.EMERGED;
    }

    function nextStateTimestamp() public view returns (uint64) {
        PublicState s = protocolState();
        if (s == PublicState.PRELAUNCH) return KHAOS_START;
        if (s == PublicState.ACTIVE || s == PublicState.SEALED) {
            uint8 e = activeNormalEpoch();
            return normalEpochEnd(e);
        }
        if (s == PublicState.OION_ACTIVE || s == PublicState.OION_SEALED) return OION_CLOSE;
        if (s == PublicState.FINAL_SEAL) return EMERGENCE_TIME;
        if (s == PublicState.ABORTED) return 0;
        return 0;
    }

    /// @notice Returns the active purchasable issuance stage: 0-3 normal epochs, 4 OION, 255 otherwise.
    function currentIssuanceStage() public view returns (uint8) {
        PublicState s = protocolState();
        if (s == PublicState.ACTIVE) return activeNormalEpoch();
        if (s == PublicState.OION_ACTIVE) return 4;
        return type(uint8).max;
    }



    // -------------------------------------------------------------------------
    // Public issuance
    // -------------------------------------------------------------------------

    function buy(uint8 expectedStage, uint256 maxPaymentAmount, uint256 minPhanesReceived, uint64 deadline)
        external
        nonReentrant
        returns (uint256 paymentSpent, uint256 phanesReceived)
    {
        _requireLiveDeployment();
        _sweepLaunchUnusedIfNeeded();
        if (block.timestamp > deadline) revert QuoteExpired();
        uint8 liveStage = currentIssuanceStage();
        if (liveStage != expectedStage) revert IssuanceStageChanged();
        PublicState s = protocolState();
        if (s != PublicState.ACTIVE && s != PublicState.OION_ACTIVE) revert SaleNotOpen();
        if (publicIssuanceFinalized || block.timestamp >= OION_CLOSE) revert SaleClosed();

        uint256 remaining;
        uint8 stage;
        uint8 e = activeNormalEpoch();
        if (s == PublicState.ACTIVE) {
            stage = e;
            remaining = normalEpochCurrentlyPurchasable(e);
        } else {
            stage = 4; // OION
            remaining = oionRemaining();
        }

        (phanesReceived, paymentSpent) = _quoteWithinLimit(maxPaymentAmount, remaining);
        if (phanesReceived == 0 || paymentSpent == 0) revert PaymentTooSmall();
        if (phanesReceived < minPhanesReceived) revert SlippageExceeded();

        publicSold += phanesReceived;
        if (s == PublicState.ACTIVE) normalEpochSold[e] += phanesReceived;
        else oionSold += phanesReceived;
        totalPaymentCommitted += paymentSpent;

        address destination = address(liquidityVault);
        uint256 beforeBalance = paymentToken.balanceOf(destination);
        bool ok = paymentToken.transferFrom(msg.sender, destination, paymentSpent);
        if (!ok) revert TransferFailed();
        uint256 afterBalance = paymentToken.balanceOf(destination);
        if (afterBalance - beforeBalance != paymentSpent) revert PaymentMismatch();

        // Internal issuance delivery records the allocation before bypassing the public transfer gate.
        _recordScheduledAllocation(msg.sender, phanesReceived);
        _transfer(address(this), msg.sender, phanesReceived);

        emit Purchased(msg.sender, stage, paymentSpent, phanesReceived, publicSold, currentIssuancePrice());
    }

    function quote(uint256 maxPaymentAmount) external view returns (uint256 paymentSpent, uint256 phanesReceived) {
        if (!launchArmed || launchAborted) return (0, 0);
        PublicState s = protocolState();
        if (s != PublicState.ACTIVE && s != PublicState.OION_ACTIVE) return (0, 0);
        if (publicIssuanceFinalized || block.timestamp >= OION_CLOSE) return (0, 0);

        uint256 remaining;
        if (s == PublicState.ACTIVE) {
            uint8 e = activeNormalEpoch();
            remaining = normalEpochCurrentlyPurchasable(e);
        } else {
            remaining = oionRemaining();
        }
        (phanesReceived, paymentSpent) = _quoteWithinLimit(maxPaymentAmount, remaining);
    }

    /// @notice Stage-bound quote for frontends that want the quote and transaction to share the same epoch identity.
    function quoteForStage(uint8 expectedStage, uint256 maxPaymentAmount)
        external
        view
        returns (uint256 paymentSpent, uint256 phanesReceived)
    {
        if (currentIssuanceStage() != expectedStage) return (0, 0);
        PublicState s = protocolState();
        if (s != PublicState.ACTIVE && s != PublicState.OION_ACTIVE) return (0, 0);
        if (publicIssuanceFinalized || block.timestamp >= OION_CLOSE) return (0, 0);

        uint256 remaining;
        if (s == PublicState.ACTIVE) {
            uint8 e = activeNormalEpoch();
            remaining = normalEpochCurrentlyPurchasable(e);
        } else {
            remaining = oionRemaining();
        }
        (phanesReceived, paymentSpent) = _quoteWithinLimit(maxPaymentAmount, remaining);
    }

    function _quoteWithinLimit(uint256 maxPaymentAmount, uint256 maxTokenUnits)
        internal
        view
        returns (uint256 tokenUnits, uint256 paymentAmount)
    {
        if (maxPaymentAmount == 0 || maxTokenUnits == 0) return (0, 0);
        uint256 fullCost = costBetween(publicSold, publicSold + maxTokenUnits);
        if (fullCost <= maxPaymentAmount) return (maxTokenUnits, fullCost);

        uint256 low;
        uint256 high = maxTokenUnits;
        while (low < high) {
            uint256 mid = low + (high - low + 1) / 2;
            uint256 c = costBetween(publicSold, publicSold + mid);
            if (c <= maxPaymentAmount) low = mid;
            else high = mid - 1;
        }
        tokenUnits = low;
        paymentAmount = costBetween(publicSold, publicSold + tokenUnits);
    }

    // -------------------------------------------------------------------------
    // Immutable price curve
    // -------------------------------------------------------------------------

    function currentIssuancePrice() public view returns (uint256) {
        uint256 x = (publicSold * WAD) / PUBLIC_ALLOCATION;
        uint256 linear = (PRICE_B * x) / WAD;
        uint256 quadratic = (((PRICE_C * x) / WAD) * x) / WAD;
        return PRICE_A + linear + quadratic;
    }

    function cumulativeCost(uint256 q) public pure returns (uint256) {
        require(q <= PUBLIC_ALLOCATION, "PHN: q > public");
        uint256 term1 = (PRICE_A * q) / UNIT;
        uint256 term2 = (PRICE_B * q * q) / (2 * PUBLIC_ALLOCATION * UNIT);
        uint256 term3 = (PRICE_C * q * q * q) / (3 * PUBLIC_ALLOCATION * PUBLIC_ALLOCATION * UNIT);
        return term1 + term2 + term3;
    }

    function costBetween(uint256 fromQ, uint256 toQ) public pure returns (uint256) {
        require(fromQ <= toQ && toQ <= PUBLIC_ALLOCATION, "PHN: range");
        return cumulativeCost(toQ) - cumulativeCost(fromQ);
    }

    // -------------------------------------------------------------------------
    // Final public Reserve sealing / post-primary state
    // -------------------------------------------------------------------------

    function finalizePublicIssuance() external returns (uint256 reserved) {
        _sweepLaunchUnusedIfNeeded();
        if (block.timestamp < OION_CLOSE) revert SaleClosed();
        reserved = _finalizePublicIssuance();
    }

    function _finalizeIfNeeded() internal {
        if (!publicIssuanceFinalized) _finalizePublicIssuance();
    }

    function _finalizePublicIssuance() internal returns (uint256 reserved) {
        if (publicIssuanceFinalized) return 0;
        if (block.timestamp < OION_CLOSE) revert SaleClosed();

        reserved = PUBLIC_ALLOCATION - publicSold;
        if (balanceOf[address(this)] != reserved) revert InventoryInvariant();

        publicIssuanceFinalized = true;
        finalPublicReserve = reserved;
        if (reserved != 0) _transfer(address(this), address(reserveVault), reserved);
        reserveVault.sealReserve(reserved);

        emit PublicIssuanceFinalized(reserved, totalSupply, publicSold);
    }

    // -------------------------------------------------------------------------
    // Transparency reads
    // -------------------------------------------------------------------------

    function economicTransparencyStatus() external view returns (
        uint256 supply,
        uint256 sold,
        uint256 saleInventoryRemaining,
        uint256 committedPayment,
        uint256 liveIssuancePrice,
        bool finalized,
        uint256 reserved
    ) {
        supply = totalSupply;
        sold = publicSold;
        saleInventoryRemaining = balanceOf[address(this)];
        committedPayment = totalPaymentCommitted;
        liveIssuancePrice = currentIssuancePrice();
        finalized = publicIssuanceFinalized;
        reserved = finalPublicReserve;
    }

    function stateTransparencyStatus() external view returns (
        PublicState state,
        uint8 normalEpoch,
        uint64 nextTimestamp,
        uint256 currentStageSold,
        uint256 currentStageAllocation,
        uint256 rolledToOion,
        uint256 finalOionTotal,
        uint256 finalOionSold
    ) {
        state = protocolState();
        normalEpoch = activeNormalEpoch();
        nextTimestamp = nextStateTimestamp();
        rolledToOion = oionAccumulated();
        finalOionTotal = finalOionAllocation();
        finalOionSold = oionSold;

        if (state == PublicState.ACTIVE || state == PublicState.SEALED) {
            currentStageSold = normalEpochSold[normalEpoch];
            currentStageAllocation = normalEpochAllocation(normalEpoch);
        } else if (state == PublicState.OION_ACTIVE || state == PublicState.OION_SEALED) {
            currentStageSold = oionSold;
            currentStageAllocation = finalOionTotal;
        }
    }

    function vaultTransparencyStatus() external view returns (
        uint256 liquidityPhnBalance,
        uint256 liquidityPaymentBalance,
        uint256 founderVaultPhnBalance,
        uint256 rewardsVaultPhnBalance,
        uint256 reserveVaultPhnBalance
    ) {
        liquidityPhnBalance = balanceOf[address(liquidityVault)];
        liquidityPaymentBalance = paymentToken.balanceOf(address(liquidityVault));
        founderVaultPhnBalance = balanceOf[address(founderVault)];
        rewardsVaultPhnBalance = balanceOf[address(rewardsVault)];
        reserveVaultPhnBalance = balanceOf[address(reserveVault)];
    }

    // Intentionally NO owner(), NO mint(), NO setPrice(), NO manual epoch release(),
    // NO pause(), NO upgrade(), NO developer payment withdrawal(), NO protocol burn(), and NO public-inventory rescue().
}
