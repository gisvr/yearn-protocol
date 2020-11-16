pragma solidity ^0.5.16;


interface ILendingPoolAddressesProvider {
    function getLendingPool() external view returns (address);
}

interface Aave {
    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external;
}

interface LendingPoolAddressesProvider {
    function getLendingPool() external view returns (address);

    function getLendingPoolCore() external view returns (address);

}


interface AToken {
    function redeem(uint256 amount) external;
}

///------------oracle------------

interface LendingPoolCore {
    function getReserveCurrentLiquidityRate(address _reserve)
    external
    view
    returns (
        uint256 liquidityRate
    );

    function getReserveInterestRateStrategyAddress(address _reserve) external view returns (address);

    function getReserveTotalBorrows(address _reserve) external view returns (uint256);

    function getReserveTotalBorrowsStable(address _reserve) external view returns (uint256);

    function getReserveTotalBorrowsVariable(address _reserve) external view returns (uint256);

    function getReserveCurrentAverageStableBorrowRate(address _reserve)
    external
    view
    returns (uint256);

    function getReserveAvailableLiquidity(address _reserve) external view returns (uint256);
}

interface IReserveInterestRateStrategy {

    function getBaseVariableBorrowRate() external view returns (uint256);

    function calculateInterestRates(
        address _reserve,
        uint256 _utilizationRate,
        uint256 _totalBorrowsStable,
        uint256 _totalBorrowsVariable,
        uint256 _averageStableBorrowRate)
    external
    view
    returns (uint256 liquidityRate, uint256 stableBorrowRate, uint256 variableBorrowRate);
}

interface InterestRateModel {
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint);
}
