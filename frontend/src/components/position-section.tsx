import { ComponentProps, useMemo, useState } from "react"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { ExternalLink, Loader2, Plus } from "lucide-react"
import { toast } from "sonner"
import { decodeEventLog, fromHex, pad, toHex } from "viem"
import { useAccount, useWriteContract } from "wagmi"

import { currencies } from "@/config/currency"
import { client, contracts, tokenAbi, zkLendAbi } from "@/lib/contract"
import { formatter } from "@/lib/formatter"
import { cn } from "@/lib/utils"
import { Position, usePositionStore } from "@/hooks/use-position"
import { usePrices } from "@/hooks/use-prices"
import { useProvePosition } from "@/hooks/use-prove-position"
import { refreshContractState, useContractState } from "@/hooks/use-state"
import {
  refreshTokenBalances,
  useTokenBalances,
} from "@/hooks/use-token-balances"

import { NewPositionDialog } from "./new-position-dialog"
import { Button } from "./ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "./ui/dialog"
import { Input } from "./ui/input"

export function PositionSection({
  className,
  ...props
}: ComponentProps<"div">) {
  const { address } = useAccount()
  const { positions } = usePositionStore()
  return (
    <div
      className={cn("border-border space-y-4 border p-4", className)}
      {...props}
    >
      <div className="flex items-center justify-between gap-2">
        <h1 className="font-bold">Your Positions</h1>
        {address && (
          <NewPositionDialog>
            <Button>
              New Position <Plus />
            </Button>
          </NewPositionDialog>
        )}
      </div>
      {!positions.length ? (
        <div className="text-muted-foreground p-4 text-center">
          You have no active positions
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {positions.map((position) => (
            <PositionCard key={position.id} position={position} />
          ))}
        </div>
      )}
    </div>
  )
}

export function PositionCard({ position }: { position: Position }) {
  const price = usePrices()

  const [depositAmount, depositValue] = useMemo(() => {
    return [
      Number(position.lendAmt) / 1e6,
      (price.data?.weth || 0) * (Number(position.lendAmt) / 1e6),
    ] as const
  }, [position.lendAmt, price.data?.weth])

  const [borrowAmount, borrowValue] = useMemo(() => {
    return [
      Number(position.borrowAmt) / 1e6,
      (price.data?.weth || 0) * (Number(position.borrowAmt) / 1e6),
    ] as const
  }, [position.borrowAmt, price.data?.weth])

  const [maxBorrow, maxBorrowPercent] = useMemo(() => {
    // at 50% ltv
    if (position.depositToken === "weth") {
      return [
        depositAmount * 0.5 * position.willLiqPriceWeth,
        depositAmount === 0 || position.willLiqPriceWeth === 0
          ? 0
          : borrowAmount / (depositAmount * 0.5 * position.willLiqPriceWeth),
      ] as const
    }
    return [
      (depositAmount * 0.5) / position.willLiqPriceWeth,
      depositAmount === 0 || position.willLiqPriceWeth === 0
        ? 0
        : borrowAmount / ((depositAmount * 0.5) / position.willLiqPriceWeth),
    ] as const
  }, [depositAmount, borrowAmount, position.willLiqPriceWeth])

  const healthFactor = useMemo(() => {
    // current price of deposit token from liquidation price, nothing else
    const currentDepositPrice = price.data?.weth || 0
    return (
      Math.abs(currentDepositPrice - position.willLiqPriceWeth) /
      currentDepositPrice
    )
  }, [price.data, position.depositToken])

  const balances = useTokenBalances()
  const state = useContractState()

  const writeContract = useWriteContract()
  const queryClient = useQueryClient()

  const { address } = useAccount()
  const prove = useProvePosition()
  const { replacePosition } = usePositionStore()

  const proveAndExecute = useMutation({
    mutationFn: async ({
      action,
      lendTokenIn,
      borrowTokenIn,
      lendTokenOut,
      borrowTokenOut,
    }: {
      action: "deposit" | "borrow" | "repay" | "withdraw"
      lendTokenIn: bigint
      borrowTokenIn: bigint
      lendTokenOut: bigint
      borrowTokenOut: bigint
    }) => {
      if (!address) {
        throw new Error("No account")
      }
      const approval = await client.readContract({
        address: contracts[position.depositToken],
        abi: tokenAbi,
        functionName: "allowance",
        args: [address, contracts.zklend],
      })
      const fullAmount =
        lendTokenIn + borrowTokenIn + lendTokenOut + borrowTokenOut
      if (
        approval < fullAmount &&
        (action === "deposit" || action === "repay")
      ) {
        const tx = await writeContract.writeContractAsync({
          address:
            lendTokenIn > 0
              ? contracts[position.depositToken]
              : contracts[position.borrowToken],
          abi: tokenAbi,
          functionName: "approve",
          args: [
            contracts.zklend,
            100000000000000000000000000000000000000000000000000000000000000000000000000000n,
          ],
        })
        await client.waitForTransactionReceipt({
          hash: tx,
        })
      }

      const { new_note, proof, willLiqPrice, ...inputs } =
        await prove.mutateAsync({
          oldPosition: position,
          lendTokenIn,
          borrowTokenIn,
          lendTokenOut,
          borrowTokenOut,
          willLiqPrice: fromHex(position.willLiqPrice, "bigint"),
        })
      const newPosition: Position = {
        ...position,
        borrowAmt: new_note.borrow_amt,
        lendAmt: new_note.lend_amt,
        timestamp: fromHex(new_note.timestamp, "number"),
        nullifier: new_note.nullifier,
        nonce: new_note.nonce,
      }
      const tx = await writeContract.writeContractAsync({
        address: contracts.zklend,
        abi: zkLendAbi,
        functionName: action,
        args: [
          ...[
            pad(inputs.new_note_hash),
            pad(new_note.will_liq_price),
            fromHex(new_note.timestamp, "bigint"),
            pad(inputs.root),
            pad(inputs.old_nullifier),
            toHex(proof),
            fullAmount,
            action === "borrow" || action === "repay"
              ? contracts[position.borrowToken]
              : contracts[position.depositToken],
          ],
          ...(action === "borrow" || action === "withdraw" ? [address] : []),
        ] as any,
      })
      const receipt = await client.waitForTransactionReceipt({
        hash: tx,
      })
      if (receipt.status !== "success") {
        throw new Error("Transaction reverted")
      }
      const event = decodeEventLog({
        abi: zkLendAbi,
        topics: receipt.logs[1].topics,
        data: receipt.logs[1].data,
        eventName: "CommitmentAdded",
      })
      newPosition.leafIndex = event.args.leafIndex
      replacePosition(position.id, newPosition)
      refreshContractState(queryClient)
      refreshTokenBalances(queryClient)
      toast.success("Position updated", {
        description: `Tx hash: ${tx}`,
        action: {
          label: <ExternalLink className="size-4" />,
          onClick: () => {
            window.open(`${contracts.explorer}/tx/${tx}`, "_blank")
          },
        },
      })
    },
    onError: (error) => {
      toast.error("Failed to update position", {
        description: error.message,
      })
    },
  })

  return (
    <div className="border-border space-y-2 border p-4">
      <h1 className="font-bold">Position {position.id.slice(0, 6)}</h1>
      <div className="flex items-center gap-2">
        <div className="text-muted-foreground text-xs">Deposited</div>
        <div className="ml-auto text-end">
          <div>{formatter.number(depositAmount)}</div>
          <div className="text-muted-foreground text-xs">
            {formatter.usd(depositValue)}
          </div>
        </div>
        <img src={currencies[position.depositToken].icon} className="size-6" />
      </div>
      <div className="flex items-center gap-2">
        <div className="text-muted-foreground text-xs">Borrowed</div>
        <div className="ml-auto text-end">
          <div>{formatter.number(borrowAmount)}</div>
          <div className="text-muted-foreground text-xs">
            {formatter.usd(borrowValue)}
          </div>
        </div>
        <img src={currencies[position.borrowToken].icon} className="size-6" />
      </div>
      <div className="flex items-center gap-2">
        <div className="text-muted-foreground text-xs">Max Borrow</div>
        <div className="ml-auto">
          {formatter.number(maxBorrow)} ({formatter.percent(maxBorrowPercent)})
        </div>
        <img src={currencies[position.borrowToken].icon} className="size-6" />
      </div>
      <div className="flex items-center gap-2">
        <div className="text-muted-foreground text-xs">Liquidation Price</div>
        <div className="ml-auto text-end">
          {formatter.usd(position.willLiqPriceWeth)}
        </div>
      </div>
      <div className="flex items-center gap-2">
        <div className="text-muted-foreground text-xs">
          <div>Health</div>
          <div>*Liq when 100%*</div>
        </div>
        <div className="ml-auto text-end">
          {formatter.percent(healthFactor)}
        </div>
      </div>
      <BorrowDialog
        position={position}
        borrow={(amt) =>
          proveAndExecute.mutateAsync({
            action: "borrow",
            lendTokenIn: 0n,
            borrowTokenIn: amt,
            lendTokenOut: 0n,
            borrowTokenOut: 0n,
          })
        }
        isBorrowing={proveAndExecute.isPending}
        maxBorrow={maxBorrow - borrowAmount}
      />
    </div>
  )
}

