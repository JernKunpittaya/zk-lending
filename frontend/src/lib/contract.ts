import { parseAbi } from "viem"

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
  "event Deposit(bytes32 indexed commitment, bytes32 nullifierHash, uint32 leafIndex, uint256 timestamp)",
  "event Borrow(bytes32 indexed commitment, address to, bytes32 nullifierHash, uint32 leafIndex, uint256 timestamp)",
  "event Repay(bytes32 indexed commitment, bytes32 nullifierHash, uint32 leafIndex, uint256 timestamp)",
  "event Withdraw(bytes32 indexed commitment, address to, bytes32 nullifierHash, uint32 leafIndex, uint256 timestamp)",
])

export const contracts = {
  usdc: "0xacf706de76dce4db1350917d39dbb68dd8bda8e4",
  weth: "0x00ea46082024f5b0c8c3e120d6442f92fa1c7f99",
  verifier: "0xdf003194e800e5f29dcf65d1a5e4fbb8e5f01bdc",
  zklend: "0xe30b1924b952b3013ca62417c8bb3ea3e79f5a27",
}
