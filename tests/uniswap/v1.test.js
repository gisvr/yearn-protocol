const provider = require("../base/infura.web3.provider");

describe("uniswap v1 ropsten", async () => {
    let owner, sender;
    let daiAddr = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

    before(async function() {
        const { UniswapFactory, UniswapExchange, accounts, web3, BN, constants } = await provider.getArttifact();
        [owner, sender] = accounts;
        this.web3 = web3;
        this.BN = BN;
        console.log("owner", owner);
        console.log("sender", sender);
        this.factory = UniswapFactory;
        this.exchange = UniswapExchange;

    });
    it("calcUniswapROI ", async function() {
        // let exchange = await this.factory.getExchange(daiAddr).call()
        let exchangeAddr = await this.factory.getExchange(daiAddr);
        this.exchange = await this.exchange.at(exchangeAddr);
        let totalShares = await this.exchange.totalSupply();
        let name = await this.exchange.name();
        let symbol = await this.exchange.symbol();
        console.log("name",this.web3.utils.hexToAscii(name),"symbol",this.web3.utils.hexToAscii(symbol))
        console.log(totalShares.toString());

        let ethBalance = await this.web3.eth.getBalance(this.exchange.address) //balance();
        console.log(ethBalance.toString());

        let ret =new this.BN(ethBalance).mul(new this.BN("1000")).div(totalShares);

        console.log(ret.toString())
    });

});


