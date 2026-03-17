"use client";

import { useAccount, useReadContract, useReadContracts } from "wagmi";
import { CrowdfundFactoryABI, CampaignABI } from "@/contracts/abis";
import { FACTORY_ADDRESS, CAMPAIGN_STATES } from "@/config/contracts";
import { formatEther, type Address } from "viem";
import Link from "next/link";

export default function DashboardPage() {
  const { address } = useAccount();

  const { data: count } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: CrowdfundFactoryABI,
    functionName: "getCampaignCount",
  });

  const total = count ? Number(count) : 0;

  const { data: rawAddresses } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: CrowdfundFactoryABI,
    functionName: "getCampaigns",
    args: [0n, BigInt(total)],
    query: { enabled: total > 0 },
  });

  const addresses = rawAddresses as Address[] | undefined;

  // Read summaries for all campaigns
  const addrList = addresses || [];
  const summaryContracts = addrList.map((addr: Address) => ({
    address: addr,
    abi: CampaignABI,
    functionName: "getSummary" as const,
  }));

  const { data: summaries } = useReadContracts({
    contracts: summaryContracts,
    query: { enabled: summaryContracts.length > 0 },
  });

  // Read user contributions for all campaigns
  const contributionContracts = address
    ? addrList.map((addr: Address) => ({
        address: addr,
        abi: CampaignABI,
        functionName: "getContribution" as const,
        args: [address] as const,
      }))
    : [];

  const { data: contributions } = useReadContracts({
    contracts: contributionContracts,
    query: { enabled: contributionContracts.length > 0 },
  });

  if (!address) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-20 text-center">
        <h1 className="text-2xl font-bold text-white mb-4">Dashboard</h1>
        <p className="text-gray-400">Connect your wallet to view your campaigns and investments.</p>
      </div>
    );
  }

  // Filter campaigns created by user
  const myCampaigns: Array<{
    address: Address;
    summary: readonly [bigint, `0x${string}`, bigint, bigint, bigint, bigint, bigint, bigint, number, string];
  }> = [];

  // Filter campaigns user has contributed to
  const myInvestments: Array<{
    address: Address;
    summary: readonly [bigint, `0x${string}`, bigint, bigint, bigint, bigint, bigint, bigint, number, string];
    contribution: readonly [bigint, bigint, boolean];
  }> = [];

  if (summaries && addresses) {
    for (let i = 0; i < addresses.length; i++) {
      const result = summaries[i];
      if (result.status !== "success") continue;
      const summary = result.result as readonly [bigint, `0x${string}`, bigint, bigint, bigint, bigint, bigint, bigint, number, string];

      if (summary[1].toLowerCase() === address.toLowerCase()) {
        myCampaigns.push({ address: addresses[i] as Address, summary });
      }

      if (contributions && contributions[i]?.status === "success") {
        const contrib = contributions[i].result as readonly [bigint, bigint, boolean];
        if (contrib[0] > 0n) {
          myInvestments.push({
            address: addresses[i] as Address,
            summary,
            contribution: contrib,
          });
        }
      }
    }
  }

  const getName = (metadataURI: string, id: bigint) => {
    try {
      if (metadataURI.startsWith("{")) {
        return JSON.parse(metadataURI).name || `Campaign #${id}`;
      }
    } catch { /* ignore */ }
    return `Campaign #${id}`;
  };

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <h1 className="text-3xl font-bold text-white mb-8">Dashboard</h1>

      {/* My Campaigns */}
      <section className="mb-12">
        <h2 className="text-xl font-semibold text-white mb-4">
          My Campaigns ({myCampaigns.length})
        </h2>
        {myCampaigns.length === 0 ? (
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 text-center">
            <p className="text-gray-400 mb-3">You haven&apos;t created any campaigns yet.</p>
            <Link href="/create" className="text-indigo-400 hover:text-indigo-300">
              Create one
            </Link>
          </div>
        ) : (
          <div className="space-y-3">
            {myCampaigns.map(({ address: addr, summary }) => {
              const [id, , goal, , , , raised, backers, state, meta] = summary;
              const pct = goal > 0n ? Number((raised * 100n) / goal) : 0;
              return (
                <Link
                  key={addr}
                  href={`/campaigns/${addr}`}
                  className="block bg-gray-900 border border-gray-800 rounded-xl p-4 hover:border-indigo-500/50 transition-colors"
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-medium text-white">{getName(meta, id)}</span>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${
                      state === 0 ? "text-green-400 bg-green-400/10" :
                      state === 1 ? "text-blue-400 bg-blue-400/10" :
                      state === 2 ? "text-red-400 bg-red-400/10" :
                      "text-gray-400 bg-gray-400/10"
                    }`}>
                      {CAMPAIGN_STATES[state]}
                    </span>
                  </div>
                  <div className="flex items-center gap-4 text-sm text-gray-400">
                    <span>{formatEther(raised)} / {formatEther(goal)} ETH ({pct}%)</span>
                    <span>{Number(backers)} backers</span>
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </section>

      {/* My Investments */}
      <section>
        <h2 className="text-xl font-semibold text-white mb-4">
          My Investments ({myInvestments.length})
        </h2>
        {myInvestments.length === 0 ? (
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 text-center">
            <p className="text-gray-400 mb-3">You haven&apos;t invested in any campaigns yet.</p>
            <Link href="/campaigns" className="text-indigo-400 hover:text-indigo-300">
              Browse campaigns
            </Link>
          </div>
        ) : (
          <div className="space-y-3">
            {myInvestments.map(({ address: addr, summary, contribution }) => {
              const [id, , goal, , , , raised, , state, meta] = summary;
              const pct = goal > 0n ? Number((raised * 100n) / goal) : 0;
              return (
                <Link
                  key={addr}
                  href={`/campaigns/${addr}`}
                  className="block bg-gray-900 border border-gray-800 rounded-xl p-4 hover:border-indigo-500/50 transition-colors"
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-medium text-white">{getName(meta, id)}</span>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${
                      state === 0 ? "text-green-400 bg-green-400/10" :
                      state === 1 ? "text-blue-400 bg-blue-400/10" :
                      state === 2 ? "text-red-400 bg-red-400/10" :
                      "text-gray-400 bg-gray-400/10"
                    }`}>
                      {CAMPAIGN_STATES[state]}
                    </span>
                  </div>
                  <div className="flex items-center gap-4 text-sm text-gray-400">
                    <span>Your investment: {formatEther(contribution[0])} ETH</span>
                    <span>Campaign: {pct}% funded</span>
                    {contribution[2] && <span className="text-green-400">Refund claimed</span>}
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}
