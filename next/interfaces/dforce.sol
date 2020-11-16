/**
 *Submitted for verification at Etherscan.io on 2020-08-24
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.5.17;

interface dRewards {
    function withdraw(uint) external;
    function getReward() external;
    function stake(uint) external;
    function balanceOf(address) external view returns (uint);
    function exit() external;
}

interface dERC20 {
    function mint(address, uint256) external;
    function redeem(address, uint) external;
    function getTokenBalance(address) external view returns (uint);
    function getExchangeRate() external view returns (uint);
}
