import { ComponentProps } from "react"
import _ from "lodash"

import { formatter } from "@/lib/formatter"
import { cn } from "@/lib/utils"

import { Button } from "./ui/button"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "./ui/table"

const assets = [
  {
    name: "ETH",
    icon: "https://icons.iconarchive.com/icons/cjdowner/cryptocurrency-flat/512/Ethereum-ETH-icon.png",
    price: 1806.5,
    deposits: 230.01,
    borrowed: 78.89,
    utilization: 0.3429,
  },
  {
    name: "USDC",
    icon: "https://assets.coingecko.com/coins/images/6319/small/usdc.png?1746042285",
    price: 1.0001,
    deposits: 45678.9,
    borrowed: 23456.78,
    utilization: 0.5135,
  },
]

export function MarketSection({ className, ...props }: ComponentProps<"div">) {
  return (
    <div {...props} className={cn("border-border border pt-4", className)}>
      <h1 className="px-4 font-bold">Main Market</h1>
      <div className="grid grid-cols-3 gap-2 px-4 text-sm">
        <div>
          <div className="text-muted-foreground font-sans">Deposits</div>
          <div className="font-bold">$12,493.32</div>
        </div>
        <div>
          <div className="text-muted-foreground font-sans">Borrowed</div>
          <div className="font-bold">$12,493.32</div>
        </div>
        <div>
          <div className="text-muted-foreground font-sans">TVL</div>
          <div className="font-bold">$12,493.32</div>
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
              <TableCell>{formatter.percent(asset.utilization)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
