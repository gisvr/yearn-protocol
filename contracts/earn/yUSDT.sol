/**
 *Submitted for verification at Etherscan.io on 2020-02-12 v2
 https://etherscan.io/address/0x83f798e925bcd4017eb265844fddabb448f1707d#code
*/

pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";


import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

import "../misc/ERC20.sol";
import "../interfaces/compound.sol";
import "../interfaces/aave.sol";
import "../interfaces/fulcrum.sol";


interface IIEarnManager {
    function recommend(address _token) external view returns (
        string memory choice,
        uint256 capr,
        uint256 iapr,
        uint256 aapr,
        uint256 dapr
    );
}

contract Structs {
    struct Val {
        uint256 value;
    }

    enum ActionType {
        Deposit, // supply tokens
        Withdraw  // borrow tokens
    }

    enum AssetDenomination {
        Wei // the amount is denominated in wei
    }

    enum AssetReference {
        Delta // the amount is given as a delta from the current value
    }

    struct AssetAmount {
        bool sign; // true if positive
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }

    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }

    struct Info {
        address owner;  // The address that owns the account
        uint256 number; // A nonce that allows a single address to control many accounts
    }

    struct Wei {
        bool sign; // true if positive
        uint256 value;
    }
}

contract DyDx is Structs {
    function getAccountWei(Info memory account, uint256 marketId) public view returns (Wei memory);

    function operate(Info[] memory, ActionArgs[] memory) public;
}


