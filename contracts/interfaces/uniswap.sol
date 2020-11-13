pragma solidity ^0.5.0;

interface IUniswapROI {
    function calcUniswapROI(address token) external view returns (uint256, uint256);
}


interface IUniswapAPR {
    function getBlocksPerYear() external view returns (uint256);
    function calcUniswapAPRFromROI(uint256 roi, uint256 createdAt) external view returns (uint256);
    function calcUniswapAPR(address token, uint256 createdAt) external view returns (uint256);
}

interface IUniswapFactory {
    function getExchange(address token) external view returns (address exchange);
}
