import { useMutation, useQueryClient } from "@tanstack/react-query"
import { ExternalLink } from "lucide-react"
import { toast } from "sonner"
import { Hex } from "viem"
import { useAccount, useWriteContract } from "wagmi"

import { client, contracts, tokenAbi } from "@/lib/contract"

import { refreshTokenBalances } from "./use-token-balances"

export const useFaucet = () => {
  const queryClient = useQueryClient()
  const writeContract = useWriteContract()
  const { address } = useAccount()

  return useMutation({
    mutationFn: async ({ token, amount }: { token: Hex; amount: number }) => {
      console.log("token", token, amount, address)
      if (!address) return

      const tx = await writeContract.writeContractAsync({
        abi: tokenAbi,
        address: token,
        functionName: "mint",
        args: [address, BigInt(amount)],
      })

      const receipt = await client.waitForTransactionReceipt({
        hash: tx,
      })

      if (receipt.status !== "success") {
        throw new Error("Transaction failed", { cause: receipt })
      }

      refreshTokenBalances(queryClient)
      toast.success("Tokens minted", {
        description: `Tx hash: ${tx}`,
        action: {
          label: <ExternalLink className="size-4" />,
          onClick: () => {
            window.open(`${contracts.explorer}/tx/${tx}`, "_blank")
          },
        },
      })

      return receipt
    },
    onError: (error) => {
      toast.error("Failed to mint tokens", {
        description: error.message,
      })
    },
  })
}
