pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

interface DyDx {
    struct val {
        uint256 value;
    }

    struct set {
        uint128 borrow;
        uint128 supply;
    }

    function getEarningsRate() external view returns (val memory);

    function getMarketInterestRate(uint256 marketId) external view returns (val memory);

    function getMarketTotalPar(uint256 marketId) external view returns (set memory);
}
