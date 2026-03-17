# Crowdfund Protocol Specification

## Vision

The de facto permissionless crowdfunding platform on Ethereum. A fully immutable, trustless protocol where anyone can create a fundraising campaign and anyone can invest — with built-in economic guarantees that protect backers through dominant assurance mechanics.

**Target Chains:** Ethereum Mainnet, Monad. No L2s.

---

## Core Concept

This protocol implements **Dominant Assurance Contracts** — a game-theoretic improvement on traditional crowdfunding where backers are economically incentivized to participate because they are guaranteed a profit if the campaign fails. Unlike platforms like Kickstarter where failed campaigns simply return funds, this protocol pays backers a **refund plus interest** on failure, making participation a weakly dominant strategy.

---

## Protocol Architecture

### Contracts

1. **CrowdfundFactory** — Singleton factory that deploys Campaign contracts. Immutable. Tracks all campaigns. Entry point for the protocol.

2. **Campaign** — One contract per campaign. Holds contributed funds and manages the lifecycle: active → settled (successful or failed). Handles refund + interest distribution on failure, creator withdrawal on success.

3. **Treasury** — Receives protocol fees from successful campaigns. Holds funds for protocol operations. Controlled by a configurable admin address (can be a multisig or governance contract).

### Contract Relationships

```
User → CrowdfundFactory.createCampaign() → deploys Campaign (free, no ETH required)
User → Campaign.contribute{value: X}()   → sends ETH, 25bps deducted as fee
Anyone → Campaign.settle()               → finalizes after deadline
  ├─ Success → Creator calls creatorWithdraw() → raised funds to creator, fee pool to Treasury
  └─ Failure → Backers call claimRefund()      → net refund + proportional interest from fee pool
```

---

## Fee Model

- **Protocol fee: 25 basis points (0.25%)** deducted from every contribution transaction
- Campaign creation is **free** (gas only) — no upfront deposit required from the creator
- The fee accumulates in a `feePool` within each Campaign contract
- **On success:** The fee pool is sent to the Treasury for protocol operations
- **On failure:** The fee pool is distributed proportionally to backers as **interest** — this IS the dominant assurance mechanism

### Fee Flow

```
Backer contributes 10 ETH to a campaign:
  → Fee: 10 ETH × 0.25% = 0.025 ETH → added to feePool
  → Net contribution: 9.975 ETH → added to totalRaised
  → Contribution record stores 9.975 ETH (net amount)

If campaign SUCCEEDS (totalRaised ≥ fundingGoal):
  → Creator receives: totalRaised (sum of all net contributions)
  → Treasury receives: feePool (sum of all 25bps fees)
  → Backers: funded the project they believed in

If campaign FAILS (totalRaised < fundingGoal):
  → Each backer receives: netContribution + (netContribution / totalRaised) × feePool
  → Treasury receives: nothing
  → Creator: nothing happens (they never deposited anything)
```

### Why This Works (Game Theory)

Backers face a weakly dominant strategy: participate in any campaign you find interesting. If it succeeds, you funded something worthwhile. If it fails, you get your money back plus interest funded by the collective fees. The 0.25% cost is negligible — and you only lose it on success (which means you got what you wanted anyway). On failure, you are made whole and then some.

### Future Token Economics

Once sufficient protocol demand exists, a governance token will be introduced:
- Successful campaign fees (currently sent to Treasury) will be used for **token buyback and burn**
- Token holders who **lock** their tokens will receive a higher share of refund interest on failed campaigns
- This creates a flywheel: more usage → more fees → more buyback pressure → more incentive to lock → better refund rates for lockers

---

## Campaign Lifecycle

### 1. Creation

A creator calls `CrowdfundFactory.createCampaign()` with:
- `fundingGoal` — Target amount in ETH (wei), net of fees
- `deadline` — Unix timestamp when the campaign ends
- `minContribution` — Minimum contribution per backer (wei)
- `metadataURI` — IPFS hash or URL pointing to campaign details (title, description, image, social links, etc.)

No ETH required. Campaign creation is free (gas only).

The factory deploys a new `Campaign` contract and registers it.

**Constraints:**
- Deadline must be between 1 day and 90 days from now
- Funding goal must be > 0
- Min contribution must be > 0 and ≤ funding goal

### 2. Contribution

Any address (EOA or smart contract wallet) calls `Campaign.contribute{value: amount}()`.

**Constraints:**
- Campaign must be active (before deadline, not settled/cancelled)
- Contribution must be ≥ minContribution
- Each address can contribute only once (prevents gaming interest distribution)
- Additional contributions from same address should call `contributeMore()`
- A 25bps (0.25%) fee is deducted from each contribution and added to the fee pool

### 3. Settlement

After the deadline, anyone can call `Campaign.settle()` to finalize:

