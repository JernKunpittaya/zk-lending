import { QueryClient, useQuery } from "@tanstack/react-query"

export const refreshPrices = (queryClient: QueryClient) => {
  queryClient.invalidateQueries({ queryKey: ["prices"], exact: true })
}

export const usePrices = () => {
  return useQuery({
    queryKey: ["prices"],
    queryFn: async () => {
      const response = await fetch(
        "https://api.coingecko.com/api/v3/coins/ethereum"
      )
      const data = await response.json()
      return { weth: data.market_data.current_price.usd as number, usdc: 1 }
    },
    refetchInterval: 1000 * 30, // 30 seconds
  })
}
