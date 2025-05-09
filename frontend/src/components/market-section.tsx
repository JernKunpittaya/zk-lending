import { ComponentProps, useState } from "react"
import _ from "lodash"

import { currencies } from "@/config/currency"
import { formatter } from "@/lib/formatter"
import { cn } from "@/lib/utils"
import { usePrices } from "@/hooks/use-prices"
import { useContractState } from "@/hooks/use-state"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "./ui/table"

export function MarketSection({ className, ...props }: ComponentProps<"div">) {
  const price = usePrices()
  const state = useContractState()

  const assets = [
    {
      name: currencies.weth.name,
      symbol: currencies.weth.symbol,
      icon: currencies.weth.icon,
      price: price.data?.weth || 0,
      deposits:
        state.data && state.data?.weth_deposit_amount
          ? Number(state.data?.weth_deposit_amount) / 1e6
          : 0,
      borrowed:
        state.data && state.data?.weth_borrow_amount
          ? Number(state.data?.weth_borrow_amount) / 1e6
          : 0,
      utilization: state.data
        ? Number(state.data?.weth_borrow_amount) /
          Number(state.data?.weth_deposit_amount)
        : 0,
    },
    {
      name: currencies.usdc.name,
      symbol: currencies.usdc.symbol,
      icon: currencies.usdc.icon,
      price: price.data?.usdc || 0,
      deposits:
        state.data && state.data?.usdc_deposit_amount
          ? Number(state.data?.usdc_deposit_amount) / 1e6
          : 0,
      borrowed:
        state.data && state.data?.usdc_borrow_amount
          ? Number(state.data?.usdc_borrow_amount) / 1e6
          : 0,
      utilization: state.data
        ? Number(state.data?.usdc_borrow_amount) /
          Number(state.data?.usdc_deposit_amount)
        : 0,
    },
  ]

  const total = {
    deposits: assets.reduce(
      (acc, asset) => acc + asset.deposits * asset.price,
      0
    ),
    borrowed: assets.reduce(
      (acc, asset) => acc + asset.borrowed * asset.price,
      0
    ),
    tvl: assets.reduce(
      (acc, asset) => acc + (asset.deposits - asset.borrowed) * asset.price,
      0
    ),
  }

  return (
    <div {...props} className={cn("border-border border pt-4", className)}>
      <h1 className="px-4 font-bold">Main Market</h1>
      <div className="grid grid-cols-3 gap-2 px-4 text-sm">
        <div>
          <div className="text-muted-foreground font-sans">Deposits</div>
          <div className="font-bold">{formatter.usd(total.deposits)}</div>
        </div>
        <div>
          <div className="text-muted-foreground font-sans">Borrowed</div>
          <div className="font-bold">{formatter.usd(total.borrowed)}</div>
        </div>
        <div>
          <div className="text-muted-foreground font-sans">TVL</div>
          <div className="font-bold">{formatter.usd(total.tvl)}</div>
        </div>
      </div>
      <Table className="border-t">
        <TableHeader className="*:*:text-muted-foreground font-sans text-xs *:*:first:pl-4 *:*:last:pr-4">
          <TableRow>
            <TableHead>Assets</TableHead>
            <TableHead>Deposits</TableHead>
            <TableHead>Borrowed</TableHead>
            <TableHead>Utilization</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {assets.map((asset) => (
            <TableRow key={asset.name}>
              <TableCell className="flex items-center gap-2 pl-4">
                <img
                  src={asset.icon}
                  alt={asset.name}
                  className="size-8 shrink-0 rounded-full"
                />
                <div>
                  <div className="font-bold">{asset.name}</div>
                  <div className="text-muted-foreground">
                    {formatter.usd(asset.price)}
                  </div>
                </div>
              </TableCell>
              <TableCell>
                <div className="font-bold">
                  {formatter.number(asset.deposits)}
                </div>
                <div className="text-muted-foreground">
                  {formatter.usd(asset.price * asset.deposits)}
                </div>
              </TableCell>
              <TableCell>
                <div className="font-bold">
                  {formatter.number(asset.borrowed)}
                </div>
                <div className="text-muted-foreground">
                  {formatter.usd(asset.price * asset.borrowed)}
                </div>
              </TableCell>
              <TableCell>
                {_.isNaN(asset.utilization)
                  ? "-"
                  : formatter.percent(asset.utilization)}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
