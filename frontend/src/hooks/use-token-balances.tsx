import { useQuery } from "@tanstack/react-query"
import { useAccount, useClient } from "wagmi"

import { client, contracts, tokenAbi } from "@/lib/contract"

export const useTokenBalances = () => {
  const { address } = useAccount()
  return useQuery({
    queryKey: ["token-balances", address],
    queryFn: async () => {
      if (!address) return { usdc: 0, weth: 0 }
      const results = await client.multicall({
        contracts: [
          {
            abi: tokenAbi,
            address: contracts.usdc,
            functionName: "balanceOf",
            args: [address],
          },
          {
            abi: tokenAbi,
            address: contracts.weth,
            functionName: "balanceOf",
            args: [address],
          },
        ],
      })
      return {
        usdc: Number(results[0].result) / 1e6,
        weth: Number(results[1].result) / 1e6,
      }
    },
  })
}
