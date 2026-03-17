"use client";

import { useReadContract } from "wagmi";
import { CrowdfundFactoryABI } from "@/contracts/abis";
import { FACTORY_ADDRESS } from "@/config/contracts";
import { CampaignCard } from "@/components/CampaignCard";
import { type Address } from "viem";

export default function CampaignsPage() {
  const { data: count, isLoading: countLoading } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: CrowdfundFactoryABI,
    functionName: "getCampaignCount",
  });

  const total = count ? Number(count) : 0;

  const { data: rawAddresses, isLoading: addressesLoading } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: CrowdfundFactoryABI,
    functionName: "getCampaigns",
    args: [0n, BigInt(total)],
    query: { enabled: total > 0 },
  });

  const addresses = rawAddresses as Address[] | undefined;
  const isLoading = countLoading || addressesLoading;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-white">Browse Campaigns</h1>
        <p className="text-gray-400 mt-2">
          {total} campaign{total !== 1 ? "s" : ""} on the platform
        </p>
      </div>

      {isLoading ? (
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="rounded-xl border border-gray-800 bg-gray-900 p-6 animate-pulse h-64"
            />
          ))}
        </div>
      ) : addresses && addresses.length > 0 ? (
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[...addresses].reverse().map((addr: Address) => (
            <CampaignCard key={addr} address={addr} />
          ))}
        </div>
      ) : (
        <div className="text-center py-20">
          <p className="text-gray-400 text-lg">No campaigns yet.</p>
          <a
            href="/create"
            className="text-indigo-400 hover:text-indigo-300 mt-2 inline-block"
          >
            Create the first one
          </a>
        </div>
      )}
    </div>
  );
}
