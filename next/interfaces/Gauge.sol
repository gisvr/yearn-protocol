//https://dao.curve.fi/minter/gauges
// https://etherscan.io/address/0xFA712EE4788C042e2B7BB55E6cb8ec569C4530c1#readContract


pragma solidity ^0.5.17;


interface Gauge {
    function deposit(uint) external;

    function balanceOf(address) external view returns (uint);

    function withdraw(uint) external;
}

