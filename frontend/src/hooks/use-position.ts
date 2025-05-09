import { Hex } from "viem"
import { create } from "zustand"
import { persist } from "zustand/middleware"

import { contracts } from "@/lib/contract"

export interface Position {
  id: string
  depositToken: "usdc" | "weth"
  borrowToken: "usdc" | "weth"
  lendAmt: Hex
  borrowAmt: Hex
  willLiqPrice: Hex
  willLiqPriceWeth: number
  timestamp: number
  nullifier: Hex
  nonce: Hex
  leafIndex: number | null
}

export interface PositionStore {
  positions: Position[]
  addPosition: (position: Position) => void
  replacePosition: (id: string, position: Position) => void
}

export const usePositionStore = create<PositionStore>()(
  persist(
    (set, get) => ({
      positions: [],
      addPosition: (position: Position) =>
        set({ positions: [...get().positions, position] }),
      replacePosition: (id: string, position: Position) =>
        set(({ positions }) => ({
          positions: positions.map((p) => (p.id === id ? position : p)),
        })),
    }),

    {
      name: `position-storage-${contracts.zklend}-1.0`,
    }
  )
)
