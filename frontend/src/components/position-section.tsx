import { ComponentProps } from "react"
import { Plus } from "lucide-react"
import { useAccount } from "wagmi"

import { cn } from "@/lib/utils"

import { NewPositionDialog } from "./new-position-dialog"
import { Button } from "./ui/button"

export function PositionSection({
  className,
  ...props
}: ComponentProps<"div">) {
  const { address } = useAccount()
  return (
    <div className={cn("border-border border p-4", className)} {...props}>
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
      <div className="text-muted-foreground p-4 text-center">
        You have no active positions
      </div>
    </div>
  )
}
