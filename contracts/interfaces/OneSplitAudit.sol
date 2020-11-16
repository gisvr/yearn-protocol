//https://etherscan.io/address/0x64d04c6da4b0bc0109d7fc29c9d09c802c061898#code


pragma solidity ^0.5.0;

interface OneSplitAudit {
    function swap(
        address fromToken,
        address destToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata distribution,
        uint256 flags
    )
    external
    payable
    returns(uint256 returnAmount);

    function getExpectedReturn(
        address fromToken,
        address destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags // See constants in IOneSplit.sol // 1 - Uniswap, 2 - Kyber, 4 - Bancor, 8 - Oasis, 16 - Compound, 32 - Fulcrum, 64 - Chai, 128 - Aave, 256 - SmartToken, 1024 - bDAI
    )
    external
    view
    returns(
        uint256 returnAmount,
        uint256[] memory distribution // [Uniswap, Kyber, Bancor, Oasis]
    );
}


