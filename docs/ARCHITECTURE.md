# Architecture

## Smart Contract Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    CrowdfundFactory                      │
│                    (Singleton)                            │
│                                                          │
│  - createCampaign() → deploys Campaign                   │
│  - getCampaign(id) → returns campaign address            │
│  - getCampaignCount() → total campaigns                  │
│  - campaignId → address mapping                          │
│  - treasury address (immutable)                          │
│  - PROTOCOL_FEE_BPS = 25 (immutable)                    │
│                                                          │
│  Events: CampaignCreated                                 │
└──────────────┬──────────────────────────────┬────────────┘
               │ deploys                      │ references
               ▼                              ▼
┌──────────────────────────┐   ┌──────────────────────────┐
│        Campaign          │   │        Treasury          │
│    (One per campaign)    │   │       (Singleton)        │
│                          │   │                          │
│  Immutables:             │   │  - admin (configurable)  │
│  - campaignId            │   │  - receive() ETH         │
│  - creator               │   │  - withdraw(to, amount)  │
│  - fundingGoal           │   │  - getBalance()          │
│  - deadline              │   │                          │
│  - minContribution       │   │  Events:                 │
│  - bonusPool             │   │  - FeeReceived           │
│  - factory               │   │  - Withdrawal            │
│  - treasury              │   │  - AdminTransferred      │
│                          │   │                          │
│  State:                  │   └──────────────────────────┘
│  - state (enum)          │
│  - totalRaised           │
│  - backerCount           │
│  - contributions[]       │
│  - backers[]             │
│                          │
│  Functions:              │
│  - contribute()          │
│  - contributeMore()      │
│  - settle()              │
│  - creatorWithdraw()     │
│  - claimRefund()         │
│  - cancel()              │
│                          │
│  Events:                 │
│  - ContributionMade      │
│  - CampaignSettled       │
│  - RefundClaimed         │
│  - CreatorWithdrawal     │
│  - CampaignCancelled     │
└──────────────────────────┘
```

## User Flows

### Creator Flow
```
1. Creator prepares metadata JSON, uploads to IPFS
2. Creator calls Factory.createCampaign(goal, deadline, minContrib, metadataURI)
   with msg.value ≥ goal * 25bps (bonus pool)
3. Factory deploys Campaign contract, returns campaignId
4. Campaign is now live — appears on frontend
5. After deadline:
   a. If successful → creator calls creatorWithdraw()
   b. If failed → creator loses bonus pool
```

### Backer Flow
```
1. Backer browses campaigns on frontend
2. Backer calls Campaign.contribute{value: X}()
3. After deadline:
   a. If successful → backer's investment went to the project
   b. If failed → backer calls claimRefund() → gets contribution + bonus
```

### Fee Flow
```
Campaign succeeds:
  → 25bps of totalRaised → Treasury contract
  → Remaining raised → Creator
  → Bonus pool → returned to Creator

Campaign fails:
  → Bonus pool → distributed proportionally to backers
  → Treasury gets nothing
  → Creator loses bonus pool deposit
```

## Frontend Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Next.js App                        │
│                                                      │
│  Pages:                                              │
│  ├── / (Home)           — Hero, value prop, stats    │
│  ├── /campaigns         — Browse + filter campaigns  │
│  ├── /campaigns/[id]    — Detail + contribute        │
│  ├── /create            — Create campaign form       │
│  └── /dashboard         — My campaigns + investments │
│                                                      │
│  State: Zustand stores                               │
│  ├── campaignStore      — Campaign data + filters    │
│  ├── userStore          — Wallet + portfolio         │
│  └── appStore           — UI state + notifications   │
│                                                      │
│  Web3: Wagmi v2 + Viem                               │
│  ├── useAccount         — Wallet connection          │
│  ├── useReadContract    — Read campaign state        │
│  ├── useWriteContract   — Send transactions          │
│  └── useWatchContractEvent — Real-time updates       │
│                                                      │
│  Wallet: RainbowKit                                  │
│  ├── MetaMask                                        │
│  ├── Coinbase Wallet                                 │
│  ├── WalletConnect v2                                │
│  └── Any ERC-4337/7702 compatible wallet             │
│                                                      │
│  Styling: Tailwind CSS                               │
│  Metadata: IPFS via Pinata gateway                   │
└─────────────────────────────────────────────────────┘
```

## Data Flow

### On-chain (source of truth)
- Campaign parameters (goal, deadline, state, raised, backers)
- Contribution records
- Protocol fee receipts

### Off-chain (metadata)
- Campaign title, description, image
- Social links, team info, milestones
- Stored on IPFS, referenced by metadataURI in contract

### Frontend reads
- Factory: campaign count, campaign addresses
- Campaign: state, progress, contributions, backers
- IPFS: metadata JSON for display

### Frontend writes
- Factory: createCampaign (deploys new campaign)
- Campaign: contribute, settle, creatorWithdraw, claimRefund, cancel
