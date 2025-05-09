import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"
import { fromHex, toHex } from "viem"
import { generatePrivateKey } from "viem/accounts"

const MODULUS =
  21888242871839275222246405745257275088548364400416034343698204186575808495617n

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function randomHex() {
  return toHex(fromHex(generatePrivateKey(), "bigint") % MODULUS)
}
