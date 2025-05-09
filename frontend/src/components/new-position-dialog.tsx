import { ComponentProps, useEffect, useMemo, useState } from "react"
import { zodResolver } from "@hookform/resolvers/zod"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import _ from "lodash"
import { ExternalLink, Loader2, Minus, Plus, Wallet } from "lucide-react"
import { useForm, useWatch } from "react-hook-form"
import { toast } from "sonner"
import { decodeEventLog, fromHex, Hex, pad, padHex, toHex } from "viem"
import { useAccount, useWriteContract } from "wagmi"
import { z } from "zod"

import { currencies } from "@/config/currency"
import { client, contracts, tokenAbi, zkLendAbi } from "@/lib/contract"
import { formatter } from "@/lib/formatter"
import { randomHex } from "@/lib/utils"
import { Position, usePositionStore } from "@/hooks/use-position"
import { usePrices } from "@/hooks/use-prices"
import { useProvePosition } from "@/hooks/use-prove-position"
import { refreshContractState } from "@/hooks/use-state"
import {
  refreshTokenBalances,
  useTokenBalances,
} from "@/hooks/use-token-balances"

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
import { Form } from "./ui/form"
import { Input } from "./ui/input"
import { Slider } from "./ui/slider"
import { Toggle } from "./ui/toggle"
import { ToggleGroup, ToggleGroupItem } from "./ui/toggle-group"

const formSchema = z.object({
  step: z.number(),
  depositToken: z.enum(["weth", "usdc"]),
  borrowToken: z.enum(["weth", "usdc"]),
  liquidationPrice: z.number(),
  initialAmount: z.string(),
})

