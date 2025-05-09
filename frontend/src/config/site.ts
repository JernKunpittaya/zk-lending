import { env } from "@/env.mjs"

export const siteConfig = {
  name: "Noiri",
  author: "Jernkul, Yoyoismee, Yoisha",
  description: "Noiri - ZK Lending Protocol on Steriod",
  keywords: [],
  url: {
    base: env.NEXT_PUBLIC_APP_URL,
    author: "Author",
  },
  twitter: "",
  favicon: "/favicon.ico",
  ogImage: `${env.NEXT_PUBLIC_APP_URL}/og.jpg`,
}
