/*以太坊/qc上的uniswap：
1：两个ERC20的token，一个用于跟ETH进行交易，另一个用于记录流动性比例
2: 一个交易合约，继承自ERC20，在提供/收回流动性的时候，会分配liquid_token，表示所占流动性份额
3：一个Factory合约，用于生成交易合约
4：交易过程中，交易者有以下几种操作方式：
（1）将ETH转账给交易合约，交易合约调用token合约，token合约将交易合约拥有的余额进行转账
（2）指定需要购买的Token数量，以及最多愿意消耗的ETH，让交易合约来完成交易
（3）先将想要出售的Token委托给交易合约（此步是在外部操作），交易合约计算出可获取的ETH，如果大于等于交易者认同的最小金额，便将ETH转移给交易者，然后再将交易者委托的token转移给自己
（4）只指定想要获取的ETH和最多愿意卖出的token，具体卖出多少token看交易执行时的实际行情，同（3），需要交易者事先将最多数量的token委托给交易合约
（5）以eth作为中介，用指定数量的token1换token2，但token1能换取的eth不可低于某个值，此步骤相当于从（3）——>（1）
（6）以eth作为中介，用可变数量的token1换固定数量且价格不高于某个值的token2
（7）增加流动性，根据msg.sender提供的流动性的比例，向msg.sender增发对应数量的liquid_token
（8）减少流动性，根据msg.sender欲减少的流动性数量，向msg.sender发放应得的ETH和Token（包含了应得的手续费激励）, 并减少其对应数量的liquid_token
*/
pragma solidity ^0.5.0;
import "../tokens/ERC20.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapFactory.sol";
import "../interfaces/IUniswapExchange.sol";


