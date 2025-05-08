const { ethers } = require("ethers");
const { pedersenHash } = require("./utils/pedersen.js");
const { rbigint, bigintToHex, leBigintToBuffer } = require("./utils/bigint.js");

// Intended output: (bytes32 commitment, bytes32 nullifier, bytes32 secret)

////////////////////////////// MAIN ///////////////////////////////////////////

async function main() {
  const inputs = process.argv.slice(2, process.argv.length);

  // 1. Parse parameters
  const lend_amt = BigInt(inputs[0]);
  const borrow_amt = BigInt(inputs[1]);
  const will_liq_price = BigInt(inputs[2]);
  const timestamp = BigInt(inputs[3]);

  // 2. Generate random nullifier and secret
  const nullifier = rbigint(31);
  const secret = rbigint(31);

  // 3. Get commitment
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

  // 4. Return abi encoded nullifier, secret, commitment
  const res = ethers.AbiCoder.defaultAbiCoder().encode(
    ["bytes32", "bytes32", "bytes32"],
    [bigintToHex(commitment), bigintToHex(nullifier), bigintToHex(secret)]
  );

  return res;
}

main()
  .then((res) => {
    process.stdout.write(res);
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
