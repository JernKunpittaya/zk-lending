import { ComponentProps } from "react"

import { cn } from "@/lib/utils"

export function PositionSection({
  className,
  ...props
}: ComponentProps<"div">) {
  return (
    <div className={cn("border-border border p-4", className)} {...props}>
      <h1 className="font-bold">Your Positions</h1>
    </div>
  )
}
