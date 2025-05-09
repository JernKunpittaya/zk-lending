"use client"

import "@rainbow-me/rainbowkit/styles.css"

import { darkTheme, RainbowKitProvider } from "@rainbow-me/rainbowkit"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { State, WagmiProvider } from "wagmi"

import { config } from "@/config/wallet"

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      experimental_prefetchInRender: true,
    },
  },
})

export function Providers({
  children,
  initialState,
}: {
  children: React.ReactNode
  initialState?: State
}) {
  return (
    <WagmiProvider config={config} initialState={initialState}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider theme={darkTheme()}>{children}</RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
