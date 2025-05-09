import { ConnectButton } from "@rainbow-me/rainbowkit"

export function Navbar() {
  return (
    <nav className="flex h-10 items-center gap-2">
      <h1 className="text-3xl font-bold">NOIRI</h1>
      <div className="ml-auto">
        <ConnectButton showBalance />
      </div>
    </nav>
  )
}
