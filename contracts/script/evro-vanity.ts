import assert from "assert";

import {
  type ByteArray,
  bytesToHex,
  concatBytes,
  getAddress,
  hexToBytes,
  keccak256,
  padBytes,
  stringToBytes,
} from "viem";

import EvroToken from "../out/EvroToken.sol/EvroToken.json";

const DEPLOYER = "0xbEC25C5590e89596BDE2DfCdc71579E66858772c";
const SALT_PREFIX = "beEVRO";
const CREATE2_DEPLOYER = "0x4e59b44847b379578588920cA78FbF26c0B4956C";
const CREATE2_PREFIX = concatBytes([hexToBytes("0xFF"), hexToBytes(CREATE2_DEPLOYER)]);

const computeCreate2Address = (salt: ByteArray, initCodeHash: ByteArray): ByteArray =>
  keccak256(concatBytes([CREATE2_PREFIX, salt, initCodeHash]), "bytes").slice(12);

const startsWith = <T extends string>(str: string, prefix: T): str is `${T}${string}` => str.startsWith(prefix);
assert(startsWith(EvroToken.bytecode.object, "0x"));

const evroInitCodeHash = keccak256(
  concatBytes([
    hexToBytes(EvroToken.bytecode.object),
    padBytes(hexToBytes(DEPLOYER)),
  ]),
  "bytes",
);

for (let i = 0;; ++i) {
  const saltStr = `${SALT_PREFIX}${i}`;
  const salt = keccak256(stringToBytes(saltStr), "bytes");
  const evroAddress = computeCreate2Address(salt, evroInitCodeHash);

  if (evroAddress[0] === 0xe0 /*&& evroAddress[18] === 0xe0*/) {
    console.log("Salt found:", saltStr);
    console.log("EVRO address:", getAddress(bytesToHex(evroAddress)));
    break;
  }
}
