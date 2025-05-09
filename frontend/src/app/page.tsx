"use client"

import { AccountSection } from "@/components/account-section"
import { MarketSection } from "@/components/market-section"
import { Navbar } from "@/components/navbar"
import { PositionSection } from "@/components/position-section"

export default function Home() {
  return (
    <main className="container space-y-4 py-4">
      <Navbar />
      <div className="flex gap-6 *:space-y-4">
        <div className="flex-1 space-y-8">
          <MarketSection className="w-full flex-1 space-y-4" />
          <PositionSection />
        </div>
        <AccountSection className="w-[360px] shrink-0" />
      </div>
    </main>
  )
}