contract yUSDT is ERC20, ERC20Detailed, ReentrancyGuard, Ownable, Structs {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public pool;
    address public token;
    address public compound;
    address public fulcrum;
    address public aave;
    address public aaveToken;
    address public dydx;
    uint256 public dToken;
    address public apr;

    enum Lender {
        NONE,
        DYDX,
        COMPOUND,
        AAVE,
        FULCRUM
    }

    Lender public provider = Lender.NONE;

    constructor () public ERC20Detailed("iearn USDT", "yUSDT", 6) {
        //Tether USD USDT
        token = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        // IEarnAPRWithPool
        apr = address(0xdD6d648C991f7d47454354f4Ef326b04025a48A8);
        //dydx SoloMargin
        dydx = address(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e);
        //LendingPoolAddressesProvider
        aave = address(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);
        // Fulcrum USDC iToken iUSDC
        fulcrum = address(0xF013406A0B1d544238083DF0B93ad0d2cBE0f65f);
        // AToken-》 aUSDT
        aaveToken = address(0x71fc860F7D3A592A4a98740e39dB31d25db65ae8);
        // Compound USD Coin cUSDC
        //compound = address(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
        // Compound USDT -》cUSDT
        compound = address(0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9);

        dToken = 0;
        // 市场id
        //  approveToken();
    }

    // Ownable setters incase of support in future for these systems
    function set_new_APR(address _new_APR) public onlyOwner {
        apr = _new_APR;
    }

    function set_new_FULCRUM(address _new_FULCRUM) public onlyOwner {
        fulcrum = _new_FULCRUM;
    }

    function set_new_COMPOUND(address _new_COMPOUND) public onlyOwner {
        compound = _new_COMPOUND;
    }

    function set_new_DTOKEN(uint256 _new_DTOKEN) public onlyOwner {
        dToken = _new_DTOKEN;
    }

    // Quick swap low gas method for pool swaps
    function deposit(uint256 _amount)
    external
    nonReentrant
    {
        require(_amount > 0, "deposit must be greater than 0");
        // 累加合约地址拥有的token
        pool = _calcPoolValueInToken();

        // 将msg.sender的USDT的转入合约，
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);

        // Calculate pool shares
        uint256 shares = 0;
        if (pool == 0) {
            shares = _amount;
            pool = _amount;
        } else {
            // （充值量* yUSDT量)/pool池子总量
            shares = (_amount.mul(_totalSupply)).div(pool);
        }
        // 累加合约地址拥有的token，池量增加了充值
        pool = _calcPoolValueInToken();
        //通过充值铸造 yUSDT
        _mint(msg.sender, shares);
    }

    // No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares)
    external
    nonReentrant
    {
        require(_shares > 0, "withdraw must be greater than 0");

        uint256 ibalance = balanceOf(msg.sender);
        require(_shares <= ibalance, "insufficient balance");

        // Could have over value from cTokens
        pool = _calcPoolValueInToken();
        // Calc to redeem before updating balances
        // 计算用户在池中的拥有的量 (pool*shares) / totalSupply
        uint256 r = (pool.mul(_shares)).div(_totalSupply);

        //更新 用户的体现后余额
        _balances[msg.sender] = _balances[msg.sender].sub(_shares, "redeem amount exceeds balance");

        //在总量上减去 用户持有的股份
        _totalSupply = _totalSupply.sub(_shares);

        emit Transfer(msg.sender, address(0), _shares);

        // Check balance
        // 获取合约地址在USDT上的余额
        uint256 b = IERC20(token).balanceOf(address(this));
        if (b < r) {
            // r 在pool中拥有的量，b 合约地址拥有的USDT 量
            // 通过外部函数指定 体现的池
            _withdrawSome(r.sub(b));
        }
        // 从USDT 合约往发起用户体现
        IERC20(token).safeTransfer(msg.sender, r);
        pool = _calcPoolValueInToken();
    }

    function() external payable {
        //直接transfor ETH 不做处理
    }

    // 推荐
    function recommend() public view returns (Lender) {
        (,uint256 capr,uint256 iapr,uint256 aapr,uint256 dapr) = IIEarnManager(apr).recommend(token);
        uint256 max = 0;
        if (capr > max) {
            max = capr;
        }
        if (iapr > max) {
            max = iapr;
        }
        if (aapr > max) {
            max = aapr;
        }
        if (dapr > max) {
            max = dapr;
        }

        Lender newProvider = Lender.NONE;
        if (max == capr) {
            newProvider = Lender.COMPOUND;
        } else if (max == iapr) {
            newProvider = Lender.FULCRUM;
        } else if (max == aapr) {
            newProvider = Lender.AAVE;
        } else if (max == dapr) {
            newProvider = Lender.DYDX;
        }
        return newProvider;
    }

    function supplyDydx(uint256 amount) public {
        Info[] memory infos = new Info[](1);
        infos[0] = Info(address(this), 0);

        AssetAmount memory amt = AssetAmount(true, AssetDenomination.Wei, AssetReference.Delta, amount);
        ActionArgs memory act;
        act.actionType = ActionType.Deposit;
        act.accountId = 0;
        act.amount = amt;
        act.primaryMarketId = dToken;
        act.otherAddress = address(this);

        ActionArgs[] memory args = new ActionArgs[](1);
        args[0] = act;

        DyDx(dydx).operate(infos, args);
    }

    function _withdrawDydx(uint256 amount) internal {
        Info[] memory infos = new Info[](1);
        infos[0] = Info(address(this), 0);

        AssetAmount memory amt = AssetAmount(false, AssetDenomination.Wei, AssetReference.Delta, amount);
        ActionArgs memory act;
        act.actionType = ActionType.Withdraw;
        act.accountId = 0;
        act.amount = amt;
        act.primaryMarketId = dToken;
        act.otherAddress = address(this);

        ActionArgs[] memory args = new ActionArgs[](1);
        args[0] = act;

        DyDx(dydx).operate(infos, args);
    }

    function getAave() public view returns (address) {
        return LendingPoolAddressesProvider(aave).getLendingPool();
    }

    function getAaveCore() public view returns (address) {
        return LendingPoolAddressesProvider(aave).getLendingPoolCore();
    }

    function approveToken() public {
        IERC20(token).safeApprove(compound, uint(- 1));
        //also add to constructor
        IERC20(token).safeApprove(dydx, uint(- 1));
        IERC20(token).safeApprove(getAaveCore(), uint(- 1));
        // aave 需要获取代理地址
        IERC20(token).safeApprove(fulcrum, uint(- 1));
    }

    function balance() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function balanceDydx() public view returns (uint256) {
        Wei memory bal = DyDx(dydx).getAccountWei(Info(address(this), 0), dToken);
        return bal.value;
    }

    function balanceCompound() public view returns (uint256) {
        return IERC20(compound).balanceOf(address(this));
    }

    function balanceCompoundInToken() public view returns (uint256) {
        // Mantisa 1e18 to decimals
        uint256 b = balanceCompound();
        if (b > 0) {
            b = b.mul(Compound(compound).exchangeRateStored()).div(1e18);
        }
        return b;
    }

    function balanceFulcrumInToken() public view returns (uint256) {
        uint256 b = balanceFulcrum();
        if (b > 0) {
            b = Fulcrum(fulcrum).assetBalanceOf(address(this));
        }
        return b;
    }

    function balanceFulcrum() public view returns (uint256) {
        return IERC20(fulcrum).balanceOf(address(this));
    }

    function balanceAave() public view returns (uint256) {
        return IERC20(aaveToken).balanceOf(address(this));
    }

    function _balance() internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _balanceDydx() internal view returns (uint256) {
        Wei memory bal = DyDx(dydx).getAccountWei(Info(address(this), 0), dToken);
        return bal.value;
    }

    function _balanceCompound() internal view returns (uint256) {
        return IERC20(compound).balanceOf(address(this));
    }

    function _balanceCompoundInToken() internal view returns (uint256) {
        // Mantisa 1e18 to decimals
        uint256 b = balanceCompound();
        if (b > 0) {
            b = b.mul(Compound(compound).exchangeRateStored()).div(1e18);
        }
        return b;
    }

    function _balanceFulcrumInToken() internal view returns (uint256) {
        uint256 b = balanceFulcrum();
        if (b > 0) {
            b = Fulcrum(fulcrum).assetBalanceOf(address(this));
        }
        return b;
    }

    function _balanceFulcrum() internal view returns (uint256) {
        return IERC20(fulcrum).balanceOf(address(this));
    }

    function _balanceAave() internal view returns (uint256) {
        return IERC20(aaveToken).balanceOf(address(this));
    }

    function _withdrawAll() internal {
        uint256 amount = _balanceCompound();
        if (amount > 0) {
            _withdrawCompound(amount);
        }
        amount = _balanceDydx();
        if (amount > 0) {
            _withdrawDydx(amount);
        }
        amount = _balanceFulcrum();
        if (amount > 0) {
            _withdrawFulcrum(amount);
        }
        amount = _balanceAave();
        if (amount > 0) {
            _withdrawAave(amount);
        }
    }

    function _withdrawSomeCompound(uint256 _amount) internal {
        uint256 b = balanceCompound();
        uint256 bT = balanceCompoundInToken();
        require(bT >= _amount, "insufficient funds");
        // can have unintentional rounding errors
        uint256 amount = (b.mul(_amount)).div(bT).add(1);
        _withdrawCompound(amount);
    }

    // 1999999614570950845
    function _withdrawSomeFulcrum(uint256 _amount) internal {
        // Balance of fulcrum tokens, 1 iDAI = 1.00x DAI
        uint256 b = balanceFulcrum();
        // 1970469086655766652
        // Balance of token in fulcrum
        uint256 bT = balanceFulcrumInToken();
        // 2000000803224344406
        require(bT >= _amount, "insufficient funds");
        // can have unintentional rounding errors
        uint256 amount = (b.mul(_amount)).div(bT).add(1);
        _withdrawFulcrum(amount);
    }

    function _withdrawSome(uint256 _amount) internal {
        if (provider == Lender.COMPOUND) {
            _withdrawSomeCompound(_amount);
        }
        if (provider == Lender.AAVE) {
            require(balanceAave() >= _amount, "insufficient funds");
            _withdrawAave(_amount);
        }
        if (provider == Lender.DYDX) {
            require(balanceDydx() >= _amount, "insufficient funds");
            _withdrawDydx(_amount);
        }
        if (provider == Lender.FULCRUM) {
            _withdrawSomeFulcrum(_amount);
        }
    }

    // 移仓
    function rebalance() public {
        Lender newProvider = recommend();

        if (newProvider != provider) {
            _withdrawAll();
        }

        // 获取 合约中USDT 的余额 移动到价格最合适的 合约中
        if (balance() > 0) {
            if (newProvider == Lender.DYDX) {
                supplyDydx(balance());
            } else if (newProvider == Lender.FULCRUM) {
                supplyFulcrum(balance());
            } else if (newProvider == Lender.COMPOUND) {
                supplyCompound(balance());
            } else if (newProvider == Lender.AAVE) {
                supplyAave(balance());
            }
        }

        provider = newProvider;
    }

    // Internal only rebalance for better gas in redeem
    function _rebalance(Lender newProvider) internal {
        if (_balance() > 0) {
            if (newProvider == Lender.DYDX) {
                supplyDydx(_balance());
            } else if (newProvider == Lender.FULCRUM) {
                supplyFulcrum(_balance());
            } else if (newProvider == Lender.COMPOUND) {
                supplyCompound(_balance());
            } else if (newProvider == Lender.AAVE) {
                supplyAave(_balance());
            }
        }
        provider = newProvider;
    }

    function supplyAave(uint amount) public {
        Aave(getAave()).deposit(token, amount, 0);
    }

    function supplyFulcrum(uint amount) public {
        require(Fulcrum(fulcrum).mint(address(this), amount) > 0, "FULCRUM: supply failed");
    }

    function supplyCompound(uint amount) public {
        require(Compound(compound).mint(amount) == 0, "COMPOUND: supply failed");
    }

    function _withdrawAave(uint amount) internal {
        AToken(aaveToken).redeem(amount);
    }

    function _withdrawFulcrum(uint amount) internal {
        require(Fulcrum(fulcrum).burn(address(this), amount) > 0, "FULCRUM: withdraw failed");
    }

    function _withdrawCompound(uint amount) internal {
        require(Compound(compound).redeem(amount) == 0, "COMPOUND: withdraw failed");
    }

    function _calcPoolValueInToken() internal view returns (uint) {
        return _balanceCompoundInToken()
        .add(_balanceFulcrumInToken())
        .add(_balanceDydx())
        .add(_balanceAave())
        .add(_balance());
    }

    function calcPoolValueInToken() public view returns (uint) {
        return balanceCompoundInToken()
        .add(balanceFulcrumInToken())
        .add(balanceDydx())
        .add(balanceAave())
        .add(balance());
    }

    function getPricePerFullShare() public view returns (uint) {
        uint _pool = calcPoolValueInToken();
        return _pool.mul(1e18).div(_totalSupply);
    }
}
