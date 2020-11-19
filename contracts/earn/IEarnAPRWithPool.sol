/**
 *Submitted for verification at Etherscan.io on 2020-02-06
 https://etherscan.io/address/0xdD6d648C991f7d47454354f4Ef326b04025a48A8#code
 获取 不同资金池的年化利率
*/
pragma solidity ^0.5.16;


import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "../interfaces/erc20.sol";
import "../interfaces/uniswap.sol";
import "../interfaces/APRWithPoolOracle.sol";

contract IEarnAPRWithPool is Ownable {
    using SafeMath for uint;
    using Address for address;

    mapping(address => uint256) public pools; //池
    mapping(address => address) public compound;
    mapping(address => address) public fulcrum; // bzx
    mapping(address => address) public aave;
    mapping(address => address) public aaveUni;
    mapping(address => uint256) public dydx;
    mapping(address => address) public yTokens;

    address public UNI;
    //    address public UNIROI;
    address public UNIAPR;
    address public APR;

    constructor() public {
        UNI = address(0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95);
        //https://uniswap.org/docs/v1/frontend-integration/connect-to-uniswap
        // UNIROI = address(0xD04cA0Ae1cd8085438FDd8c22A76246F315c2687); // Uniswap的投资回报率
        UNIAPR = address(0x4c70D89A4681b2151F56Dc2c3FD751aBb9CE3D95);
        //对 Uniswap的ROI进行换算APR

        APR = address(0xeC3aDd301dcAC0e9B0B880FCf6F92BDfdc002BBc);
        // APR的 Oracle

        //(token, created)
        addPool(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643, 9000629);
        // cDAI CErc20Delegator
        addPool(0xF5DCe57282A584D2746FaF1593d3121Fcac444dC, 7723867);
        // cDAI CErc20
        addPool(0x6B175474E89094C44Da98b954EedeAC495271d0F, 8939330);
        // Dai Stablecoin
        addPool(0x0000000000085d4780B73119b644AE5ecd22b376, 7794100);
        // TUSD OwnedUpgradeabilityProxy uniswap crated block number

        addPool(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 6783192);
        // USDC FiatTokenProxy
        addPool(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51, 8623684);
        // sUSD
        addPool(0x0D8775F648430679A709E98d2b0Cb6250d2887EF, 6660894);
        // BAT
        addPool(0x514910771AF9Ca656af840dff83E8264EcF986CA, 6627987);
        // LINK
        addPool(0xdd974D5C2e2928deA5F71b9825b8b646686BD200, 6627984);
        // KNC KyberNetworkCrystal
        addPool(0x1985365e9f78359a9B6AD760e32412f4a445E862, 6627994);
        // REP Reputation https://www.augur.net/
        addPool(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2, 6627956);
        // Mu Maker DSToken
        addPool(0xE41d2489571d322189246DaFA5ebDe1F4699F498, 6627972);
        // ZRX  0x Protocol Token
        addPool(0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F, 8314762);
        // SNX Synthetix Network Token ProxyERC20
        addPool(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 7004537);
        // WBTC

        // (token,cToken)
        addCToken(0x6B175474E89094C44Da98b954EedeAC495271d0F, 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
        // cDAI
        addCToken(0x0D8775F648430679A709E98d2b0Cb6250d2887EF, 0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E);
        // cBAT
        addCToken(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
        // cETH
        addCToken(0x1985365e9f78359a9B6AD760e32412f4a445E862, 0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1);
        // cREP
        addCToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0x39AA39c021dfbaE8faC545936693aC917d5E7563);
        // cUSDC
        addCToken(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 0xC11b1268C1A384e55C48c2391d8d480264A3A7F4);
        // cWBTC

        // (atoken,aToken)
        addAToken(0x6B175474E89094C44Da98b954EedeAC495271d0F, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        // aDAI
        addAToken(0x0000000000085d4780B73119b644AE5ecd22b376, 0x0000000000085d4780B73119b644AE5ecd22b376);
        // aTUSD
        addAToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        // aUSDC
        addAToken(0xdAC17F958D2ee523a2206206994597C13D831ec7, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        // aUSDT
        addAToken(0x80fB784B7eD66730e8b1DBd9820aFD29931aab03, 0x80fB784B7eD66730e8b1DBd9820aFD29931aab03);
        // aLEND
        addAToken(0x0D8775F648430679A709E98d2b0Cb6250d2887EF, 0x0D8775F648430679A709E98d2b0Cb6250d2887EF);
        // aBAT
        addAToken(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        // aETH
        addAToken(0x514910771AF9Ca656af840dff83E8264EcF986CA, 0x514910771AF9Ca656af840dff83E8264EcF986CA);
        // aLINK
        addAToken(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        // aWBTC

        //(atoken,aToken) Uni
        addAUniToken(0x6B175474E89094C44Da98b954EedeAC495271d0F, 0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d);
        // aDAI
        addAUniToken(0x0000000000085d4780B73119b644AE5ecd22b376, 0x4DA9b813057D04BAef4e5800E36083717b4a0341);
        // aTUSD
        addAUniToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0x9bA00D6856a4eDF4665BcA2C2309936572473B7E);
        // aUSDC
        addAUniToken(0xdAC17F958D2ee523a2206206994597C13D831ec7, 0x71fc860F7D3A592A4a98740e39dB31d25db65ae8);
        // aUSDT


        // (token,iToken) bzx.network
        addIToken(0xE41d2489571d322189246DaFA5ebDe1F4699F498, 0xA7Eb2bc82df18013ecC2A6C533fc29446442EDEe);
        // iZRX
        addIToken(0x1985365e9f78359a9B6AD760e32412f4a445E862, 0xBd56E9477Fc6997609Cf45F84795eFbDAC642Ff1);
        // iREP
        addIToken(0xdd974D5C2e2928deA5F71b9825b8b646686BD200, 0x1cC9567EA2eB740824a45F8026cCF8e46973234D);
        // iKNC
        addIToken(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 0xBA9262578EFef8b3aFf7F60Cd629d6CC8859C8b5);
        // iWBTC
        addIToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0xF013406A0B1d544238083DF0B93ad0d2cBE0f65f);
        // iUSDC
        addIToken(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 0x77f973FCaF871459aa58cd81881Ce453759281bC);
        // iETH
        addIToken(0x6B175474E89094C44Da98b954EedeAC495271d0F, 0x493C57C4763932315A328269E1ADaD09653B9081);
        // iDAI
        addIToken(0x514910771AF9Ca656af840dff83E8264EcF986CA, 0x1D496da96caf6b518b133736beca85D5C4F9cBc5);
        // iLINK
        addIToken(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51, 0x49f4592E641820e928F9919Ef4aBd92a719B4b49);
        // iSUSD

        //(token,index) //dydx
        addDToken(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 0);
        // dETH
        addDToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 2);
        // dUSDC
        addDToken(0x6B175474E89094C44Da98b954EedeAC495271d0F, 3);
        // dDAI

        //(token,yTokens) yearn.finance
        addYToken(0x6B175474E89094C44Da98b954EedeAC495271d0F, 0x9D25057e62939D3408406975aD75Ffe834DA4cDd);
        // yDAI
        addYToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0xa2609B2b43AC0F5EbE27deB944d2a399C201E3dA);
        // yUSDC
        addYToken(0xdAC17F958D2ee523a2206206994597C13D831ec7, 0xa1787206d5b1bE0f432C4c4f96Dc4D1257A1Dd14);
        // yUSDT
        addYToken(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51, 0x36324b8168f960A12a8fD01406C9C78143d41380);
        // ySUSD
        addYToken(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 0x04EF8121aD039ff41d10029c91EA1694432514e9);
        // yWBTC

    }

    // Wrapper for legacy v1 token support
    function recommend(address _token) public view returns (
        string memory choice,
        uint256 capr,
        uint256 iapr,
        uint256 aapr,
        uint256 dapr
    ) {
        (, capr, , iapr, , aapr, , dapr, ,) = getAPROptionsInc(_token);
        return (choice, capr, iapr, aapr, dapr);
    }

    function getAPROptionsInc(address _token) public view returns (
        uint256 _uniswap,
        uint256 _compound,
        uint256 _unicompound,
        uint256 _fulcrum,
        uint256 _unifulcrum,
        uint256 _aave,
        uint256 _uniaave,
        uint256 _dydx,
        uint256 _ddex,
        uint256 _lendf
    ) {
        address yToken = yTokens[_token];
        uint256 _supply = 0;
        if (yToken != address(0)) {
            _supply = IYToken(yToken).calcPoolValueInToken();
        }
        return getAPROptionsAdjusted(_token, _supply);
    }

    function getAPROptions(address _token) public view returns (
        uint256 _uniswap,
        uint256 _compound,
        uint256 _unicompound,
        uint256 _fulcrum,
        uint256 _unifulcrum,
        uint256 _aave,
        uint256 _uniaave,
        uint256 _dydx,
        uint256 _ddex,
        uint256 _lendf
    ) {
        return getAPROptionsAdjusted(_token, 0);
    }

    function getAPROptionsAdjusted(address _token, uint256 _supply) public view returns (
        uint256 _uniswap,
        uint256 _compound,
        uint256 _unicompound,
        uint256 _fulcrum,
        uint256 _unifulcrum,
        uint256 _aave,
        uint256 _uniaave,
        uint256 _dydx,
        uint256 _ddex,
        uint256 _lendf
    ) {
        //查询 支持的资产 在uniswap 上创建的时间
        uint256 created = pools[_token];

        if (created > 0) {
            _uniswap = IUniswapAPR(UNIAPR).calcUniswapAPR(_token, created);
        }
        address addr = compound[_token];
        if (addr != address(0)) {
            _compound = APRWithPoolOracle(APR).getCompoundAPR(addr);
            created = pools[addr];
            if (created > 0) {
                _unicompound = IUniswapAPR(UNIAPR).calcUniswapAPR(addr, created);
            }
        }
        addr = fulcrum[_token];
        if (addr != address(0)) {
            _fulcrum = APRWithPoolOracle(APR).getFulcrumAPRAdjusted(addr, _supply);
            created = pools[addr];
            if (created > 0) {
                _unifulcrum = IUniswapAPR(UNIAPR).calcUniswapAPR(addr, created);
            }
        }
        addr = aave[_token];
        if (addr != address(0)) {
            _aave = APRWithPoolOracle(APR).getAaveAPRAdjusted(addr, _supply);
            addr = aaveUni[_token];
            created = pools[addr];
            if (created > 0) {
                _uniaave = IUniswapAPR(UNIAPR).calcUniswapAPR(addr, created);
            }
        }

        _dydx = dydx[_token];
        if (_dydx > 0 || _token == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            _dydx = APRWithPoolOracle(APR).getDyDxAPRAdjusted(_dydx, _supply);
        }

        _ddex = APRWithPoolOracle(APR).getDDEXAPRAdjusted(_token, _supply);
        _lendf = APRWithPoolOracle(APR).getLENDFAPRAdjusted(_token, _supply);

        return (
        _uniswap,
        _compound,
        _unicompound,
        _fulcrum,
        _unifulcrum,
        _aave,
        _uniaave,
        _dydx,
        _ddex,
        _lendf
        );
    }

    function viewPool(address _token) public view returns (
        address token,
        address unipool,
        uint256 created,
        string memory name,
        string memory symbol
    ) {
        token = _token;
        unipool = IUniswapFactory(UNI).getExchange(_token);
        created = pools[_token];
        name = IERC20(_token).name();
        symbol = IERC20(_token).symbol();
        return (token, unipool, created, name, symbol);
    }

    function addPool(
        address token,
        uint256 created
    ) public onlyOwner {
        pools[token] = created;
    }

    function addCToken(
        address token,
        address cToken
    ) public onlyOwner {
        compound[token] = cToken;
    }

    function addIToken(
        address token,
        address iToken
    ) public onlyOwner {
        fulcrum[token] = iToken;
    }

    function addAToken(
        address token,
        address aToken
    ) public onlyOwner {
        aave[token] = aToken;
    }

    function addAUniToken(
        address token,
        address aToken
    ) public onlyOwner {
        aaveUni[token] = aToken;
    }

    function addYToken(
        address token,
        address yToken
    ) public onlyOwner {
        yTokens[token] = yToken;
    }

    function addDToken(
        address token,
        uint256 dToken
    ) public onlyOwner {
        dydx[token] = dToken;
    }

    //    function set_new_UNIROI(address _new_UNIROI) public onlyOwner {
    //        UNIROI = _new_UNIROI;
    //    }

    function set_new_UNI(address _new_UNI) public onlyOwner {
        UNI = _new_UNI;
    }

    function set_new_UNIAPR(address _new_UNIAPR) public onlyOwner {
        UNIAPR = _new_UNIAPR;
    }

    function set_new_APR(address _new_APR) public onlyOwner {
        APR = _new_APR;
    }

    // incase of half-way error
    function inCaseTokenGetsStuck(IERC20 _TokenAddress) onlyOwner public {
        uint qty = _TokenAddress.balanceOf(address(this));
        _TokenAddress.transfer(msg.sender, qty);
    }
    // incase of half-way error
    function inCaseETHGetsStuck() onlyOwner public {
        (bool result,) = msg.sender.call.value(address(this).balance)("");
        require(result, "transfer of ETH failed");
    }
}
