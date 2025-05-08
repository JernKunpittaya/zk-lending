const { buildPoseidon } = require("circomlibjs");
const {
  bigintToHex,
  hexToBigint,
} = require("./forge-ffi-scripts/utils/bigint");
(async () => {
  const poseidon = await buildPoseidon();
  let empty_node_leaf_hex =
    "0x2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c";
  let empty_node_bigint = hexToBigint(empty_node_leaf_hex);
  console.log("layer 0: ", empty_node_leaf_hex);
  for (let i = 0; i < 31; i++) {
    let hash = poseidon([empty_node_bigint, empty_node_bigint]);
    empty_node_bigint = poseidon.F.toObject(hash);
    console.log("layer ", i + 1, ": ", bigintToHex(empty_node_bigint));
  }
})();
