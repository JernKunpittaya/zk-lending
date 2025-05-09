import { useMutation } from "@tanstack/react-query"
import { MerkleTree } from "fixed-merkle-tree"
import _ from "lodash"
import { poseidon2, poseidon6 } from "poseidon-lite"
import { toast } from "sonner"
import { fromHex, Hex, toHex } from "viem"
import { generatePrivateKey } from "viem/accounts"
import { useAccount } from "wagmi"

import { client, contracts, zkLendAbi } from "@/lib/contract"

import { Position, usePositionStore } from "./use-position"

const hash_note = (note: any) => {
  return toHex(
    poseidon6([
      note.lend_amt,
      note.borrow_amt,
      note.will_liq_price,
      note.timestamp,
      note.nullifier,
      note.nonce,
    ])
  )
}

const MODULUS =
  21888242871839275222246405745257275088548364400416034343698204186575808495617n

const BORROW_INTEREST_RATE = 10n
const LEND_INTEREST_RATE = 3n

const updateAmount = (
  old_amount: bigint,
  old_timestamp: bigint,
  new_timestamp: bigint,
  interest_rate: bigint
) => {
  // const one_year_seconds = 31536000n
  // const time_diff = new_timestamp - old_timestamp
  // const res =
  //   ((one_year_seconds + interest_rate * time_diff) * old_amount) /
  //   one_year_seconds
  // return res
  return old_amount
}

export async function initProver() {
  const [{ Noir }, { UltraHonkBackend }] = await Promise.all([
    import("@noir-lang/noir_js"),
    import("@aztec/bb.js"),
  ])
  const circuit = await import("../../zk_lending.json")
  return { Noir, UltraHonkBackend, circuit: circuit.default }
}

export async function getLeafs() {
  const currentBlock = await client.getBlockNumber()
  const events = await client.getContractEvents({
    abi: zkLendAbi,
    address: contracts.zklend,
    eventName: "CommitmentAdded",
    fromBlock: 8291489n,
    toBlock: currentBlock,
  })
  return events.map((e) => e.args.commitment!)
}

export const useProvePosition = () => {
  return useMutation({
    mutationFn: async ({
      oldPosition,
      lendTokenIn,
      borrowTokenIn,
      lendTokenOut,
      borrowTokenOut,
      willLiqPrice,
    }: {
      oldPosition: Position
      lendTokenIn: bigint
      borrowTokenIn: bigint
      lendTokenOut: bigint
      borrowTokenOut: bigint
      willLiqPrice: bigint
    }) => {
      const leafs = await getLeafs()
      const tree = new MerkleTree(12, leafs, {
        hashFunction: (left, right) => toHex(poseidon2([left, right])),
        zeroElement:
          "0x2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c",
      })
      const { Noir, UltraHonkBackend, circuit } = await initProver()
      const noir = new Noir(circuit as any)
      const backend = new UltraHonkBackend(circuit.bytecode)
      const now = Math.floor(Date.now() / 1000)
      const new_nullifer = toHex(
        fromHex(generatePrivateKey(), "bigint") % MODULUS
      )
      const prev_note = {
        lend_amt: oldPosition.lendAmt,
        borrow_amt: oldPosition.borrowAmt,
        will_liq_price: oldPosition.willLiqPrice,
        timestamp: oldPosition.timestamp,
        nullifier: oldPosition.nullifier,
        nonce: oldPosition.nonce,
      }
      let prev_index = 0
      if (oldPosition.leafIndex === null) {
        tree.insert(hash_note(prev_note))
      } else {
        prev_index = oldPosition.leafIndex
      }
      const prev_hash_path = tree.path(prev_index).pathElements
      const root = tree.root

      console.log("Prev note", prev_note)

      const new_note = {
        lend_amt: toHex(
          updateAmount(
            fromHex(oldPosition.lendAmt, "bigint"),
            BigInt(oldPosition.timestamp),
            BigInt(now),
            LEND_INTEREST_RATE
          ) +
            lendTokenIn -
            lendTokenOut
        ),
        borrow_amt: toHex(
          updateAmount(
            fromHex(oldPosition.borrowAmt, "bigint"),
            BigInt(oldPosition.timestamp),
            BigInt(now),
            BORROW_INTEREST_RATE
          ) +
            borrowTokenIn -
            borrowTokenOut
        ),
        will_liq_price: toHex(willLiqPrice),
        timestamp: toHex(now),
        nullifier: new_nullifer,
        nonce: oldPosition.nonce,
      }
      console.log("New note", new_note)
      const new_note_hash = hash_note(new_note)
      console.log({
        new_note,
        new_note_hash,
        new_will_liq_price: new_note.will_liq_price,
        new_timestamp: new_note.timestamp,
        prev_note,
        prev_hash: hash_note(prev_note),
        prev_nullifier: oldPosition.nullifier,
        prev_index,
        prev_hash_path,
        root,
        liquidated_array: _.range(10).map((i) => ({
          liq_price: toHex(i + 1),
          timestamp: toHex(0n),
        })),
        lend_token_out: toHex(lendTokenOut),
        borrow_token_out: toHex(borrowTokenOut),
        lend_token_in: toHex(lendTokenIn),
        borrow_token_in: toHex(borrowTokenIn),
      })
      const { witness } = await noir.execute({
        new_note,
        new_note_hash,
        new_will_liq_price: new_note.will_liq_price,
        new_timestamp: new_note.timestamp,
        prev_note,
        prev_hash: hash_note(prev_note),
        prev_nullifier: oldPosition.nullifier,
        prev_index,
        prev_hash_path,
        root,
        liquidated_array: _.range(10).map((i) => ({
          liq_price: toHex(i + 1),
          timestamp: toHex(0n),
        })),
        lend_token_out: toHex(lendTokenOut),
        borrow_token_out: toHex(borrowTokenOut),
        lend_token_in: toHex(lendTokenIn),
        borrow_token_in: toHex(borrowTokenIn),
      })
      const proof = await backend.generateProof(witness)
      return {
        proof: proof.proof,
        new_note,
        new_note_hash,
        root,
        old_nullifier: oldPosition.nullifier,
        willLiqPrice,
      }
    },
  })
}
