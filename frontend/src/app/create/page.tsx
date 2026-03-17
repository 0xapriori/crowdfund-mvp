"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { parseEther } from "viem";
import { CrowdfundFactoryABI } from "@/contracts/abis";
import { FACTORY_ADDRESS } from "@/config/contracts";

export default function CreateCampaignPage() {
  const router = useRouter();
  const { address } = useAccount();
  const { writeContract, data: txHash, isPending, error } = useWriteContract();
  const { isSuccess: txConfirmed } = useWaitForTransactionReceipt({ hash: txHash });

  const [form, setForm] = useState({
    name: "",
    description: "",
    image: "",
    category: "technology",
    website: "",
    fundingGoal: "",
    durationDays: "30",
    minContribution: "0.01",
  });

  const update = (field: string, value: string) =>
    setForm((prev) => ({ ...prev, [field]: value }));

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!address) return;

    const metadata = JSON.stringify({
      name: form.name,
      description: form.description,
      image: form.image || undefined,
      category: form.category,
      website: form.website || undefined,
    });

    const deadline = BigInt(
      Math.floor(Date.now() / 1000) + Number(form.durationDays) * 86400
    );

    writeContract({
      address: FACTORY_ADDRESS,
      abi: CrowdfundFactoryABI,
      functionName: "createCampaign",
      args: [
        parseEther(form.fundingGoal),
        deadline,
        parseEther(form.minContribution),
        metadata,
      ],
    });
  };

  if (txConfirmed) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-20 text-center">
        <div className="text-green-400 text-5xl mb-4">&#10003;</div>
        <h1 className="text-2xl font-bold text-white mb-2">Campaign Created!</h1>
        <p className="text-gray-400 mb-6">Your campaign is now live on-chain.</p>
        <button
          onClick={() => router.push("/campaigns")}
          className="bg-indigo-600 hover:bg-indigo-500 text-white px-6 py-3 rounded-lg font-medium"
        >
          View Campaigns
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <h1 className="text-3xl font-bold text-white mb-2">Create Campaign</h1>
      <p className="text-gray-400 mb-8">
        Launch a crowdfunding campaign with dominant assurance. No upfront cost
        &mdash; a 0.25% fee on contributions funds the refund bonus automatically.
      </p>

      {!address ? (
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-8 text-center">
          <p className="text-gray-400">Connect your wallet to create a campaign.</p>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Project Info */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-4">
            <h2 className="text-lg font-semibold text-white">Project Info</h2>
            <div>
              <label className="block text-sm text-gray-400 mb-1">Name</label>
              <input
                required
                value={form.name}
                onChange={(e) => update("name", e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-indigo-500"
                placeholder="My Project"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">Description</label>
              <textarea
                required
                rows={4}
                value={form.description}
                onChange={(e) => update("description", e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-indigo-500"
                placeholder="Describe your project and how funds will be used..."
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-gray-400 mb-1">Category</label>
                <select
                  value={form.category}
                  onChange={(e) => update("category", e.target.value)}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-indigo-500"
                >
                  <option value="technology">Technology</option>
                  <option value="defi">DeFi</option>
                  <option value="gaming">Gaming</option>
                  <option value="social">Social</option>
                  <option value="infrastructure">Infrastructure</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-1">Website</label>
                <input
                  value={form.website}
                  onChange={(e) => update("website", e.target.value)}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-indigo-500"
                  placeholder="https://..."
                />
              </div>
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">
                Image URL (optional)
              </label>
              <input
                value={form.image}
                onChange={(e) => update("image", e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-indigo-500"
                placeholder="https://... or ipfs://..."
              />
            </div>
          </div>

          {/* Funding */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-4">
            <h2 className="text-lg font-semibold text-white">Funding</h2>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-gray-400 mb-1">
                  Funding Goal (ETH)
                </label>
                <input
                  required
                  type="number"
                  step="0.001"
                  min="0.001"
                  value={form.fundingGoal}
                  onChange={(e) => update("fundingGoal", e.target.value)}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-indigo-500"
                  placeholder="10"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-1">
                  Duration (days)
                </label>
                <input
                  required
                  type="number"
                  min="1"
                  max="90"
                  value={form.durationDays}
                  onChange={(e) => update("durationDays", e.target.value)}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-indigo-500"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">
                Min Contribution (ETH)
              </label>
              <input
                required
                type="number"
                step="0.001"
                min="0.001"
                value={form.minContribution}
                onChange={(e) => update("minContribution", e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-indigo-500"
              />
            </div>
          </div>

          {/* Summary */}
          {form.fundingGoal && (
            <div className="bg-indigo-950/30 border border-indigo-800/50 rounded-xl p-6">
              <h3 className="text-sm font-semibold text-indigo-300 mb-3">Summary</h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Funding goal</span>
                  <span className="text-white">{form.fundingGoal} ETH</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Duration</span>
                  <span className="text-white">{form.durationDays} days</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Fee model</span>
                  <span className="text-white">0.25% on each contribution</span>
                </div>
                <hr className="border-gray-700" />
                <div className="flex justify-between font-medium">
                  <span className="text-gray-300">Cost to create</span>
                  <span className="text-green-400">Free (gas only)</span>
                </div>
              </div>
              <p className="text-xs text-gray-500 mt-3">
                If your campaign fails, the 0.25% fees collected from contributions
                are distributed back to backers as interest (dominant assurance).
              </p>
            </div>
          )}

          {error && (
            <div className="bg-red-900/20 border border-red-800 rounded-lg p-3 text-red-400 text-sm">
              {error.message.includes("User rejected")
                ? "Transaction rejected."
                : `Error: ${error.message.slice(0, 200)}`}
            </div>
          )}

          <button
            type="submit"
            disabled={isPending || !form.name || !form.fundingGoal}
            className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:bg-gray-700 disabled:text-gray-500 text-white py-3 rounded-lg font-medium transition-colors"
          >
            {isPending ? "Creating..." : "Create Campaign"}
          </button>
        </form>
      )}
    </div>
  );
}