- **If totalRaised ≥ fundingGoal → State.Successful**
- **If totalRaised < fundingGoal → State.Failed**

Settlement is permissionless — anyone can trigger it. This ensures campaigns always resolve.

### 4a. Success Path — Creator Withdrawal

Creator calls `creatorWithdraw()`:
- Fee pool sent to Treasury (for protocol operations / future token buyback)
- totalRaised (net contributions) sent to creator
- One-time operation (cannot withdraw twice)

### 4b. Failure Path — Backer Refund + Interest

Each backer calls `claimRefund()`:
- Receives: `netContribution + (netContribution / totalRaised) * feePool`
- Proportional interest — larger contributors get a larger share of the fee pool
- One-time claim per backer

### 5. Cancellation

Creator can cancel a campaign ONLY if no contributions have been received yet.
- No ETH to return (creation was free)
- Campaign state set to Cancelled

---

## Account Abstraction Compatibility

The protocol MUST be fully compatible with all Ethereum account abstraction standards:

### Design Principles

1. **No `tx.origin` checks** — Never use `tx.origin`. All access control uses `msg.sender` only. This ensures smart contract wallets (ERC-4337, ERC-7702, Safe, etc.) can interact with every function.

2. **No signature-dependent logic** — The protocol does not require ECDSA signatures. All operations are plain function calls with ETH value transfers.

3. **No EOA assumptions** — Any `address` can be a creator or backer. The protocol makes no distinction between EOAs and contract wallets.

4. **Payable receive/fallback** — All contracts that need to receive ETH implement `receive()` appropriately to work with smart wallet batched transactions.

5. **No gas-dependent logic** — No `gasleft()` checks or gas stipend assumptions that could break with different execution contexts.

### Supported Wallet Types

- MetaMask / browser extension EOAs
- ERC-4337 smart contract wallets (Kernel, Safe{Wallet}, ZeroDev, Biconomy, etc.)
- ERC-7702 delegated EOAs
- Safe multisig wallets
- Any contract that can call functions and send ETH

---

## Metadata Standard

Campaign metadata is stored off-chain (IPFS preferred) and referenced by URI. The expected JSON schema:

```json
{
  "name": "Campaign Title",
  "description": "What this project is about and how funds will be used",
  "image": "ipfs://Qm.../cover.png",
  "category": "technology|defi|gaming|social|infrastructure|other",
  "website": "https://...",
  "socials": {
    "twitter": "https://twitter.com/...",
    "discord": "https://discord.gg/...",
    "telegram": "https://t.me/..."
  },
  "team": [
    {
      "name": "Alice",
      "role": "Founder",
      "address": "0x..."
    }
  ],
  "milestones": [
    {
      "title": "MVP Launch",
      "description": "...",
      "target_date": "2026-06-01"
    }
  ]
}
```

---

## Immutability & Permissionlessness

### What is immutable
- All contract logic — no proxy patterns, no upgradability
- Campaign parameters once created (goal, deadline, min contribution)
- Fee rate (25bps) — hardcoded in factory
- Settlement logic — deterministic based on raised vs goal

### What is permissionless
- Anyone can create a campaign
- Anyone can contribute to any campaign
- Anyone can settle any campaign after its deadline
- Anyone can view all campaign data on-chain

### What is configurable
- Treasury recipient address (admin-controlled, for operational flexibility)
- Metadata URI per campaign (creator can update before first contribution)

---

## Security Considerations

1. **Reentrancy** — All ETH transfers use ReentrancyGuard. Pull-over-push pattern for withdrawals and refunds.

2. **Integer overflow** — Solidity 0.8.24 has built-in overflow protection.

3. **Front-running** — Settlement is deterministic and cannot be gamed. Contributions are first-come, no ordering advantage.

4. **Fee pool safety** — Fee pool accumulates from contributions and is locked in the Campaign contract. No one can withdraw it until settlement.

5. **Dust attacks** — minContribution prevents spam micro-contributions that would increase gas costs for settlement.

6. **Time manipulation** — Uses block.timestamp which miners can manipulate by ~15 seconds. Campaign deadlines are in days, so this is negligible.

---

## Gas Optimization Notes

- Each campaign is a standalone contract (no shared state contention)
- Backer list stored as array for iteration, but claims are individual (no batch gas bomb)
- View functions use memory returns, not storage iteration
- Factory maintains minimal state (campaign ID → address mapping)

---

## Target Deployment

### Ethereum Mainnet
- Primary target
- Higher gas costs mean higher minContribution thresholds recommended
- Treasury multisig for fee management

### Monad
- Secondary target, same contracts
- Lower gas costs enable smaller campaigns
- Same immutable deployment

### NOT deploying to
- No L2s (Arbitrum, Optimism, Base, etc.)
- No sidechains