export function BorrowDialog({
  position,
  borrow,
  isBorrowing,
  maxBorrow,
}: {
  position: Position
  borrow: (amount: bigint) => Promise<void>
  isBorrowing: boolean
  maxBorrow: number
}) {
  const state = useContractState()
  const limit = useMemo(() => {
    const available =
      Number(
        position.depositToken === "weth"
          ? (state.data?.usdc_deposit_amount || 0n) -
              (state.data?.usdc_borrow_amount || 0n)
          : (state.data?.weth_deposit_amount || 0n) -
              (state.data?.weth_borrow_amount || 0n)
      ) / 1e6
    return Math.min(maxBorrow, available)
  }, [maxBorrow, state.data])
  const [amount, setAmount] = useState("0")
  const amountNumber = useMemo(() => {
    return parseFloat(amount)
  }, [amount])
  const [isBorrowOpen, setIsBorrowOpen] = useState(false)
  return (
    <Dialog open={isBorrowOpen} onOpenChange={setIsBorrowOpen}>
      <DialogTrigger asChild>
        <Button size="sm" className="mt-2 w-full" variant="secondary">
          Borrow
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Borrow</DialogTitle>
          <DialogDescription>
            Borrow tokens from your position
          </DialogDescription>
        </DialogHeader>
        <div className="flex items-center justify-end gap-2">
          Borrow limit: {formatter.number(limit)}
          <img src={currencies[position.borrowToken].icon} className="size-4" />
        </div>
        <Input
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="Amount"
        />
        <DialogFooter>
          <Button
            disabled={isBorrowing || !amountNumber || amountNumber > limit}
            onClick={async () => {
              await borrow(BigInt(amountNumber * 1e6))
              setIsBorrowOpen(false)
            }}
          >
            {isBorrowing ? "Borrowing..." : "Borrow"}
            {isBorrowing && <Loader2 className="animate-spin" />}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
