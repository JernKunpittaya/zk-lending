const circomlibjs = require("circomlibjs");

const nInputs = 2;

process.stdout.write(circomlibjs.poseidonContract.createCode(nInputs));
