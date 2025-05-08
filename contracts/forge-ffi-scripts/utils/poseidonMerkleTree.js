const circomlibjs = require("circomlibjs");
const { MerkleTree } = require("fixed-merkle-tree");

const { leBufferToBigint, hexToBigint } = require("./bigint.js");

// Constants from MerkleTreeWithHistory.sol
const MERKLE_TREE_HEIGHT = 20;

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
  "045132221d1fa0a7f4aed8acd2cbec1e2189b7732ccb2ec272b9c60f0d5afc5b",
  "27f427ccbf58a44b1270abbe4eda6ba53bd6ac4d88cf1e00a13c4371ce71d366",
  "1617eaae5064f26e8f8a6493ae92bfded7fde71b65df1ca6d5dcec0df70b2cef",
  "20c6b400d0ea1b15435703c31c31ee63ad7ba5c8da66cec2796feacea575abca",
  "09589ddb438723f53a8e57bdada7c5f8ed67e8fece3889a73618732965645eec",
  "0064b6a738a5ff537db7b220f3394f0ecbd35bfd355c5425dc1166bf3236079b",
  "095de56281b1d5055e897c3574ff790d5ee81dbc5df784ad2d67795e557c9e9f",
  "11cf2e2887aa21963a6ec14289183efe4d4c60f14ecd3d6fe0beebdf855a9b63",
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
