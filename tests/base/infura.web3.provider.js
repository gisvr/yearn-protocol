let network ="mainnet";// "ropsten"; //   rinkeby
let { projectId, privateKeys } = require("/Users/liyu/github/defi/secrets");

let host = `https://${network}.infura.io/v3/${projectId}`;


require("@openzeppelin/test-helpers/configure")({
    provider: host,
    singletons: {
        abstraction: "truffle"
    }
});
let Web3 = require("web3");

const {
    BN,           // Big Number support
    constants,
    expectEvent,  // Assertions for emitted events
    expectRevert // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

const { setupLoader } = require("@openzeppelin/contract-loader");
const loader = setupLoader({
    provider: host,
    defaultGas: 8e6,
    defaultGasPrice: 20e9,
    artifactsDir:"/Users/liyu/github/yearn-protocol/tests/abi"
}).truffle;


// const ERC20 = loader.fromArtifact("UniswapV1");
// https://etherscan.io/address/0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95#code
let UniswapFactoryV1 =require("/Users/liyu/github/yearn-protocol/tests/abi/UniswapFactoryV1")
// https://etherscan.io/address/0x2a1530C4C41db0B0b2bB646CB5Eb1A67b7158667
let UniswapExchangeV1 =require("/Users/liyu/github/yearn-protocol/tests/abi/UniswapExchangeV1")

// https://etherscan.io/address/0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95#code
let UniswapFactoryV2 =require("/Users/liyu/github/yearn-protocol/tests/abi/UniswapFactoryV1")
// https://etherscan.io/address/0x2a1530C4C41db0B0b2bB646CB5Eb1A67b7158667
let UniswapExchangeV2 =require("/Users/liyu/github/yearn-protocol/tests/abi/UniswapExchangeV1")


const web3 = new Web3(host);
module.exports = {
    async getArttifact() {
        const UniswapFactory = loader.fromABI(UniswapFactoryV1.abi, UniswapFactoryV1.bytecode,UniswapFactoryV1.networks["1"].address)
        const UniswapExchange = loader.fromABI(UniswapExchangeV1.abi)
        return {
            BN,
            web3,
            constants,
            accounts,
            UniswapFactory,
            UniswapExchange
        };
    },
    async getArttifactV2() {
        const UniswapFactory = loader.fromABI(UniswapFactoryV2.abi, UniswapFactoryV2.bytecode,UniswapFactoryV2.networks["1"].address)
        const UniswapExchange = loader.fromABI(UniswapExchangeV2.abi)
        return {
            BN,
            web3,
            constants,
            accounts,
            UniswapFactory,
            UniswapExchange
        };
    }
};
