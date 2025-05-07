const circomlibjs = require("circomlibjs");

const { leBufferToBigint } = require("./bigint.js");

// Computes the Pedersen hash of the given data, returning the result as a BigInt.
const pedersenHash = async (data) => {
  const pedersen = await circomlibjs.buildPedersenHash();

  const pedersenOutput = pedersen.hash(data);

  const babyJubOutput = leBufferToBigint(
    pedersen.babyJub.F.fromMontgomery(
      pedersen.babyJub.unpackPoint(pedersenOutput)[0]
    )
  );
  return babyJubOutput;
};

module.exports = {
  pedersenHash,
};
