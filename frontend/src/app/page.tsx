import { AccountSection } from "@/components/account-section"
import { MarketSection } from "@/components/market-section"

export default function Home() {
  return (
    <main className="container flex gap-6 py-4 *:space-y-4">
      <MarketSection className="w-full flex-1" />
      <AccountSection className="w-[360px] shrink-0" />
    </main>
  )
}
