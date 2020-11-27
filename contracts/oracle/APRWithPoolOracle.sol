/**
 *Submitted for verification at Etherscan.io on 2020-02-06
 https://etherscan.io/address/0xeC3aDd301dcAC0e9B0B880FCf6F92BDfdc002BBc#code
*/

pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "../interfaces/erc20.sol";
import "../interfaces/compound.sol";
import "../interfaces/fulcrum.sol";
import "../interfaces/aave.sol";
import "../interfaces/dydx.sol";
import "../interfaces/iddex.sol";
import "../interfaces/iLendF.sol";

library Decimal {
    using SafeMath for uint256;

    uint256 constant BASE = 10 ** 18;

    function one()
    internal
    pure
    returns (uint256)
    {
        return BASE;
    }

    function onePlus(
        uint256 d
    )
    internal
    pure
    returns (uint256)
    {
        return d.add(BASE);
    }

    function mulFloor(
        uint256 target,
        uint256 d
    )
    internal
    pure
    returns (uint256)
    {
        return target.mul(d) / BASE;
    }

    //https://github.com/ripio/ramp-contracts/blob/master/contracts/utils/Math.sol
    function divCeil(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
        require(_b != 0, "div by zero");
        c = _a / _b;
        if (_a % _b != 0) {
            c = c + 1;
        }
        return c;
    }

    function mulCeil(
        uint256 target,
        uint256 d
    )
    internal
    pure
    returns (uint256)
    {
        // return target.mul(d).divCeil(BASE);
        return divCeil(target.mul(d), BASE);
    }

    function divFloor(
        uint256 target,
        uint256 d
    )
    internal
    pure
    returns (uint256)
    {
        return target.mul(BASE).div(d);
    }

    //    function divCeil(
    //        uint256 target,
    //        uint256 d
    //    )
    //    internal
    //    pure
    //    returns (uint256)
    //    {
    //        // return target.mul(BASE).divCeil(d);
    //        return divCeil(target.mul(BASE), d);
    //
    //    }
}


