import { type Address } from "viem";

export const FACTORY_ADDRESS = (process.env.NEXT_PUBLIC_FACTORY_ADDRESS ||
  "0x0000000000000000000000000000000000000000") as Address;

export const CAMPAIGN_STATES = ["Active", "Successful", "Failed", "Cancelled"] as const;
export type CampaignState = (typeof CAMPAIGN_STATES)[number];

export interface CampaignMetadata {
  name: string;
  description: string;
  image?: string;
  category?: string;
  website?: string;
  socials?: {
    twitter?: string;
    discord?: string;
    telegram?: string;
  };
}

export interface CampaignSummary {
  address: Address;
  campaignId: bigint;
  creator: Address;
  fundingGoal: bigint;
  deadline: bigint;
  minContribution: bigint;
  feePool: bigint;
  totalRaised: bigint;
  backerCount: bigint;
  state: number;
  metadataURI: string;
  metadata?: CampaignMetadata;
}
