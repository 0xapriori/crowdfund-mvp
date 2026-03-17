# Prior Codebase Analysis — crowdfunding-protocol

This document captures findings from a deep analysis of the original `/Users/apriori/crowdfunding-protocol` repository, which informed the design of this new MVP build.

---

## Repository Overview

- **Location:** `/Users/apriori/crowdfunding-protocol`
- **Commits:** 6 total (initialized Feb 2024, last updated Feb 2026)
- **Stack:** Foundry (Solidity 0.8.24) + Next.js 16 + Wagmi v2/Viem
- **Deployed:** Sepolia testnet, frontend on GitHub Pages

---

## Smart Contracts Found

### 1. CrowdfundFactory.sol (332 lines)
- Factory pattern deploying individual Campaign contracts
- Supported 4 bonus types: None, Fixed, Proportional, EarlyBird, Tiered
- Included a "funding request" system (demand-side aggregation)
- Protocol fee: 2.5% (250bps) — collected in individual campaigns
- Active campaign tracking via array (O(n) filtering)

### 2. Campaign.sol (305 lines)
- Individual campaign lifecycle management
- Contribution tracking with reward tiers
- Four bonus calculation algorithms
- ReentrancyGuard protection
- Pull-over-push withdrawal pattern

### 3. ConditionalIntentManager.sol (280 lines)
- Automated conditional contribution system
- 4 intent types: Identity, Threshold, Category, Bonus-based
- Escrowed funds held until conditions met

### 4. Interfaces
- ICampaign.sol, ICrowdfundFactory.sol, IConditionalIntentManager.sol

---

## Critical Issues Found

### Security
- **Private key exposed in `.env` committed to git** — must rotate immediately
- Low-level `call` in ConditionalIntentManager doesn't properly attribute contributions

### Bugs
- **Category-based intent matching double-hashes** the metadata URI — effectively broken
- **Tiered bonus hardcodes 90-day duration** regardless of actual campaign length
- **Protocol fees stuck in Campaign contracts** — no mechanism to transfer to factory
- Missing event emission on `commitToFundingRequest`

### Design Issues
- Auto-contribution on funding request match disabled (code commented out)
- ConditionalIntentManager can't contribute on behalf of backers (Campaign.contribute checks msg.sender)
- Array-based active campaign filtering is O(n), no cleanup mechanism
- `contributeConditional` function exists but has no execution logic

### Test Coverage
- Only 9 tests (~40% coverage)
- Missing tests: tiered bonus, cancellation, metadata updates, most intent types, edge cases

---

## Frontend Assessment

### What Existed
- Complete Next.js 16 app with App Router
- 5 pages: Home, Campaigns, Campaign Detail, Create, Dashboard, Intents
- Full Wagmi v2 + Viem + RainbowKit integration
- Zustand state management (3 stores: campaign, user, app)
- Tailwind CSS v4 styling
- IPFS/Pinata integration for metadata
- Multi-wallet support: MetaMask, Coinbase, WalletConnect

### What Was Missing/Broken
- `/profile` route referenced but not implemented
- Some hardcoded mock data ("23 backers")
- Intents page relied on broken ConditionalIntentManager

---

## Configuration

### Foundry
- Solidity 0.8.24, optimizer 200 runs, via-IR enabled
- OpenZeppelin v5.0.1, forge-std v1.14.0
- Sepolia RPC via Alchemy

### Deployment
- Contracts on Sepolia: Factory at `0x79770c...`, IntentManager at `0xe839b6...`
- Frontend on GitHub Pages via CI/CD workflow
- Deployer: `0xE4A1eA...`

### CI/CD
- `ci.yml` — Forge test on push to master
- `deploy.yml` — Build and deploy frontend to GitHub Pages on frontend changes

---

## What We're Keeping for MVP

- Factory + Campaign contract pattern (proven architecture)
- Proportional bonus calculation (simplest, fairest)
- Next.js + Wagmi + Viem + Tailwind stack
- Zustand state management
- Pull-over-push withdrawal pattern
- ReentrancyGuard on all payable functions
- IPFS metadata standard

## What We're Dropping

- ConditionalIntentManager (intents system — too complex for MVP)
- Funding request system (demand-side aggregation)
- Multiple bonus types (just proportional)
- Reward tiers (simplify to flat contributions)
- 2.5% fee → 25bps (0.25%) fee
- L2/testnet-only targeting → Ethereum mainnet + Monad

## What We're Fixing

- Fee flow: fees go to a dedicated Treasury contract, not stuck in campaigns
- Account abstraction: no tx.origin, pure msg.sender, compatible with ERC-4337/7702
- Bonus pool funded by creator at campaign creation (minimum = 25bps of goal)
- Clean separation: Factory deploys, Campaign manages lifecycle, Treasury holds fees
- Proper .gitignore for secrets from day one
