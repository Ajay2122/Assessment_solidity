pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //
  // ------------------------------------------ //

  mapping (address => mapping (address => uint256)) private _allowances;

  // List of token holders with non-zero balance, plus a 1-based index
  // into that list so holders can be added/removed in O(1).
  address[] private _holders;
  mapping (address => uint256) private _holderIndex;

  mapping (address => uint256) private _withdrawableDividend;

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value, "Token: transfer amount exceeds allowance");
    _transfer(from, to, value);
    return true;
  }

  function _transfer(address from, address to, uint256 value) private {
    balanceOf[from] = balanceOf[from].sub(value, "Token: transfer amount exceeds balance");
    balanceOf[to] = balanceOf[to].add(value);
    _syncHolder(from);
    _syncHolder(to);
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Token: no ETH sent");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _syncHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _syncHolder(msg.sender);

    (bool success, ) = dest.call{ value: amount }("");
    require(success, "Token: ETH transfer failed");
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) {
      return address(0);
    }
    return _holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Token: no ETH sent");

    uint256 supply = totalSupply;
    uint256 numHolders = _holders.length;
    for (uint256 i = 0; i < numHolders; i += 1) {
      address holder = _holders[i];
      uint256 share = msg.value.mul(balanceOf[holder]).div(supply);
      _withdrawableDividend[holder] = _withdrawableDividend[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _withdrawableDividend[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = _withdrawableDividend[msg.sender];
    _withdrawableDividend[msg.sender] = 0;

    (bool success, ) = dest.call{ value: amount }("");
    require(success, "Token: ETH transfer failed");
  }

  // Keeps the holder list in sync with an account's balance, adding it
  // when its balance becomes non-zero and removing it (via swap-and-pop)
  // when its balance drops to zero, so lookups stay O(1).
  function _syncHolder(address account) private {
    bool hasBalance = balanceOf[account] > 0;
    uint256 index = _holderIndex[account];
    bool isHolder = index != 0;

    if (hasBalance && !isHolder) {
      _holders.push(account);
      _holderIndex[account] = _holders.length;
    } else if (!hasBalance && isHolder) {
      uint256 lastIndex = _holders.length;
      address lastHolder = _holders[lastIndex - 1];

      _holders[index - 1] = lastHolder;
      _holderIndex[lastHolder] = index;

      _holders.pop();
      _holderIndex[account] = 0;
    }
  }
}
