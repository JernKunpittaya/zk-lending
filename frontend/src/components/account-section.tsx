import { ComponentProps } from "react"

export function AccountSection({ ...props }: ComponentProps<"div">) {
  return (
    <div {...props}>
      <div className="border-border border p-4">
        <h1 className="font-bold">Account</h1>
      </div>
    </div>
  )
}
