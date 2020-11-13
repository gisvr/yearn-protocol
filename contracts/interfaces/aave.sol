pragma solidity ^0.5.0;


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