contract APRWithPoolOracle is Ownable, Structs {
    using SafeMath for uint256;
    using Address for address;

    uint256 DECIMAL = 10 ** 18;

    address public DYDX;
    address public AAVE;
    address public DDEX;
    address public LENDF;

    uint256 public liquidationRatio;
    uint256 public dydxModifier;
    uint256 public blocksPerYear = 2102400; // 1年的秒数/ 15秒出块 = 31536000/15


    constructor() public {
        DYDX = address(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e);
        AAVE = address(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);
        DDEX = address(0x241e82C79452F51fbfc89Fac6d912e021dB1a3B7);
        LENDF = address(0x0eEe3E3828A45f7601D5F54bF49bB01d1A9dF5ea);
        liquidationRatio = 50000000000000000;
        //5e16
        dydxModifier = 20;
    }

    function set_new_AAVE(address _new_AAVE) public onlyOwner {
        AAVE = _new_AAVE;
    }

    function set_new_DDEX(address _new_DDEX) public onlyOwner {
        DDEX = _new_DDEX;
    }

    function set_new_DYDX(address _new_DYDX) public onlyOwner {
        DYDX = _new_DYDX;
    }

    function set_new_LENDF(address _new_LENDF) public onlyOwner {
        LENDF = _new_LENDF;
    }

    function set_new_Ratio(uint256 _new_Ratio) public onlyOwner {
        liquidationRatio = _new_Ratio;
    }

    function set_new_Modifier(uint256 _new_Modifier) public onlyOwner {
        dydxModifier = _new_Modifier;
    }

    /*
        get APR
    */

    function getLENDFAPR(address token) public view returns (uint256) {
        (,,,,uint256 supplyRateMantissa,,,,) = ILendF(LENDF).markets(token);
        return supplyRateMantissa.mul(2102400);
    }

    function getLENDFAPRAdjusted(address token, uint256 supply) public view returns (uint256) {
        if (token == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            return 0;
        }
        uint256 totalCash = IERC20(token).balanceOf(LENDF).add(supply);
        (,, address interestRateModel,,,, uint256 totalBorrows,,) = ILendF(LENDF).markets(token);
        if (interestRateModel == address(0)) {
            return 0;
        }
        (, uint256 supplyRateMantissa) = ILendFModel(interestRateModel).getSupplyRate(token, totalCash, totalBorrows);
        return supplyRateMantissa.mul(2102400);
    }

    function getDDEXAPR(address token) public view returns (uint256) {
        if (token == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            token = address(0x000000000000000000000000000000000000000E);
        }
        (uint256 supplyIndex,) = IDDEX(DDEX).getIndex(token);
        if (supplyIndex == 0) {
            return 0;
        }
        (,uint256 supplyRate) = IDDEX(DDEX).getInterestRates(token, 0);
        return supplyRate;
    }

    function getDDEXAPRAdjusted(address token, uint256 _supply) public view returns (uint256) {
        if (token == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            token = address(0x000000000000000000000000000000000000000E);
        }
        (uint256 supplyIndex,) = IDDEX(DDEX).getIndex(token);
        if (supplyIndex == 0) {
            return 0;
        }
        uint256 supply = IDDEX(DDEX).getTotalSupply(token).add(_supply);
        uint256 borrow = IDDEX(DDEX).getTotalBorrow(token);
        uint256 borrowRatio = borrow.mul(Decimal.one()).div(supply);
        address interestRateModel = IDDEX(DDEX).getAsset(token).interestModel;
        uint256 borrowRate = IDDEXModel(interestRateModel).polynomialInterestModel(borrowRatio);
        uint256 borrowInterest = Decimal.mulCeil(borrow, borrowRate);
        uint256 supplyInterest = Decimal.mulFloor(borrowInterest, Decimal.one().sub(liquidationRatio));
        return Decimal.divFloor(supplyInterest, supply);
    }

    function getCompoundAPR(address token) public view returns (uint256) {
        // * @notice返回此cToken的当前每块供应利率
        //* @返回每块的供应利率，按1e18缩放
        return Compound(token).supplyRatePerBlock().mul(2102400);
    }

    // 调整收益率 - 可操作的量
    function getCompoundAPRAdjusted(address token, uint256 _supply) public view returns (uint256) {
        Compound c = Compound(token);
        // * @notice返回此cToken的当前每块供应利率
        //* @返回每块的供应利率，按1e18缩放
        address model = Compound(token).interestRateModel();
        if (model == address(0)) {
            return c.supplyRatePerBlock().mul(2102400);
        }
        InterestRateModel i = InterestRateModel(model);
        //* @notice将此cToken的现金余额计入标的资产
        //* @返还本合同所拥有的标的资产数量
        uint256 cashPrior = c.getCash().add(_supply);

        //    * @notice计算每段现时的供应利率

        //    * @param现金市场拥有的现金总额
        //    * @param借款市场上未偿还的借款总额
        //    * @param储备金市场拥有的储备金总额
        //    * @param储备因数是市场现有的储备因数

        //    * @返回每个区块的供货率(以百分比表示，按1e18缩放)
        return i.getSupplyRate(cashPrior, c.totalBorrows(), c.totalReserves().add(_supply), c.reserveFactorMantissa()).mul(2102400);
    }

    function getFulcrumAPR(address token) public view returns (uint256) {
        return Fulcrum(token).supplyInterestRate().div(100);
    }

    function getFulcrumAPRAdjusted(address token, uint256 _supply) public view returns (uint256) {
        return Fulcrum(token).nextSupplyInterestRate(_supply).div(100);
    }

    function getDyDxAPR(uint256 marketId) public view returns (uint256) {
        uint256 rate = DyDx(DYDX).getMarketInterestRate(marketId).value;
        uint256 aprBorrow = rate * 31622400;
        uint256 borrow = DyDx(DYDX).getMarketTotalPar(marketId).borrow;
        uint256 supply = DyDx(DYDX).getMarketTotalPar(marketId).supply;
        uint256 usage = (borrow * DECIMAL) / supply;
        uint256 apr = (((aprBorrow * usage) / DECIMAL) * DyDx(DYDX).getEarningsRate().value) / DECIMAL;
        return apr;
    }

    function getDyDxAPRAdjusted(uint256 marketId, uint256 _supply) public view returns (uint256) {
        uint256 rate = DyDx(DYDX).getMarketInterestRate(marketId).value;
        // Arbitrary value to offset calculations
        _supply = _supply.mul(dydxModifier);
        uint256 aprBorrow = rate * 31622400;
        uint256 borrow = DyDx(DYDX).getMarketTotalPar(marketId).borrow;
        uint256 supply = DyDx(DYDX).getMarketTotalPar(marketId).supply;
        supply = supply.add(_supply);
        uint256 usage = (borrow * DECIMAL) / supply;
        uint256 apr = (((aprBorrow * usage) / DECIMAL) * DyDx(DYDX).getEarningsRate().value) / DECIMAL;
        return apr;
    }

    function getAaveCore() public view returns (address) {
        return address(LendingPoolAddressesProvider(AAVE).getLendingPoolCore());
    }

    function getAaveAPR(address token) public view returns (uint256) {
        LendingPoolCore core = LendingPoolCore(LendingPoolAddressesProvider(AAVE).getLendingPoolCore());
        // 资产当前的流动性比率， 统一单位 到 e18 aave的单位是e27
        return core.getReserveCurrentLiquidityRate(token).div(1e9);
    }

    function getAaveAPRAdjusted(address token, uint256 _supply) public view returns (uint256) {
        LendingPoolCore core = LendingPoolCore(LendingPoolAddressesProvider(AAVE).getLendingPoolCore());
        //获得资产的利率策略
        IReserveInterestRateStrategy apr = IReserveInterestRateStrategy(core.getReserveInterestRateStrategyAddress(token));
        //计算利率
        (uint256 newLiquidityRate,,) = apr.calculateInterestRates(
            token,
            core.getReserveAvailableLiquidity(token).add(_supply), // 可用的流动性
            core.getReserveTotalBorrowsStable(token), // 总共的固定利率借出
            core.getReserveTotalBorrowsVariable(token), // 总计浮动利率借出
            core.getReserveCurrentAverageStableBorrowRate(token) // 当前平均固定借出利率
        );
        return newLiquidityRate.div(1e9);
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
