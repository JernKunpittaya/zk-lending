import { ComponentProps } from "react"
import _ from "lodash"
import { Loader2 } from "lucide-react"
import { useAccount } from "wagmi"

import { currencies } from "@/config/currency"
import { formatter } from "@/lib/formatter"
import { cn } from "@/lib/utils"
import { useFaucet } from "@/hooks/use-faucet"
import { useTokenBalances } from "@/hooks/use-token-balances"

import { Button } from "./ui/button"

export function AccountSection({ className, ...props }: ComponentProps<"div">) {
  const { address } = useAccount()
  const balance = useTokenBalances()
  const faucet = useFaucet()

  return (
    <div {...props} className={cn(className)}>
      <div className="border-border space-y-4 border p-4">
        <div className="flex items-center justify-between gap-2">
          <h1 className="font-bold">Account</h1>
        </div>
        {!address ? (
          <div className="text-muted-foreground p-4 text-center">
            Please connect your wallet
          </div>
        ) : (
          <div className="space-y-2">
            {_.entries(currencies).map(([key, currency]) => (
              <div key={currency.address} className="flex items-center gap-2">
                <img
                  src={currency.icon}
                  alt={currency.name}
                  className="size-6 shrink-0 rounded-full"
                />
                <div className="font-bold">{currency.symbol}</div>
                <div className="ml-auto">
                  {formatter.number(balance.data?.[currency.key])}
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={
                    faucet.isPending &&
                    faucet.variables?.token === currency.address
                  }
                  onClick={() =>
                    faucet.mutateAsync({
                      token: currency.address,
                      amount: currency.faucetAmount,
                    })
                  }
                >
                  Faucet{" "}
                  {faucet.isPending &&
                    faucet.variables?.token === currency.address && (
                      <Loader2 className="animate-spin" />
                    )}
                </Button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
