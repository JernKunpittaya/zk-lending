import { QueryClient, useQuery } from "@tanstack/react-query"

import { client, contracts, zkLendAbi } from "@/lib/contract"

export const refreshContractState = (queryClient: QueryClient) => {
  queryClient.invalidateQueries({
    queryKey: ["state", contracts.zklend],
    exact: true,
  })
}

export const useContractState = () => {
  return useQuery({
    queryKey: ["state", contracts.zklend],
    queryFn: async () => {
      const state = await client.readContract({
        abi: zkLendAbi,
        address: contracts.zklend,
        functionName: "state",
      })
      return state
    },
  })
}
