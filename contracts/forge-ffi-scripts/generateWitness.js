const path = require("path");
const snarkjs = require("snarkjs");
const { ethers } = require("ethers");

const {
  hexToBigint,
  bigintToHex,
  leBigintToBuffer,
} = require("./utils/bigint.js");

const { pedersenHash } = require("./utils/pedersen.js");
const { poseidonMerkleTree } = require("./utils/poseidonMerkleTree.js");

// Intended output: (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, bytes32 root, bytes32 nullifierHash)

////////////////////////////// MAIN ///////////////////////////////////////////

async function main() {
  const inputs = process.argv.slice(2, process.argv.length);

  // 1. Get parameters & nullifier and secret
  const lend_amt = BigInt(inputs[0]);
  const borrow_amt = BigInt(inputs[1]);
  const will_liq_price = BigInt(inputs[2]);
  const timestamp = BigInt(inputs[3]);
  const nullifier = hexToBigint(inputs[4]);
  const secret = hexToBigint(inputs[5]);

  // 2. Get nullifier hash
  const nullifierHash = await pedersenHash(leBigintToBuffer(nullifier, 31));

  // 3. Create merkle tree, insert leaves and get merkle proof for commitment
  const leaves = inputs.slice(6, inputs.length).map((l) => hexToBigint(l));

  const tree = await poseidonMerkleTree(leaves);

  const commitment = await pedersenHash(
    Buffer.concat([
      leBigintToBuffer(lend_amt, 31),
      leBigintToBuffer(borrow_amt, 31),
      leBigintToBuffer(will_liq_price, 31),
      leBigintToBuffer(timestamp, 31),
      leBigintToBuffer(nullifier, 31),
      leBigintToBuffer(secret, 31),
    ])
  );

  const merkleProof = tree.proof(commitment);

  // 4. Format witness input to exactly match circuit expectations
  // const input = {
  //   // Public inputs
  //   root: merkleProof.pathRoot,
  //   nullifierHash: nullifierHash,
  //   recipient: hexToBigint(inputs[2]),
  //   relayer: hexToBigint(inputs[3]),
  //   fee: BigInt(inputs[4]),
  //   refund: BigInt(inputs[5]),

  //   // Private inputs
  //   nullifier: nullifier,
  //   secret: secret,
  //   pathElements: merkleProof.pathElements.map((x) => x.toString()),
  //   pathIndices: merkleProof.pathIndices,
  // };

  // 5. Create groth16 proof for witness
  // const { proof } = await snarkjs.groth16.fullProve(
  //   input,
  //   path.join(__dirname, "../circuit_artifacts/withdraw_js/withdraw.wasm"),
  //   path.join(__dirname, "../circuit_artifacts/withdraw_final.zkey")
  // );

  // const pA = proof.pi_a.slice(0, 2);
  // const pB = proof.pi_b.slice(0, 2);
  // const pC = proof.pi_c.slice(0, 2);

  // 6. Return abi encoded witness
  const witness = ethers.AbiCoder.defaultAbiCoder().encode(
    ["uint256", "bytes32", "bytes32"],
    [0, bigintToHex(merkleProof.pathRoot), bigintToHex(nullifierHash)]
  );

  return witness;
}

main()
  .then((wtns) => {
    process.stdout.write(wtns);
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