contract UniswapExchange is ERC20 {

    /***********************************|
    |        Variables && Events        |
    |__________________________________*/

    // Variables
    bytes32 public name;         // Uniswap V1
    bytes32 public symbol;       // UNI-V1
    uint256 public decimals;     // 18
    IERC20 token;                // address of the ERC20 token traded on this contract
    IUniswapFactory factory;     // interface for the factory that created this contract

    // Events
    event TokenPurchase(address indexed buyer, uint256 indexed eth_sold, uint256 indexed tokens_bought);
    event EthPurchase(address indexed buyer, uint256 indexed tokens_sold, uint256 indexed eth_bought);
    event AddLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);
    event RemoveLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);


    /***********************************|
    |            Constsructor           |
    |__________________________________*/

    /**
     * @dev This function acts as a contract constructor which is not currently supported in contracts deployed
     *      using create_with_code_of(). It is called once by the factory during contract creation.
     */
    function setup(address token_addr) public {
        require(
            address(factory) == address(0) && address(token) == address(0) && token_addr != address(0),
            "INVALID_ADDRESS"
        );
        factory = IUniswapFactory(msg.sender);
        token = IERC20(token_addr);
        name = 0x556e697377617020563100000000000000000000000000000000000000000000;
        symbol = 0x554e492d56310000000000000000000000000000000000000000000000000000;
        decimals = 18;
    }


    /***********************************|
    |        Exchange Functions         |
    |__________________________________*/


    /**
     * @notice Convert ETH to Tokens.
     * @dev User specifies exact input (msg.value).
     * @dev User cannot specify minimum output or deadline.
     */
    function () external payable {
        ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }

    /**
      * @dev Pricing function for converting between ETH && Tokens.
      * @param input_amount Amount of ETH or Tokens being sold.   =△x
      * @param input_reserve Amount of ETH or Tokens (input type) in exchange reserves.    =x
      * @param output_reserve Amount of ETH or Tokens (output type) in exchange reserves.  =y
      * @return Amount of ETH or Tokens bought.  = △y
      * 如果手续费为p，则 △y = y * [△x * (1 - p) / (x + △x * (1 - p))]，即由于手续费的存在，可购买的△y数量会少一些
      */
    function getInputPrice(uint256 input_amount, uint256 input_reserve, uint256 output_reserve) public view returns (uint256) {
        require(input_reserve > 0 && output_reserve > 0, "INVALID_VALUE");
        uint256 input_amount_with_fee = input_amount.mul(997);
        uint256 numerator = input_amount_with_fee.mul(output_reserve);
        uint256 denominator = input_reserve.mul(1000).add(input_amount_with_fee);
        return numerator / denominator;
    }

    /**
      * @dev Pricing function for converting between ETH && Tokens.
      * @param output_amount Amount of ETH or Tokens being bought.
      * @param input_reserve Amount of ETH or Tokens (input type) in exchange reserves.
      * @param output_reserve Amount of ETH or Tokens (output type) in exchange reserves.
      * @return Amount of ETH or Tokens sold.
      */
    function getOutputPrice(uint256 output_amount, uint256 input_reserve, uint256 output_reserve) public view returns (uint256) {
        require(input_reserve > 0 && output_reserve > 0);
        uint256 numerator = input_reserve.mul(output_amount).mul(1000);
        uint256 denominator = (output_reserve.sub(output_amount)).mul(997);
        return (numerator / denominator).add(1);
    }

    function ethToTokenInput(uint256 eth_sold, uint256 min_tokens, uint256 deadline, address buyer, address recipient) private returns (uint256) {
        require(deadline >= block.timestamp && eth_sold > 0 && min_tokens > 0);
        uint256 token_reserve = token.balanceOf(address(this));  // 获取本合约账号拥有的token数量
        uint256 tokens_bought = getInputPrice(eth_sold, address(this).balance.sub(eth_sold), token_reserve);  // 计算出可购买到的token数量
        require(tokens_bought >= min_tokens);   // 要求可购买的token数量大于等于最小可接受额度
        require(token.transfer(recipient, tokens_bought));  // 将购买到的token从合约转移到接收者地址上
        emit TokenPurchase(buyer, eth_sold, tokens_bought);
        return tokens_bought;
    }

    /** msg.sender用eth为自己购买token
     * @notice Convert ETH to Tokens.
     * @dev User specifies exact input (msg.value) && minimum output.
     * @param min_tokens Minimum Tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of Tokens bought.
     */
    function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) public payable returns (uint256) {
        return ethToTokenInput(msg.value, min_tokens, deadline, msg.sender, msg.sender);
    }

    /**  msg.sender用eth购买token，并将token给第三方
     * @notice Convert ETH to Tokens && transfers Tokens to recipient.
     * @dev User specifies exact input (msg.value) && minimum output
     * @param min_tokens Minimum Tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output Tokens.
     * @return  Amount of Tokens bought.
     */
    function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) public payable returns(uint256) {
        require(recipient != address(this) && recipient != address(0));
        return ethToTokenInput(msg.value, min_tokens, deadline, msg.sender, recipient);
    }

    // 通过指定需要购买的token数量来进行交易，需要指定最多愿意支付的ETH
    function ethToTokenOutput(uint256 tokens_bought, uint256 max_eth, uint256 deadline, address payable buyer, address recipient) private returns (uint256) {
        require(deadline >= block.timestamp && tokens_bought > 0 && max_eth > 0);
        uint256 token_reserve = token.balanceOf(address(this));   // 本合约拥有的token数量
        uint256 eth_sold = getOutputPrice(tokens_bought, address(this).balance.sub(max_eth), token_reserve);  // 计算购买token所需的ETH
        // Throws if eth_sold > max_eth
        uint256 eth_refund = max_eth.sub(eth_sold);  // 计算剩余ETH，其中sub方法在结果为负数时会抛异常
        if (eth_refund > 0) {
            buyer.transfer(eth_refund);   // 将剩下的ETH退回给购买者
        }
        require(token.transfer(recipient, tokens_bought));  // 将购买到的token转移给接收者
        emit TokenPurchase(buyer, eth_sold, tokens_bought);
        return eth_sold;
    }

    /**
     * @notice Convert ETH to Tokens.
     * @dev User specifies maximum input (msg.value) && exact output.
     * @param tokens_bought Amount of tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of ETH sold.
     */
    function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) public payable returns(uint256) {
        return ethToTokenOutput(tokens_bought, msg.value, deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Convert ETH to Tokens && transfers Tokens to recipient.
     * @dev User specifies maximum input (msg.value) && exact output.
     * @param tokens_bought Amount of tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output Tokens.
     * @return Amount of ETH sold.
     */
    function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient) public payable returns (uint256) {
        require(recipient != address(this) && recipient != address(0));
        return ethToTokenOutput(tokens_bought, msg.value, deadline, msg.sender, recipient);
    }

    // 卖掉指定数量的token，获取eth
    function tokenToEthInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address buyer, address payable recipient) private returns (uint256) {
        require(deadline >= block.timestamp && tokens_sold > 0 && min_eth > 0);
        uint256 token_reserve = token.balanceOf(address(this));      // 合约拥有的token数量
        uint256 eth_bought = getInputPrice(tokens_sold, token_reserve, address(this).balance);   // 获得当前可获取的ETH
        uint256 wei_bought = eth_bought;
        require(wei_bought >= min_eth);    // 获取的ETH必须大于等于最小值
        recipient.transfer(wei_bought);    // 将ETH转移给接收者
        require(token.transferFrom(buyer, address(this), tokens_sold));   // 合约调用token合约，将token转移到自己账户里，此处需要购买者先授权出售的token给合约进行transferFrom
        emit EthPurchase(buyer, tokens_sold, wei_bought);
        return wei_bought;
    }

    /**
     * @notice Convert Tokens to ETH.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_eth Minimum ETH purchased.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of ETH bought.
     */
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) public returns (uint256) {
        return tokenToEthInput(tokens_sold, min_eth, deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Convert Tokens to ETH && transfers ETH to recipient.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_eth Minimum ETH purchased.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @return  Amount of ETH bought.
     */
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address payable recipient) public returns (uint256) {
        require(recipient != address(this) && recipient != address(0));
        return tokenToEthInput(tokens_sold, min_eth, deadline, msg.sender, recipient);
    }

    // 只指定想要获取的ETH和最大愿意卖出的token，具体卖出多少token看实际行情
    function tokenToEthOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address buyer, address payable recipient) private returns (uint256) {
        require(deadline >= block.timestamp && eth_bought > 0);
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 tokens_sold = getOutputPrice(eth_bought, token_reserve, address(this).balance);
        // tokens sold is always > 0
        require(max_tokens >= tokens_sold);
        recipient.transfer(eth_bought);
        require(token.transferFrom(buyer, address(this), tokens_sold));
        emit EthPurchase(buyer, tokens_sold, eth_bought);
        return tokens_sold;
    }

    /** 卖掉可变数量的token(不可超过最大值)，获取固定的eth
     * @notice Convert Tokens to ETH.
     * @dev User specifies maximum input && exact output.
     * @param eth_bought Amount of ETH purchased.
     * @param max_tokens Maximum Tokens sold.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of Tokens sold.
     */
    function tokenToEthSwapOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline) public returns (uint256) {
        return tokenToEthOutput(eth_bought, max_tokens, deadline, msg.sender, msg.sender);
    }

    /** 卖掉可变数量的token(不可超过最大值)，获取固定的eth给第三方
     * @notice Convert Tokens to ETH && transfers ETH to recipient.
     * @dev User specifies maximum input && exact output.
     * @param eth_bought Amount of ETH purchased.
     * @param max_tokens Maximum Tokens sold.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @return Amount of Tokens sold.
     */
    function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address payable recipient) public returns (uint256) {
        require(recipient != address(this) && recipient != address(0));
        return tokenToEthOutput(eth_bought, max_tokens, deadline, msg.sender, recipient);
    }

    // 进行币币交易token1 -> token2
    function tokenToTokenInput(
        uint256 tokens_sold,         // 准备出售的token1
        uint256 min_tokens_bought,   // 期望买到的最少的token2数量
        uint256 min_eth_bought,      // 通过出售token1获取的最少的ETH
        uint256 deadline,
        address buyer,
        address recipient,
        address payable exchange_addr)  // 另一个交易对（ETH<=>TOKEN2）的合约地址
    private returns (uint256)
    {
        require(deadline >= block.timestamp && tokens_sold > 0 && min_tokens_bought > 0 && min_eth_bought > 0);
        require(exchange_addr != address(this) && exchange_addr != address(0));
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 eth_bought = getInputPrice(tokens_sold, token_reserve, address(this).balance);
        uint256 wei_bought = eth_bought;
        require(wei_bought >= min_eth_bought);
        require(token.transferFrom(buyer, address(this), tokens_sold));
        uint256 tokens_bought = IUniswapExchange(exchange_addr).ethToTokenTransferInput.value(wei_bought)(min_tokens_bought, deadline, recipient);
        emit EthPurchase(buyer, tokens_sold, wei_bought);
        return tokens_bought;
    }

    /**
     * @notice Convert Tokens (token) to Tokens (token_addr).
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
     * @param min_eth_bought Minimum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param token_addr The address of the token being purchased.
     * @return Amount of Tokens (token_addr) bought.
     */
    function tokenToTokenSwapInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address token_addr)
    public returns (uint256)
    {
        address payable exchange_addr = factory.getExchange(token_addr);
        return tokenToTokenInput(tokens_sold, min_tokens_bought, min_eth_bought, deadline, msg.sender, msg.sender, exchange_addr);
    }

    /**
     * @notice Convert Tokens (token) to Tokens (token_addr) && transfers
     *         Tokens (token_addr) to recipient.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
     * @param min_eth_bought Minimum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param token_addr The address of the token being purchased.
     * @return Amount of Tokens (token_addr) bought.
     */
    function tokenToTokenTransferInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address recipient,
        address token_addr)
    public returns (uint256)
    {
        address payable exchange_addr = factory.getExchange(token_addr);
        return tokenToTokenInput(tokens_sold, min_tokens_bought, min_eth_bought, deadline, msg.sender, recipient, exchange_addr);
    }
    // token1换token2
    function tokenToTokenOutput(
        uint256 tokens_bought,    // 希望买入的token2数量，在其它交易对合约中
        uint256 max_tokens_sold,  // 可售出的最多token1数量
        uint256 max_eth_sold,     // 可接受的付出最多的ETH数量（用于买token2）
        uint256 deadline,
        address buyer,
        address recipient,
        address payable exchange_addr) // token2<=>ETH 交易对合约
    private returns (uint256)
    {
        require(deadline >= block.timestamp && (tokens_bought > 0 && max_eth_sold > 0));
        require(exchange_addr != address(this) && exchange_addr != address(0));
        uint256 eth_bought = IUniswapExchange(exchange_addr).getEthToTokenOutputPrice(tokens_bought);
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 tokens_sold = getOutputPrice(eth_bought, token_reserve, address(this).balance);
        // tokens sold is always > 0
        require(max_tokens_sold >= tokens_sold && max_eth_sold >= eth_bought);
        require(token.transferFrom(buyer, address(this), tokens_sold));
        uint256 eth_sold = IUniswapExchange(exchange_addr).ethToTokenTransferOutput.value(eth_bought)(tokens_bought, deadline, recipient);
        emit EthPurchase(buyer, tokens_sold, eth_bought);
        return tokens_sold;
    }

    /**
     * @notice Convert Tokens (token) to Tokens (token_addr).
     * @dev User specifies maximum input && exact output.
     * @param tokens_bought Amount of Tokens (token_addr) bought.
     * @param max_tokens_sold Maximum Tokens (token) sold.
     * @param max_eth_sold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param token_addr The address of the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
    function tokenToTokenSwapOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address token_addr)
    public returns (uint256)
    {
        address payable exchange_addr = factory.getExchange(token_addr);
        return tokenToTokenOutput(tokens_bought, max_tokens_sold, max_eth_sold, deadline, msg.sender, msg.sender, exchange_addr);
    }

    /**
     * @notice Convert Tokens (token) to Tokens (token_addr) && transfers
     *         Tokens (token_addr) to recipient.
     * @dev User specifies maximum input && exact output.
     * @param tokens_bought Amount of Tokens (token_addr) bought.
     * @param max_tokens_sold Maximum Tokens (token) sold.
     * @param max_eth_sold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param token_addr The address of the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
    function tokenToTokenTransferOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address recipient,
        address token_addr)
    public returns (uint256)
    {
        address payable exchange_addr = factory.getExchange(token_addr);
        return tokenToTokenOutput(tokens_bought, max_tokens_sold, max_eth_sold, deadline, msg.sender, recipient, exchange_addr);
    }

    /**
     * @notice Convert Tokens (token) to Tokens (exchange_addr.token).
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
     * @param min_eth_bought Minimum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param exchange_addr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (exchange_addr.token) bought.
     */
    function tokenToExchangeSwapInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address payable exchange_addr)
    public returns (uint256)
    {
        return tokenToTokenInput(tokens_sold, min_tokens_bought, min_eth_bought, deadline, msg.sender, msg.sender, exchange_addr);
    }

    /**
     * @notice Convert Tokens (token) to Tokens (exchange_addr.token) && transfers
     *         Tokens (exchange_addr.token) to recipient.
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
     * @param min_eth_bought Minimum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param exchange_addr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (exchange_addr.token) bought.
     */
    function tokenToExchangeTransferInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address recipient,
        address payable exchange_addr)
    public returns (uint256)
    {
        require(recipient != address(this));
        return tokenToTokenInput(tokens_sold, min_tokens_bought, min_eth_bought, deadline, msg.sender, recipient, exchange_addr);
    }

    /**
     * @notice Convert Tokens (token) to Tokens (exchange_addr.token).
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies maximum input && exact output.
     * @param tokens_bought Amount of Tokens (token_addr) bought.
     * @param max_tokens_sold Maximum Tokens (token) sold.
     * @param max_eth_sold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param exchange_addr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
    function tokenToExchangeSwapOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address payable exchange_addr)
    public returns (uint256)
    {
        return tokenToTokenOutput(tokens_bought, max_tokens_sold, max_eth_sold, deadline, msg.sender, msg.sender, exchange_addr);
    }

    /**
     * @notice Convert Tokens (token) to Tokens (exchange_addr.token) && transfers
     *         Tokens (exchange_addr.token) to recipient.
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies maximum input && exact output.
     * @param tokens_bought Amount of Tokens (token_addr) bought.
     * @param max_tokens_sold Maximum Tokens (token) sold.
     * @param max_eth_sold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param exchange_addr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
    function tokenToExchangeTransferOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address recipient,
        address payable exchange_addr)
    public returns (uint256)
    {
        require(recipient != address(this));
        return tokenToTokenOutput(tokens_bought, max_tokens_sold, max_eth_sold, deadline, msg.sender, recipient, exchange_addr);
    }


    /***********************************|
    |         Getter Functions          |
    |__________________________________*/

    /**
     * @notice Public price function for ETH to Token trades with an exact input.
     * @param eth_sold Amount of ETH sold.
     * @return Amount of Tokens that can be bought with input ETH.
     */
    function getEthToTokenInputPrice(uint256 eth_sold) public view returns (uint256) {
        require(eth_sold > 0);
        uint256 token_reserve = token.balanceOf(address(this));
        return getInputPrice(eth_sold, address(this).balance, token_reserve);
    }

    /**
     * @notice Public price function for ETH to Token trades with an exact output.
     * @param tokens_bought Amount of Tokens bought.
     * @return Amount of ETH needed to buy output Tokens.
     */
    function getEthToTokenOutputPrice(uint256 tokens_bought) public view returns (uint256) {
        require(tokens_bought > 0);
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 eth_sold = getOutputPrice(tokens_bought, address(this).balance, token_reserve);
        return eth_sold;
    }

    /**
     * @notice Public price function for Token to ETH trades with an exact input.
     * @param tokens_sold Amount of Tokens sold.
     * @return Amount of ETH that can be bought with input Tokens.
     */
    function getTokenToEthInputPrice(uint256 tokens_sold) public view returns (uint256) {
        require(tokens_sold > 0);
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 eth_bought = getInputPrice(tokens_sold, token_reserve, address(this).balance);
        return eth_bought;
    }

    /**
     * @notice Public price function for Token to ETH trades with an exact output.
     * @param eth_bought Amount of output ETH.
     * @return Amount of Tokens needed to buy output ETH.
     */
    function getTokenToEthOutputPrice(uint256 eth_bought) public view returns (uint256) {
        require(eth_bought > 0);
        uint256 token_reserve = token.balanceOf(address(this));
        return getOutputPrice(eth_bought, token_reserve, address(this).balance);
    }

    /**
     * @return Address of Token that is sold on this exchange.
     */
    function tokenAddress() public view returns (address) {
        return address(token);
    }

    /**
     * @return Address of factory that created this exchange.
     */
    function factoryAddress() public view returns (address) {
        return address(factory);
    }


    /***********************************|
    |        Liquidity Functions        |
    |__________________________________*/

    /**
     * @notice Deposit ETH && Tokens (token) at current ratio to mint UNI tokens.
     * @dev min_liquidity does nothing when total UNI supply is 0.
     * @param min_liquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
     * @param max_tokens Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return The amount of UNI minted.
     */
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) public payable returns (uint256) {
        require(deadline > block.timestamp && max_tokens > 0 && msg.value > 0, 'UniswapExchange#addLiquidity: INVALID_ARGUMENT');
        uint256 total_liquidity = _totalSupply;

        if (total_liquidity > 0) {  // 后续添加流动性
            require(min_liquidity > 0);
            uint256 eth_reserve = address(this).balance.sub(msg.value);     // 当前合约ETH余额减去交易中的ETH，即本交易发送前合约的ETH余额（包含了手续费）
            uint256 token_reserve = token.balanceOf(address(this));         // 当前合约拥有的token数量
            uint256 token_amount = (msg.value.mul(token_reserve) / eth_reserve).add(1);   // 计算出交易者所需承担的等比例的token数量=(本次发送的ETH/合约ETH余额)*合约token数量 + 1
            uint256 liquidity_minted = msg.value.mul(total_liquidity) / eth_reserve;      // 计算出同比例增加的流动性数量
            require(max_tokens >= token_amount && liquidity_minted >= min_liquidity);     // 需要增加的token数不能大于流动性提供者可承受的最大值，增加的流动性也要大于输入的最小值
            _balances[msg.sender] = _balances[msg.sender].add(liquidity_minted);   // 给流动性提供者增加流动性token数量（流动性也token化，根据token数量计算当前提供者占有的比例）
            _totalSupply = total_liquidity.add(liquidity_minted);                  // 添加总的流动性数量
            require(token.transferFrom(msg.sender, address(this), token_amount));  // 将msg.sender的token转移给本合约
            emit AddLiquidity(msg.sender, msg.value, token_amount);
            emit Transfer(address(0), msg.sender, liquidity_minted);
            return liquidity_minted;

        } else {  // 首次添加流动性
            require(address(factory) != address(0) && address(token) != address(0) && msg.value >= 1000000000, "INVALID_VALUE");
            require(factory.getExchange(address(token)) == address(this));
            uint256 token_amount = max_tokens;
            uint256 initial_liquidity = address(this).balance;   // 初始的流动性token等于合约的ETH余额
            _totalSupply = initial_liquidity;                    //
            _balances[msg.sender] = initial_liquidity;           // 将初始的流动性总量都赋予msg.sender
            require(token.transferFrom(msg.sender, address(this), token_amount));   // 将msg.sender的token转给本合约
            emit AddLiquidity(msg.sender, msg.value, token_amount);
            emit Transfer(address(0), msg.sender, initial_liquidity);
            return initial_liquidity;
        }
    }

    /**
     * @dev Burn UNI tokens to withdraw ETH && Tokens at current ratio.
     * @param amount Amount of UNI burned.
     * @param min_eth Minimum ETH withdrawn.
     * @param min_tokens Minimum Tokens withdrawn.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return The amount of ETH && Tokens withdrawn.
     */
    function removeLiquidity(uint256 amount, uint256 min_eth, uint256 min_tokens, uint256 deadline) public returns (uint256, uint256) {
        require(amount > 0 && deadline > block.timestamp && min_eth > 0 && min_tokens > 0);
        uint256 total_liquidity = _totalSupply;
        require(total_liquidity > 0);
        uint256 token_reserve = token.balanceOf(address(this));  // 本合约拥有的token量
        uint256 eth_amount = amount.mul(address(this).balance) / total_liquidity;   // amount/total_liquidity是msg.sender提供的流动性占比，所以eth_mount表示其占有多少的eth
        uint256 token_amount = amount.mul(token_reserve) / total_liquidity;
        require(eth_amount >= min_eth && token_amount >= min_tokens);

        _balances[msg.sender] = _balances[msg.sender].sub(amount);  // 从msg.sender中减去提取的流动性数量，如果减去的数量超过拥有的数量，会抛出异常
        _totalSupply = total_liquidity.sub(amount);                 // 减少总的流动性
        msg.sender.transfer(eth_amount);                            // 将msg.sender拥有的eth数量转给他，此部分已经包含了增加流动性后的手续费收入
        require(token.transfer(msg.sender, token_amount));          // 将msg.sender拥有的token数量转给他，此部分已经包含了增加流动性后的手续费收入
        emit RemoveLiquidity(msg.sender, eth_amount, token_amount);
        emit Transfer(msg.sender, address(0), amount);
        return (eth_amount, token_amount);
    }


}


