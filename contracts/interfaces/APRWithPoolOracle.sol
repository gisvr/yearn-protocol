pragma solidity ^0.5.16;

interface APRWithPoolOracle {

    function getDDEXAPR(address token) external view returns (uint256);
    function getDDEXAPRAdjusted(address token, uint256 _supply) external view returns (uint256);
    function getLENDFAPR(address token) external view returns (uint256);
    function getLENDFAPRAdjusted(address token, uint256 _supply) external view returns (uint256);
    function getCompoundAPR(address token) external view returns (uint256);
    function getCompoundAPRAdjusted(address token, uint256 _supply) external view returns (uint256);
    function getFulcrumAPR(address token) external view returns(uint256);
    function getFulcrumAPRAdjusted(address token, uint256 _supply) external view returns(uint256);
    function getDyDxAPR(uint256 marketId) external view returns(uint256);
    function getDyDxAPRAdjusted(uint256 marketId, uint256 _supply) external view returns(uint256);
    function getAaveCore() external view returns (address);
    function getAaveAPR(address token) external view returns (uint256);
    function getAaveAPRAdjusted(address token, uint256 _supply) external view returns (uint256);

}

// YToken的 接口
interface IYToken {
    function calcPoolValueInToken() external view returns (uint256);
    function decimals() external view returns (uint256);
}
