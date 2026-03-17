"use client";

import Link from "next/link";
import { useReadContract } from "wagmi";
import { CrowdfundFactoryABI } from "@/contracts/abis";
import { FACTORY_ADDRESS } from "@/config/contracts";
import { CampaignCard } from "@/components/CampaignCard";
import { type Address } from "viem";

export default function Home() {
  const { data: count } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: CrowdfundFactoryABI,
    functionName: "getCampaignCount",
  });

  const fetchCount = count ? Math.min(Number(count), 3) : 0;
  const startIdx = count ? Number(count) - fetchCount : 0;

  const { data: rawRecentAddresses } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: CrowdfundFactoryABI,
    functionName: "getCampaigns",
    args: [BigInt(startIdx), BigInt(fetchCount)],
    query: { enabled: fetchCount > 0 },
  });
  const recentAddresses = rawRecentAddresses as Address[] | undefined;

  return (
    <div>
      {/* Hero */}
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-indigo-950/50 via-gray-950 to-gray-950" />
        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24 lg:py-32">
          <div className="max-w-3xl">
            <h1 className="text-5xl lg:text-6xl font-bold text-white mb-6 leading-tight">
              Invest in projects with{" "}
              <span className="text-indigo-400">built-in downside protection</span>
            </h1>
            <p className="text-xl text-gray-300 mb-8 leading-relaxed">
              The first permissionless crowdfunding protocol with dominant
              assurance. If a project fails to meet its goal, you get your money
              back <span className="text-green-400 font-semibold">plus a bonus</span>.
            </p>
            <div className="flex gap-4">
              <Link
                href="/campaigns"
                className="bg-indigo-600 hover:bg-indigo-500 text-white px-6 py-3 rounded-lg font-medium transition-colors"
              >
                Browse Campaigns
              </Link>
              <Link
                href="/create"
                className="border border-gray-700 hover:border-gray-500 text-white px-6 py-3 rounded-lg font-medium transition-colors"
              >
                Create Campaign
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <h2 className="text-3xl font-bold text-white mb-12 text-center">
          How Dominant Assurance Works
        </h2>
        <div className="grid md:grid-cols-3 gap-8">
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <div className="w-10 h-10 bg-indigo-600/20 rounded-lg flex items-center justify-center text-indigo-400 font-bold mb-4">
              1
            </div>
            <h3 className="text-lg font-semibold text-white mb-2">
              Creator Stakes a Bonus
            </h3>
            <p className="text-gray-400">
              Project creators deposit a bonus pool when creating a campaign.
              This signals confidence and guarantees backer protection.
            </p>
          </div>
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <div className="w-10 h-10 bg-indigo-600/20 rounded-lg flex items-center justify-center text-indigo-400 font-bold mb-4">
              2
            </div>
            <h3 className="text-lg font-semibold text-white mb-2">
              Backers Invest Risk-Free
            </h3>
            <p className="text-gray-400">
              Contribute ETH to campaigns you believe in. If the campaign
              succeeds, you funded a project. If it fails, you profit.
            </p>
          </div>
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <div className="w-10 h-10 bg-green-600/20 rounded-lg flex items-center justify-center text-green-400 font-bold mb-4">
              +
            </div>
            <h3 className="text-lg font-semibold text-white mb-2">
              Win-Win Outcome
            </h3>
            <p className="text-gray-400">
              Success: creator gets funds, backers supported a project, bonus pool
              is returned. Failure: backers get refund + proportional bonus.
            </p>
          </div>
        </div>
      </section>

      {/* Recent Campaigns */}
      {recentAddresses && recentAddresses.length > 0 && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div className="flex items-center justify-between mb-8">
            <h2 className="text-2xl font-bold text-white">Recent Campaigns</h2>
            <Link
              href="/campaigns"
              className="text-indigo-400 hover:text-indigo-300 transition-colors"
            >
              View all
            </Link>
          </div>
          <div className="grid md:grid-cols-3 gap-6">
            {recentAddresses.map((addr) => (
              <CampaignCard key={addr} address={addr as Address} />
            ))}
          </div>
        </section>
      )}

      {/* Stats */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <div className="grid grid-cols-3 gap-8 text-center">
          <div>
            <div className="text-3xl font-bold text-white">
              {count !== undefined ? Number(count).toString() : "..."}
            </div>
            <div className="text-gray-400 mt-1">Campaigns Created</div>
          </div>
          <div>
            <div className="text-3xl font-bold text-white">0.25%</div>
            <div className="text-gray-400 mt-1">Protocol Fee</div>
          </div>
          <div>
            <div className="text-3xl font-bold text-white">Immutable</div>
            <div className="text-gray-400 mt-1">No Proxy, No Upgrades</div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-800 py-8 mt-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center text-gray-500 text-sm">
          Crowdfund Protocol — Permissionless, immutable crowdfunding on Ethereum
        </div>
      </footer>
    </div>
  );
}
