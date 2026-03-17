"use client";

import Link from "next/link";
import { ConnectButton } from "@rainbow-me/rainbowkit";

export function Header() {
  return (
    <header className="border-b border-gray-800 bg-gray-950/80 backdrop-blur-sm sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center gap-8">
            <Link href="/" className="text-xl font-bold text-white">
              Crowdfund
            </Link>
            <nav className="hidden md:flex gap-6">
              <Link
                href="/campaigns"
                className="text-gray-400 hover:text-white transition-colors"
              >
                Browse
              </Link>
              <Link
                href="/create"
                className="text-gray-400 hover:text-white transition-colors"
              >
                Create
              </Link>
              <Link
                href="/dashboard"
                className="text-gray-400 hover:text-white transition-colors"
              >
                Dashboard
              </Link>
            </nav>
          </div>
          <ConnectButton />
        </div>
      </div>
    </header>
  );
}
