"use client";

import { useParams } from "next/navigation";
import { useReadContract, useWriteContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { CampaignABI } from "@/contracts/abis";
import { CAMPAIGN_STATES } from "@/config/contracts";
import { formatEther, parseEther, type Address } from "viem";
import { useState, useEffect } from "react";
import Link from "next/link";

function useCountdown(deadline: bigint | undefined) {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  useEffect(() => {
    const interval = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    return () => clearInterval(interval);
  }, []);
  if (!deadline) return "";
  const remaining = Number(deadline) - now;
  if (remaining <= 0) return "Campaign ended";
  const days = Math.floor(remaining / 86400);
  const hours = Math.floor((remaining % 86400) / 3600);
  const mins = Math.floor((remaining % 3600) / 60);
  const secs = remaining % 60;
  if (days > 0) return `${days}d ${hours}h ${mins}m`;
  if (hours > 0) return `${hours}h ${mins}m ${secs}s`;
  return `${mins}m ${secs}s`;
}

export default function CampaignDetailPage() {
  const params = useParams();
  const campaignAddress = params.id as Address;
  const { address: userAddress } = useAccount();
  const [contributeAmount, setContributeAmount] = useState("");

  const { data: summary, refetch: refetchSummary } = useReadContract({
    address: campaignAddress,
    abi: CampaignABI,
    functionName: "getSummary",
  });

  const { data: userContribution, refetch: refetchContribution } = useReadContract({
    address: campaignAddress,
    abi: CampaignABI,
    functionName: "getContribution",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress },
  });

  const { data: refundCalc } = useReadContract({
    address: campaignAddress,
    abi: CampaignABI,
    functionName: "calculateRefund",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress },
  });

  const { writeContract, data: txHash, isPending } = useWriteContract();
  const { isSuccess: txConfirmed } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (txConfirmed) {
      refetchSummary();
      refetchContribution();
    }
  }, [txConfirmed, refetchSummary, refetchContribution]);

  const countdown = useCountdown(summary?.[3]);

  if (!summary) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-800 rounded w-1/3" />
          <div className="h-4 bg-gray-800 rounded w-2/3" />
          <div className="h-64 bg-gray-800 rounded" />
        </div>
      </div>
    );
  }

  const [campaignId, creator, fundingGoal, deadline, minContribution, feePool, totalRaised, backerCount, state, metadataURI] = summary;

  const percentage = fundingGoal > 0n ? Number((totalRaised * 100n) / fundingGoal) : 0;
  const stateLabel = CAMPAIGN_STATES[state] || "Unknown";
  const isCreator = userAddress?.toLowerCase() === creator.toLowerCase();
  const hasContributed = userContribution && userContribution[0] > 0n;
  const deadlinePassed = Number(deadline) <= Math.floor(Date.now() / 1000);

  let name = `Campaign #${campaignId}`;
  let description = "";
  let image = "";
  let website = "";
  try {
    if (metadataURI.startsWith("{")) {
      const meta = JSON.parse(metadataURI);
      name = meta.name || name;
      description = meta.description || "";
      image = meta.image || "";
      website = meta.website || "";
    }
  } catch {
    // not JSON
  }

  const handleContribute = () => {
    if (!contributeAmount) return;
    const fn = hasContributed ? "contributeMore" : "contribute";
    writeContract({
      address: campaignAddress,
      abi: CampaignABI,
      functionName: fn,
      value: parseEther(contributeAmount),
    });
  };

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <Link href="/campaigns" className="text-indigo-400 hover:text-indigo-300 text-sm mb-6 inline-block">
        &larr; Back to campaigns
      </Link>

      <div className="grid lg:grid-cols-3 gap-8">
        {/* Main content */}
        <div className="lg:col-span-2 space-y-6">
          <div>
            <div className="flex items-start justify-between gap-4">
              <h1 className="text-3xl font-bold text-white">{name}</h1>
              <span className={`text-sm px-3 py-1 rounded-full font-medium whitespace-nowrap ${
                stateLabel === "Active" ? "text-green-400 bg-green-400/10" :
                stateLabel === "Successful" ? "text-blue-400 bg-blue-400/10" :
                stateLabel === "Failed" ? "text-red-400 bg-red-400/10" :
                "text-gray-400 bg-gray-400/10"
              }`}>
                {stateLabel}
              </span>
            </div>
            <p className="text-gray-500 text-sm mt-2">
              by {creator.slice(0, 6)}...{creator.slice(-4)}
            </p>
          </div>

          {image && (
            <img src={image} alt={name} className="w-full rounded-xl border border-gray-800" />
          )}

          {description && (
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
              <h2 className="text-lg font-semibold text-white mb-3">About</h2>
              <p className="text-gray-300 whitespace-pre-wrap">{description}</p>
            </div>
          )}

          {website && (
            <a href={website} target="_blank" rel="noopener noreferrer" className="text-indigo-400 hover:text-indigo-300 text-sm">
              {website}
            </a>
          )}

          {/* Your contribution */}
          {hasContributed && userContribution && (
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
              <h2 className="text-lg font-semibold text-white mb-3">Your Contribution</h2>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Amount</span>
                  <span className="text-white">{formatEther(userContribution[0])} ETH</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Date</span>
                  <span className="text-white">
                    {new Date(Number(userContribution[1]) * 1000).toLocaleDateString()}
                  </span>
                </div>
                {refundCalc && refundCalc[1] > 0n && (
                  <div className="flex justify-between">
                    <span className="text-gray-400">Potential interest if failed</span>
                    <span className="text-green-400">+{formatEther(refundCalc[1])} ETH</span>
                  </div>
                )}
                <div className="flex justify-between">
                  <span className="text-gray-400">Refund claimed</span>
                  <span className="text-white">{userContribution[2] ? "Yes" : "No"}</span>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* Progress */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <div className="text-3xl font-bold text-white mb-1">
              {formatEther(totalRaised)} ETH
            </div>
            <div className="text-gray-400 text-sm mb-4">
              raised of {formatEther(fundingGoal)} ETH goal
            </div>
            <div className="w-full bg-gray-800 rounded-full h-3 mb-4">
              <div
                className="bg-indigo-500 h-3 rounded-full transition-all"
                style={{ width: `${Math.min(percentage, 100)}%` }}
              />
            </div>
            <div className="grid grid-cols-3 gap-4 text-center text-sm">
              <div>
                <div className="text-white font-semibold">{percentage}%</div>
                <div className="text-gray-500">funded</div>
              </div>
              <div>
                <div className="text-white font-semibold">{Number(backerCount)}</div>
                <div className="text-gray-500">backers</div>
              </div>
              <div>
                <div className="text-white font-semibold text-xs leading-5">{countdown}</div>
                <div className="text-gray-500">remaining</div>
              </div>
            </div>
          </div>

          {/* Fee pool info */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <h3 className="text-sm font-semibold text-white mb-2">Fee Pool (Refund Interest)</h3>
            <div className="text-2xl font-bold text-green-400 mb-1">
              {formatEther(feePool)} ETH
            </div>
            <p className="text-gray-500 text-xs">
              0.25% of each contribution. Distributed as interest to backers if campaign fails.
              Min contribution: {formatEther(minContribution)} ETH
            </p>
          </div>

          {/* Actions */}
          {state === 0 && !deadlinePassed && (
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
              <h3 className="text-sm font-semibold text-white mb-3">
                {hasContributed ? "Add More" : "Contribute"}
              </h3>
              <div className="flex gap-2">
                <input
                  type="number"
                  step="0.001"
                  min={formatEther(minContribution)}
                  placeholder={`Min ${formatEther(minContribution)} ETH`}
                  value={contributeAmount}
                  onChange={(e) => setContributeAmount(e.target.value)}
                  className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500"
                />
                <button
                  onClick={handleContribute}
                  disabled={isPending || !contributeAmount}
                  className="bg-indigo-600 hover:bg-indigo-500 disabled:bg-gray-700 disabled:text-gray-500 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                >
                  {isPending ? "..." : "Send"}
                </button>
              </div>
            </div>
          )}

          {/* Settle button */}
          {state === 0 && deadlinePassed && (
            <button
              onClick={() =>
                writeContract({
                  address: campaignAddress,
                  abi: CampaignABI,
                  functionName: "settle",
                })
              }
              disabled={isPending}
              className="w-full bg-amber-600 hover:bg-amber-500 text-white px-4 py-3 rounded-lg font-medium transition-colors"
            >
              {isPending ? "Settling..." : "Settle Campaign"}
            </button>
          )}

          {/* Creator withdraw */}
          {state === 1 && isCreator && (
            <button
              onClick={() =>
                writeContract({
                  address: campaignAddress,
                  abi: CampaignABI,
                  functionName: "creatorWithdraw",
                })
              }
              disabled={isPending}
              className="w-full bg-green-600 hover:bg-green-500 text-white px-4 py-3 rounded-lg font-medium transition-colors"
            >
              {isPending ? "Withdrawing..." : "Withdraw Funds"}
            </button>
          )}

          {/* Claim refund */}
          {state === 2 && hasContributed && userContribution && !userContribution[2] && (
            <button
              onClick={() =>
                writeContract({
                  address: campaignAddress,
                  abi: CampaignABI,
                  functionName: "claimRefund",
                })
              }
              disabled={isPending}
              className="w-full bg-green-600 hover:bg-green-500 text-white px-4 py-3 rounded-lg font-medium transition-colors"
            >
              {isPending
                ? "Claiming..."
                : `Claim Refund + Interest (${refundCalc ? formatEther(refundCalc[0] + refundCalc[1]) : "..."} ETH)`}
            </button>
          )}

          {/* Cancel */}
          {state === 0 && isCreator && backerCount === 0n && (
            <button
              onClick={() =>
                writeContract({
                  address: campaignAddress,
                  abi: CampaignABI,
                  functionName: "cancel",
                })
              }
              disabled={isPending}
              className="w-full border border-red-800 text-red-400 hover:bg-red-900/20 px-4 py-3 rounded-lg font-medium transition-colors"
            >
              {isPending ? "Cancelling..." : "Cancel Campaign"}
            </button>
          )}

          {txConfirmed && (
            <div className="bg-green-900/20 border border-green-800 rounded-lg p-3 text-green-400 text-sm text-center">
              Transaction confirmed!
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
