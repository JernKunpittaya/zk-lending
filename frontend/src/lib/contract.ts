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
  usdc: "0x0729b1C8aE8AbBF95dAB6F0835CF9962C29c7344",
  weth: "0x9c56316255cff57cbeb8a0418c8f5d4f9523588f",
  verifier: "0x40C106c9F4B74b16a5829B6014b0d99896eDE503",
  zklend: "0xda574377faFB3775e8A1bC547a9BA387f1c749C5",
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
