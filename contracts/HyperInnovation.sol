pragma solidity ^0.4.11;

import './ERC20.sol';
import './SafeMath.sol';

// @title HyperInnovation Contract with Token Sale Functionality as well
contract HyperInnovation is ERC20,SafeMath{

  // flag to determine if address is for a real contract or not
  bool isHyperInnovation = false;
  // Address of Owner for this Contract
  address public owner;

  // Define the current state of crowdsale
  enum State{PreFunding, Funding, Success, Failure}

  // Token related information
  string public constant name = "HyperInnovation";
  string public constant symbol = "HIT";
  uint256 public constant decimals = 18;  // decimal places

  // Events for refund process
  event Refund(address indexed _from, uint256 _value);

  // Mapping of token balance and allowed address for each address with transfer limit
  mapping (address => uint256) balances;
  mapping (address => mapping (address => uint256)) allowed;

  // Crowdsale information
  bool public finalizedCrowdfunding = false;

  uint256 public fundingStartBlock; // crowdsale start block
  uint256 public fundingEndBlock; // crowdsale end block

  // Maximum Token Sale
  uint256 public tokenSaleMax;
  // Min tokens needs to be sold out for success
  uint256 public tokenSaleMin;


  // HyperInnovation:ETH exchange rate
  uint256 public tokensPerEther;

  // Constructor function sets following
  // @param fundingStartBlock block number at which funding will start
  // @param fundingEndBlock block number at which funding will end
  // @param tokenSaleMax maximum number of token to sale
  // @param tokenSaleMin minimum number of token to sale
  // @param tokensPerEther number of token to sale per ether
  function HyperInnovation(uint256 _fundingStartBlock,
                            uint256 _fundingEndBlock,
                            uint256 _tokenSaleMax,
                            uint256 _tokenSaleMin,
                            uint256 _tokensPerEther) {
      // Is funding already started then throw
      if (_fundingStartBlock <= block.number) throw;
      // If fundingEndBlock or fundingStartBlock value is not correct then throw
      if (_fundingEndBlock   <= _fundingStartBlock) throw;
      // If tokenSaleMax or tokenSaleMin value is not correct then throw
      if (_tokenSaleMax <= _tokenSaleMin) throw;
      // If tokensPerEther value is 0 then throw
      if (_tokensPerEther == 0) throw;
      // Initalized all param
      fundingStartBlock = _fundingStartBlock;
      fundingEndBlock = _fundingEndBlock;
      tokenSaleMax = _tokenSaleMax;
      tokenSaleMin = _tokenSaleMin;
      tokensPerEther = _tokensPerEther;
      // Mark it is HyperInnovation
      isHyperInnovation = true;
      //set owner of the contract
      owner = msg.sender;
  }

  // Ownership related modifer and functions
  // @dev Throws if called by any account other than the owner
  modifier onlyOwner() {
    if (msg.sender != owner) {
      throw;
    }
    _;
  }

  // @dev Allows the current owner to transfer control of the contract to a newOwner.
  // @param newOwner The address to transfer ownership to.
  function transferOwnership(address newOwner) onlyOwner {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }

  // @param who The address of the investor to check balance
  // @return balance tokens of investor address
  function balanceOf(address who) constant returns (uint) {
      return balances[who];
  }

  // @param owner The address of the account owning tokens
  // @param spender The address of the account able to transfer the tokens
  // @return Amount of remaining tokens allowed to spent
  function allowance(address _owner, address _spender) constant returns (uint) {
      return allowed[_owner][_spender];
  }

  //  Transfer `value` HyperInnovation from sender's account
  // `msg.sender` to provided account address `to`.
  // @dev Required state: Success
  // @param to The address of the recipient
  // @param value The number of HyperInnovation to transfer
  // @return Whether the transfer was successful or not
  function transfer(address to, uint value) returns (bool ok) {
      if (getState() != State.Success) throw; // Abort if crowdfunding was not a success.
      uint256 senderBalance = balances[msg.sender];
      if ( senderBalance >= value && value > 0) {
          senderBalance = safeSub(senderBalance, value);
          balances[msg.sender] = senderBalance;
          balances[to] = safeAdd(balances[to], value);
          Transfer(msg.sender, to, value);
          return true;
      }
      return false;
  }

  //  Transfer `value` HyperInnovation from sender 'from'
  // to provided account address `to`.
  // @dev Required state: Success
  // @param from The address of the sender
  // @param to The address of the recipient
  // @param value The number of HyperInnovation to transfer
  // @return Whether the transfer was successful or not
  function transferFrom(address from, address to, uint value) returns (bool ok) {
      if (getState() != State.Success) throw; // Abort if crowdfunding was not a success.
      if (balances[from] >= value &&
          allowed[from][msg.sender] >= value &&
          value > 0)
      {
          balances[to] = safeAdd(balances[to], value);
          balances[from] = safeSub(balances[from], value);
          allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], value);
          Transfer(from, to, value);
          return true;
      } else { return false; }
  }

  //  `msg.sender` approves `spender` to spend `value` tokens
  // @param spender The address of the account able to transfer the tokens
  // @param value The amount of wei to be approved for transfer
  // @return Whether the approval was successful or not
  function approve(address spender, uint value) returns (bool ok) {
      if (getState() != State.Success) throw; // Abort if not in Success state.
      allowed[msg.sender][spender] = value;
      Approval(msg.sender, spender, value);
      return true;
  }

  // Set of Crowdfunding Functions :
  // Sale of the tokens. Send ether to invest into HyperInnovation
  // Only when it's in funding mode.
  function buy() public payable {
      // Allow only to invest in funding state
      if (getState() != State.Funding) throw;

      // Sorry !! We do not allow to invest with 0 as value
      if (msg.value == 0) throw;

      // multiply by exchange rate to get newly created token amount
      uint256 createdTokens = safeMul(msg.value, tokensPerEther);

      // Wait we crossed maximum token sale goal. It's successful token sale !!
      if (safeAdd(createdTokens, totalSupply) > tokenSaleMax) throw;

      // Call to Internal function to assign tokens
      assignTokens(msg.sender, createdTokens);
  }

  // Function will transfer the tokens to investor's address
  // Common function code for Early Investor and Crowdsale Investor
  function assignTokens(address investor, uint256 tokens) internal {
      // Creating tokens and  increasing the totalSupply
      totalSupply = safeAdd(totalSupply, tokens);

      // Assign HyperInnovation to the sender
      balances[investor] = safeAdd(balances[investor], tokens);

      // Finally token created for sender, log the creation event
      Transfer(0, investor, tokens);
  }

  // Finalize crowdfunding
  // Finally - Transfer the Ether to owner address
  function finalizeCrowdfunding() external {
      // Abort if not in Funding Success state.
      if (getState() != State.Success) throw; // don't finalize unless we won
      if (finalizedCrowdfunding) throw; // can't finalize twice (so sneaky!)

      // prevent more creation of tokens
      finalizedCrowdfunding = true;

      // Calculate Unsold Tokens
      uint256 unsoldTokens = safeSub(tokenSaleMax, totalSupply);

      // Only transact if there are any unsold tokens
      if(unsoldTokens > 0) {
          totalSupply = safeAdd(totalSupply, unsoldTokens);
          // Remaining unsold tokens assign to owner account
          balances[owner] = safeAdd(balances[owner], unsoldTokens);// Assign Reward Tokens to owner wallet
          Transfer(0, owner, unsoldTokens);
      }
      // Total Supply Should not be greater than 1 Billion
      if (totalSupply > tokenSaleMax) throw;
      // Transfer ETH to the owner address.
      if (!owner.send(this.balance)) throw;
  }

  // Call this function to get the refund of investment done during Crowdsale
  // Refund can be done only when Min Goal has not reached and Crowdsale is over
  function refund() external {
      // Abort if not in Funding Failure state.
      if (getState() != State.Failure) throw;

      uint256 newValue = balances[msg.sender];
      if (newValue == 0) throw;
      balances[msg.sender] = 0;
      totalSupply = safeSub(totalSupply, newValue);

      uint256 ethValue = safeDiv(newValue , tokensPerEther);
      Refund(msg.sender, ethValue);
      if (!msg.sender.send(ethValue)) throw;
  }

  // This will return the current state of Token Sale
  // Read only method so no transaction fees
  function getState() public constant returns (State){
    if (block.number < fundingStartBlock) return State.PreFunding;
    else if (block.number <= fundingEndBlock && totalSupply < tokenSaleMax) return State.Funding;
    else if (totalSupply >= tokenSaleMin) return State.Success;
    else return State.Failure;
  }
  //Accept ether and assign tokens per ether
  function() payable { buy(); }
}
