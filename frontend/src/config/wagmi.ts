import { http } from "wagmi";
import { sepolia } from "wagmi/chains";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";

export const config = getDefaultConfig({
  appName: "Crowdfund Protocol",
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "demo",
  chains: [sepolia],
  transports: {
    [sepolia.id]: http(
      process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL || "https://rpc.sepolia.org"
    ),
  },
  ssr: true,
});
