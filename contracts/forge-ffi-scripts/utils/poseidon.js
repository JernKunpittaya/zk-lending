const circomlibjs = require("circomlibjs");

const { leBufferToBigint } = require("./bigint.js");

// Computes the Poseidon hash of the given data, returning the result as a BigInt.
const poseidonHash = async (data) => {
  const poseidon = await circomlibjs.buildPoseidon();

  const poseidonOutput = poseidon.F.toObject(poseidon(data));

  return poseidonOutput;
};

module.exports = {
  poseidonHash,
};
