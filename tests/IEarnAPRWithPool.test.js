const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
const {
    BN,          // Big Number support
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

const { expect } = require("chai");

const yUSDT = contract.fromArtifact("yUSDT"); // Loads a compiled contract

describe("yUSDT", function() {
    const [alice, bob, carol] = accounts;
    beforeEach(async () => {
        this.value = new BN(6);
        this.yUSDT = await yUSDT.new();
    });

    it("should have correct name and symbol and decimal", async () => {
        expect(await this.yUSDT.name()).to.equal("iearn USDT");
        expect(await this.yUSDT.symbol()).to.equal("yUSDT");
        expect(await this.yUSDT.decimals()).to.be.bignumber.equal(this.value);
    });


});


