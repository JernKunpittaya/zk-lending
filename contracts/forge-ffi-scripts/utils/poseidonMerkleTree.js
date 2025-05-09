const circomlibjs = require("circomlibjs");
const { MerkleTree } = require("fixed-merkle-tree");

const { leBufferToBigint, hexToBigint } = require("./bigint.js");

// Constants from MerkleTreeWithHistory.sol
const MERKLE_TREE_HEIGHT = 12;

// This matches the zeros function in MerkleTreeWithHistory.sol
const ZERO_VALUES = [
  "2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c",
  "13e37f2d6cb86c78ccc1788607c2b199788c6bb0a615a21f2e7a8e88384222f8",
  "217126fa352c326896e8c2803eec8fd63ad50cf65edfef27a41a9e32dc622765",
  "0e28a61a9b3e91007d5a9e3ada18e1b24d6d230c618388ee5df34cacd7397eee",
  "27953447a6979839536badc5425ed15fadb0e292e9bc36f92f0aa5cfa5013587",
  "194191edbfb91d10f6a7afd315f33095410c7801c47175c2df6dc2cce0e3affc",
  "1733dece17d71190516dbaf1927936fa643dc7079fc0cc731de9d6845a47741f",
  "267855a7dc75db39d81d17f95d0a7aa572bf5ae19f4db0e84221d2b2ef999219",
  "1184e11836b4c36ad8238a340ecc0985eeba665327e33e9b0e3641027c27620d",
  "0702ab83a135d7f55350ab1bfaa90babd8fc1d2b3e6a7215381a7b2213d6c5ce",
  "2eecc0de814cfd8c57ce882babb2e30d1da56621aef7a47f3291cffeaec26ad7",
  "280bc02145c155d5833585b6c7b08501055157dd30ce005319621dc462d33b47",
].map(hexToBigint);

// Creates a fixed height merkle-tree with Poseidon hash function (just like MerkleTreeWithHistory.sol)
async function poseidonMerkleTree(leaves = []) {
  // const pedersen = await circomlibjs.buildPedersenHash();
  const poseidon = await circomlibjs.buildPoseidon();

  const poseidonHash = (left, right) =>
    poseidon.F.toObject(poseidon([left, right]));

  return new MerkleTree(MERKLE_TREE_HEIGHT, leaves, {
    hashFunction: poseidonHash,
    zeroElement: ZERO_VALUES[0],
  });
}

module.exports = {
  poseidonMerkleTree,
};