export function NewPositionDialog({
  children,
  ...props
}: ComponentProps<typeof Dialog>) {
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      step: 1,
      depositToken: "weth",
      borrowToken: "usdc",
      liquidationPrice: 2500,
      initialAmount: "0",
    },
  })

  const step = useWatch({
    control: form.control,
    name: "step",
  })

  const depositToken = useWatch({
    control: form.control,
    name: "depositToken",
  })
  const borrowToken = useWatch({
    control: form.control,
    name: "borrowToken",
  })
  const liquidationPrice = useWatch({
    control: form.control,
    name: "liquidationPrice",
  })

  const prices = usePrices()
  const liquidationPrices = useMemo(() => {
    if (depositToken === "usdc") {
      const wethPriceTruncatedToHundreds =
        Math.ceil((prices.data?.weth ?? 0) / 100) * 100
      const p = _.range(10).map(
        (i) => wethPriceTruncatedToHundreds + 100 + i * 100
      )
      form.setValue("liquidationPrice", p[0])
      return p
    } else {
      const wethPriceTruncatedToHundreds =
        Math.floor((prices.data?.weth ?? 0) / 100) * 100
      const p = _.range(10).map(
        (i) => wethPriceTruncatedToHundreds - 100 - i * 100
      )
      p.reverse()
      form.setValue("liquidationPrice", p[0])
      return p
    }
  }, [depositToken, prices.data])

  const balances = useTokenBalances()

  const initialAmount = useWatch({
    control: form.control,
    name: "initialAmount",
  })
  const initialAmountNumber = useMemo(() => {
    return parseFloat(initialAmount)
  }, [initialAmount])
  const maxBorrowAmount = useMemo(() => {
    // max 50% ltv
    if (depositToken === "weth") {
      return initialAmountNumber * 0.5 * liquidationPrice
    } else {
      return (initialAmountNumber * 0.5) / liquidationPrice
    }
  }, [initialAmountNumber, liquidationPrice, depositToken])

  const writeContract = useWriteContract()
  const queryClient = useQueryClient()

  const { address } = useAccount()
  const prove = useProvePosition()
  const { addPosition } = usePositionStore()

  const proveAndExecute = useMutation({
    mutationFn: async () => {
      if (!address) {
        throw new Error("No account")
      }
      const approval = await client.readContract({
        address: contracts[depositToken],
        abi: tokenAbi,
        functionName: "allowance",
        args: [address, contracts.zklend],
      })
      const fullAmount = BigInt(initialAmountNumber * 1e6)
      if (approval < fullAmount) {
        const tx = await writeContract.writeContractAsync({
          address: contracts[depositToken],
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

      const emptyPosition: Position = {
        borrowAmt: toHex(0n),
        lendAmt: toHex(0n),
        willLiqPrice: toHex(0n),
        timestamp: 0,
        nullifier: toHex(0n),
        nonce: randomHex(),
        depositToken,
        borrowToken,
        id: randomHex(),
        leafIndex: null,
        willLiqPriceWeth: 0,
      }
      const { new_note, proof, willLiqPrice, ...inputs } =
        await prove.mutateAsync({
          oldPosition: emptyPosition,
          lendTokenIn: fullAmount,
          borrowTokenIn: 0n,
          lendTokenOut: 0n,
          borrowTokenOut: 0n,
          willLiqPrice:
            depositToken === "weth"
              ? BigInt(liquidationPrice * 1e4)
              : BigInt(Math.floor((1 / liquidationPrice) * 1e4)),
        })
      const newPosition: Position = {
        ...emptyPosition,
        borrowAmt: new_note.borrow_amt,
        lendAmt: new_note.lend_amt,
        timestamp: fromHex(new_note.timestamp, "number"),
        nullifier: new_note.nullifier,
        nonce: new_note.nonce,
        willLiqPrice: toHex(willLiqPrice),
        willLiqPriceWeth: liquidationPrice,
      }
      const tx = await writeContract.writeContractAsync({
        address: contracts.zklend,
        abi: zkLendAbi,
        functionName: "deposit",
        args: [
          pad(inputs.new_note_hash),
          pad(new_note.will_liq_price),
          fromHex(new_note.timestamp, "bigint"),
          pad(inputs.root as Hex),
          pad(inputs.old_nullifier),
          toHex(proof),
          fullAmount,
          contracts[depositToken],
        ],
      })
      const receipt = await client.waitForTransactionReceipt({
        hash: tx,
      })
      const event = decodeEventLog({
        abi: zkLendAbi,
        topics: receipt.logs[0].topics,
        data: receipt.logs[0].data,
        eventName: "CommitmentAdded",
      })
      newPosition.leafIndex = event.args.leafIndex
      console.log("newPosition", newPosition)
      addPosition(newPosition)
      refreshContractState(queryClient)
      refreshTokenBalances(queryClient)
      toast.success("Position created", {
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
      toast.error("Failed to create position", {
        description: error.message,
      })
    },
  })

  return (
    <Dialog {...props}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New Position</DialogTitle>
          <DialogDescription>
            Create a new position to start depositing and borrowing
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4 text-sm">
          {step === 1 && (
            <>
              <div className="font-sans">Step 1: Choose position type</div>
              <ToggleGroup
                type="single"
                value={depositToken || ""}
                onValueChange={(value) => {
                  if (value === "weth") {
                    form.setValue("borrowToken", "usdc")
                    form.setValue("depositToken", "weth")
                  } else {
                    form.setValue("borrowToken", "weth")
                    form.setValue("depositToken", "usdc")
                  }
                }}
                className="grid w-full grid-cols-2 gap-4 *:aspect-square *:h-full"
              >
                <ToggleGroupItem value="weth">
                  <div>
                    <div className="flex items-center gap-1">
                      Deposit WETH
                      <img
                        src={currencies.weth.icon}
                        className="size-4 rounded-full"
                      />{" "}
                      <Plus className="text-green-400" />
                    </div>
                    <div className="flex items-center gap-1">
                      Borrow USDC
                      <img
                        src={currencies.usdc.icon}
                        className="size-4 rounded-full"
                      />{" "}
                      <Minus className="text-red-400" />
                    </div>
                  </div>
                </ToggleGroupItem>
                <ToggleGroupItem value="usdc">
                  <div>
                    <div className="flex items-center gap-1">
                      Deposit USDC{" "}
                      <img
                        src={currencies.usdc.icon}
                        className="size-4 rounded-full"
                      />{" "}
                      <Plus className="text-green-400" />
                    </div>
                    <div className="flex items-center gap-1">
                      Borrow WETH
                      <img
                        src={currencies.weth.icon}
                        className="size-4 rounded-full"
                      />{" "}
                      <Minus className="text-red-400" />
                    </div>
                  </div>
                </ToggleGroupItem>
              </ToggleGroup>
              <DialogFooter>
                <Button
                  onClick={() => form.setValue("step", 2)}
                  disabled={!depositToken || !borrowToken}
                  className="ml-auto"
                >
                  Next
                </Button>
              </DialogFooter>
            </>
          )}
          {step === 2 && (
            <>
              <div className="font-sans">
                Step 2: Configure Liquidation Price & Initial Amount
              </div>
              <Slider
                step={100}
                min={liquidationPrices[0]}
                max={liquidationPrices[liquidationPrices.length - 1]}
                value={[form.watch("liquidationPrice")]}
                onValueChange={(value) => {
                  form.setValue("liquidationPrice", value[0])
                }}
              />
              <div className="space-y-2">
                <div className="flex justify-between">
                  <div className="text-muted-foreground">
                    Liquidation Price (wETH):
                  </div>
                  <div>{formatter.usd(form.watch("liquidationPrice"))}</div>
                </div>
                <div className="flex justify-between">
                  <div className="text-muted-foreground">Max LTV</div>
                  <div>50%</div>
                </div>
                <div className="flex items-center gap-2">
                  <div className="text-muted-foreground">Initial Deposit</div>
                  <Wallet className="ml-auto size-4" />
                  <div>
                    {formatter.number(balances.data?.[depositToken] ?? 0)}
                  </div>
                  <img src={currencies[depositToken].icon} className="size-4" />
                </div>
                <Input {...form.register("initialAmount")} />
                <div className="flex items-center gap-2">
                  <div className="text-muted-foreground">Max Borrow</div>
                  <div className="ml-auto">
                    {!maxBorrowAmount ? "-" : formatter.number(maxBorrowAmount)}
                  </div>
                  <img src={currencies[borrowToken].icon} className="size-4" />
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => form.reset()}>
                  Back
                </Button>
                <Button
                  disabled={
                    !initialAmountNumber ||
                    !maxBorrowAmount ||
                    initialAmountNumber > (balances.data?.[depositToken] || 0)
                  }
                  onClick={() => form.setValue("step", 3)}
                >
                  Next
                </Button>
              </DialogFooter>
            </>
          )}
          {step === 3 && (
            <>
              <div className="font-sans">Step 3: Prove And Create Position</div>
              <div className="space-y-2">
                <div className="flex justify-between">
                  <div className="text-muted-foreground">
                    Current Price (wETH):
                  </div>
                  <div>{formatter.usd(prices.data?.weth ?? 0)}</div>
                </div>
                <div className="flex justify-between">
                  <div className="text-muted-foreground">
                    Liquidation Price (wETH):
                  </div>
                  <div>{formatter.usd(form.watch("liquidationPrice"))}</div>
                </div>
                <div className="flex justify-between">
                  <div className="text-muted-foreground">Max LTV</div>
                  <div>50%</div>
                </div>
                <div className="flex items-center gap-2">
                  <div className="text-muted-foreground">Initial Deposit</div>
                  <div className="ml-auto">
                    {formatter.number(initialAmountNumber)}
                  </div>
                  <img src={currencies[depositToken].icon} className="size-4" />
                </div>
                <div className="flex items-center gap-2">
                  <div className="text-muted-foreground">Maximum Borrow</div>
                  <div className="ml-auto">
                    {formatter.number(maxBorrowAmount)}
                  </div>
                  <img src={currencies[borrowToken].icon} className="size-4" />
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => form.reset()}>
                  Reset
                </Button>
                <Button
                  disabled={proveAndExecute.isPending}
                  onClick={() => proveAndExecute.mutate()}
                >
                  {proveAndExecute.isPending
                    ? "Proving..."
                    : "Prove And Create"}
                  {proveAndExecute.isPending ? (
                    <Loader2 className="size-4 animate-spin" />
                  ) : (
                    <Plus />
                  )}
                </Button>
              </DialogFooter>
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}
