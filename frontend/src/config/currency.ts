import { contracts } from "@/lib/contract"

export const currencies = {
  weth: {
    key: "weth",
    name: "Ethereum",
    symbol: "ETH",
    decimals: 6,
    address: contracts.weth,
    icon: "https://icons.iconarchive.com/icons/cjdowner/cryptocurrency-flat/512/Ethereum-ETH-icon.png",
    faucetAmount: 500_000, // 0.5 ETH
  },
  usdc: {
    key: "usdc",
    name: "USD Coin",
    symbol: "USDC",
    decimals: 6,
    address: contracts.usdc,
    icon: "https://assets.coingecko.com/coins/images/6319/small/usdc.png?1746042285",
    faucetAmount: 1000_000_000, // 1000 USD
  },
} as const
