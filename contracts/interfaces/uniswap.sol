pragma solidity ^0.5.16;

//interface IUniswapROI {
//    function calcUniswapROI(address token) external view returns (uint256, uint256);
//}

interface IUniswapROI {

    // UniswapROI
    function getCDAIUniROI() external view returns (uint256, uint256);

    function getCBATUniROI() external view returns (uint256, uint256);

    function getCETHUniROI() external view returns (uint256, uint256);

    function getCREPUniROI() external view returns (uint256, uint256);

    function getCSAIUniROI() external view returns (uint256, uint256);

    function getCUSDCUniROI() external view returns (uint256, uint256);

    function getCWBTCUniROI() external view returns (uint256, uint256);

    function getCZRXUniROI() external view returns (uint256, uint256);


    function getIZRXUniROI() external view returns (uint256, uint256);

    function getIREPUniROI() external view returns (uint256, uint256);

    function getIKNCUniROI() external view returns (uint256, uint256);

    function getIWBTCUniROI() external view returns (uint256, uint256);

    function getIUSDCUniROI() external view returns (uint256, uint256);

    function getIETHUniROI() external view returns (uint256, uint256);

    function getISAIUniROI() external view returns (uint256, uint256);

    function getIDAIUniROI() external view returns (uint256, uint256);

    function getILINKUniROI() external view returns (uint256, uint256);

    function getISUSDUniROI() external view returns (uint256, uint256);

    function getADAIUniROI() external view returns (uint256, uint256);

    function getATUSDUniROI() external view returns (uint256, uint256);

    function getAUSDCUniROI() external view returns (uint256, uint256);

    function getAUSDTUniROI() external view returns (uint256, uint256);

    function getASUSDUniROI() external view returns (uint256, uint256);

    function getALENDUniROI() external view returns (uint256, uint256);

    function getABATUniROI() external view returns (uint256, uint256);

    function getAETHUniROI() external view returns (uint256, uint256);

    function getALINKUniROI() external view returns (uint256, uint256);

    function getAKNCUniROI() external view returns (uint256, uint256);

    function getAREPUniROI() external view returns (uint256, uint256);

    function getAMKRUniROI() external view returns (uint256, uint256);

    function getAMANAUniROI() external view returns (uint256, uint256);

    function getAZRXUniROI() external view returns (uint256, uint256);

    function getASNXUniROI() external view returns (uint256, uint256);

    function getAWBTCUniROI() external view returns (uint256, uint256);

    function getDAIUniROI() external view returns (uint256, uint256);

    function getTUSDUniROI() external view returns (uint256, uint256);

    function getUSDCUniROI() external view returns (uint256, uint256);

    function getUSDTUniROI() external view returns (uint256, uint256);

    function getSUSDUniROI() external view returns (uint256, uint256);

    function getLENDUniROI() external view returns (uint256, uint256);

    function getBATUniROI() external view returns (uint256, uint256);

    function getETHUniROI() external view returns (uint256, uint256);

    function getLINKUniROI() external view returns (uint256, uint256);

    function getKNCUniROI() external view returns (uint256, uint256);

    function getREPUniROI() external view returns (uint256, uint256);

    function getMKRUniROI() external view returns (uint256, uint256);

    function getMANAUniROI() external view returns (uint256, uint256);

    function getZRXUniROI() external view returns (uint256, uint256);

    function getSNXUniROI() external view returns (uint256, uint256);

    function getWBTCUniROI() external view returns (uint256, uint256);

    // yToken ////
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


//
interface Uni {
    function swapExactTokensForTokens(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external;
}
