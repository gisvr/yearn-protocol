/**
 *Submitted for verification at Etherscan.io on 2020-08-24
 https://etherscan.io/address/0xf147b8125d2ef93fb6965db97d6746952a133934#code
 策略投票

//mintr:   @title Token Minter //@author Curve Finance
//Escrow： @title Voting Escrow  //@author Curve Finance
//         @notice Votes have a weight depending on time, so that users are committed to the future of (whatever they are voting for)
//         @dev Vote weight decays linearly over time. Lock time cannot be  more than `MAXTIME` (4 years).
//pool：   @title Liquidity Gauge //@author Curve Finance
          //@notice Used for measuring liquidity and insurance
//strategy： StrategyProxy
//want： Curve.fi: yCrv Token //https://www.curve.fi/y
*/


// SPDX-License-Identifier: MIT

pragma solidity ^0.5.17;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "../../../interfaces/uniswap.sol";
import "../../../interfaces/Mintr.sol";
import "../../../interfaces/curvefi.sol";
import "../../../interfaces/Gauge.sol";

import "../../../interfaces/yERC20.sol";
import "../../../interfaces/controller.sol";

/*

 A strategy must implement the following calls;

 - deposit()
 - withdraw(address) must exclude any tokens used in the yield - Controller role - withdraw should return to Controller
 - withdraw(uint) - Controller | Vault role - withdraw should always return to vault
 - withdrawAll() - Controller | Vault role - withdraw should always return to vault
 - balanceOf()

 Where possible, strategies must remain as immutable as possible, instead of updating variables, we update the contract by linking it in the controller

*/


interface VoteEscrow {
    function create_lock(uint, uint) external;

    function increase_amount(uint) external;

    function withdraw() external;
}

contract CurveYCRVVoter {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address constant public want = address(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);
    address constant public pool = address(0xFA712EE4788C042e2B7BB55E6cb8ec569C4530c1);
    address constant public mintr = address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);
    address constant public crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);

    address constant public escrow = address(0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2);

    address public governance;
    address public strategy;

    constructor() public {
        governance = msg.sender;
    }

    function getName() external pure returns (string memory) {
        return "CurveYCRVVoter";
    }

    function setStrategy(address _strategy) external {
        require(msg.sender == governance, "!governance");
        strategy = _strategy;
    }

    function deposit() public {
        uint _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(pool, 0);
            IERC20(want).safeApprove(pool, _want);
            Gauge(pool).deposit(_want);
        }
    }

    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint balance) {
        require(msg.sender == strategy, "!controller");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(strategy, balance);
    }

    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint _amount) external {
        require(msg.sender == strategy, "!controller");
        uint _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }
        IERC20(want).safeTransfer(strategy, _amount);
    }

    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external returns (uint balance) {
        require(msg.sender == strategy, "!controller");
        _withdrawAll();


        balance = IERC20(want).balanceOf(address(this));
        IERC20(want).safeTransfer(strategy, balance);
    }

    function _withdrawAll() internal {
        Gauge(pool).withdraw(Gauge(pool).balanceOf(address(this)));
    }

    function createLock(uint _value, uint _unlockTime) external {
        require(msg.sender == strategy || msg.sender == governance, "!authorized");
        IERC20(crv).safeApprove(escrow, 0);
        IERC20(crv).safeApprove(escrow, _value);
        VoteEscrow(escrow).create_lock(_value, _unlockTime);
    }

    function increaseAmount(uint _value) external {
        require(msg.sender == strategy || msg.sender == governance, "!authorized");
        IERC20(crv).safeApprove(escrow, 0);
        IERC20(crv).safeApprove(escrow, _value);
        VoteEscrow(escrow).increase_amount(_value);
    }

    function release() external {
        require(msg.sender == strategy || msg.sender == governance, "!authorized");
        VoteEscrow(escrow).withdraw();
    }

    function _withdrawSome(uint256 _amount) internal returns (uint) {
        Gauge(pool).withdraw(_amount);
        return _amount;
    }

    function balanceOfWant() public view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint) {
        return Gauge(pool).balanceOf(address(this));
    }

    function balanceOf() public view returns (uint) {
        return balanceOfWant()
        .add(balanceOfPool());
    }

    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    // 抽象的 execute的执行方法。
    function execute(address to, uint value, bytes calldata data) external returns (bool, bytes memory) {
        require(msg.sender == strategy || msg.sender == governance, "!governance");
        // 执行 合约的方法，value 传入的eth，data接口参数
        //crv, 0, abi.encodeWithSignature("transfer(address,uint256)", msg.sender, _balance)
        (bool success, bytes memory result) = to.call.value(value)(data);

        return (success, result);
    }
}
