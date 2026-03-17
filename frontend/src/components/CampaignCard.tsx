"use client";

import Link from "next/link";
import { formatEther, type Address } from "viem";
import { useReadContract } from "wagmi";
import { CampaignABI } from "@/contracts/abis";
import { CAMPAIGN_STATES } from "@/config/contracts";
import { useEffect, useState } from "react";

function useCountdown(deadline: bigint | undefined) {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  useEffect(() => {
    const interval = setInterval(
      () => setNow(Math.floor(Date.now() / 1000)),
      1000
    );
    return () => clearInterval(interval);
  }, []);
  if (!deadline) return "";
  const remaining = Number(deadline) - now;
  if (remaining <= 0) return "Ended";
  const days = Math.floor(remaining / 86400);
  const hours = Math.floor((remaining % 86400) / 3600);
  const mins = Math.floor((remaining % 3600) / 60);
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${mins}m`;
  return `${mins}m`;
}

export function CampaignCard({ address }: { address: Address }) {
  const { data: summary } = useReadContract({
    address,
    abi: CampaignABI,
    functionName: "getSummary",
  });

  const countdown = useCountdown(summary?.[3]);

  if (!summary) {
    return (
      <div className="rounded-xl border border-gray-800 bg-gray-900 p-6 animate-pulse h-64" />
    );
  }

  const [campaignId, , fundingGoal, deadline, , feePool, totalRaised, backerCount, state, metadataURI] = summary;

  const percentage =
    fundingGoal > 0n
      ? Number((totalRaised * 100n) / fundingGoal)
      : 0;
  const stateLabel = CAMPAIGN_STATES[state] || "Unknown";

  // Parse metadata if it's JSON
  let name = `Campaign #${campaignId}`;
  let description = "";
  try {
    if (metadataURI.startsWith("{")) {
      const meta = JSON.parse(metadataURI);
      name = meta.name || name;
      description = meta.description || "";
    }
  } catch {
    // metadataURI might be an IPFS hash, use default name
  }

  const stateColor = {
    Active: "text-green-400 bg-green-400/10",
    Successful: "text-blue-400 bg-blue-400/10",
    Failed: "text-red-400 bg-red-400/10",
    Cancelled: "text-gray-400 bg-gray-400/10",
  }[stateLabel] || "text-gray-400 bg-gray-400/10";

  return (
    <Link
      href={`/campaigns/${address}`}
      className="block rounded-xl border border-gray-800 bg-gray-900 p-6 hover:border-indigo-500/50 transition-colors"
    >
      <div className="flex items-start justify-between mb-3">
        <h3 className="text-lg font-semibold text-white truncate pr-2">{name}</h3>
        <span className={`text-xs px-2 py-1 rounded-full font-medium whitespace-nowrap ${stateColor}`}>
          {stateLabel}
        </span>
      </div>

      {description && (
        <p className="text-gray-400 text-sm mb-4 line-clamp-2">{description}</p>
      )}

      <div className="space-y-3">
        {/* Progress bar */}
        <div>
          <div className="flex justify-between text-sm mb-1">
            <span className="text-gray-400">
              {formatEther(totalRaised)} / {formatEther(fundingGoal)} ETH
            </span>
            <span className="text-indigo-400 font-medium">{percentage}%</span>
          </div>
          <div className="w-full bg-gray-800 rounded-full h-2">
            <div
              className="bg-indigo-500 h-2 rounded-full transition-all"
              style={{ width: `${Math.min(percentage, 100)}%` }}
            />
          </div>
        </div>

        {/* Stats row */}
        <div className="flex justify-between text-sm text-gray-400">
          <span>{Number(backerCount)} backers</span>
          <span>Fees: {formatEther(feePool)} ETH</span>
          <span>{countdown}</span>
        </div>
      </div>
    </Link>
  );
}
