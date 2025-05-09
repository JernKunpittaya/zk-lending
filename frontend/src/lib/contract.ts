import { createPublicClient, http, parseAbi } from "viem"
import { sepolia } from "viem/chains"

export const tokenAbi = parseAbi([
  "function transfer(address to, uint256 amount) returns (bool)",
  "function balanceOf(address account) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function transferFrom(address from, address to, uint256 amount) returns (bool)",
  "function totalSupply() view returns (uint256)",
  "function mint(address to, uint256 amount) returns (bool)",
])

export const zkLendAbi = parseAbi([
  "struct State { int256 weth_deposit_amount; int256 weth_borrow_amount; int256 usdc_deposit_amount; int256 usdc_borrow_amount; }",
  "function state() view returns (State)",
  "function weth() view returns (address)",
  "function usdc() view returns (address)",
  "function deposit(bytes32 _new_note_hash, bytes32 _new_will_liq_price, uint256 _new_timestamp, bytes32 _root, bytes32 _old_nullifier, bytes calldata _proof, uint256 _lend_amt, address _lend_token)",
  "function borrow(bytes32 _new_note_hash, bytes32 _new_will_liq_price, uint256 _new_timestamp, bytes32 _root, bytes32 _old_nullifier, bytes calldata _proof, uint256 _borrow_amt, address _borrow_token, address _to)",
  "function repay(bytes32 _new_note_hash, bytes32 _new_will_liq_price, uint256 _new_timestamp, bytes32 _root, bytes32 _old_nullifier, bytes calldata _proof, uint256 _repay_amt, address _repay_token)",
  "function withdraw(bytes32 _new_note_hash, bytes32 _new_will_liq_price, uint256 _new_timestamp, bytes32 _root, bytes32 _old_nullifier, bytes calldata _proof, uint256 _withdraw_amt, address _withdraw_token, address _to)",
  "event CommitmentAdded(bytes32 indexed commitment, uint32 indexed leafIndex)",
  "event Deposit(bytes32 nullifierHash, uint256 timestamp)",
  "event Borrow(address to, bytes32 nullifierHash, uint256 timestamp)",
  "event Repay(bytes32 nullifierHash, uint256 timestamp)",
  "event Withdraw(address to, bytes32 nullifierHash, uint256 timestamp)",
])

export const contracts = {
  usdc: "0x3770952b41b1346215F0b8733760ce222b28506c",
  weth: "0x96705944c7e4e6325D4a2ee7e2a7b586EB1490F1",
  verifier: "0xC2d3d1e6649f8e4697E2b339af56DA5ADd2af186",
  zklend: "0xcB9d899d7f14Dca9EF05D9DaA5D01DaFE6B5BD24",
  explorer: "https://sepolia.etherscan.io",
} as const

export const client = createPublicClient({
  transport: http(sepolia.rpcUrls.default.http[0], {
    batch: true,
  }),
  chain: sepolia,
  batch: {
    multicall: true,
  },
})
