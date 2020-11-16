pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

contract Structs {
    struct Asset {
        address lendingPool;
        address priceOralce;
        address interestModel;
    }
}

contract IDDEX is Structs {

    function getInterestRates(address token, uint256 extraBorrowAmount)
    external
    view
    returns (uint256 borrowInterestRate, uint256 supplyInterestRate);

    function getIndex(address token)
    external
    view
    returns (uint256 supplyIndex, uint256 borrowIndex);

    function getTotalSupply(address asset)
    external
    view
    returns (uint256 amount);

    function getTotalBorrow(address asset)
    external
    view
    returns (uint256 amount);

    function getAsset(address token)
    external
    view returns (Asset memory asset);
}

interface IDDEXModel {
    function polynomialInterestModel(uint256 borrowRatio) external view returns (uint256);
}
