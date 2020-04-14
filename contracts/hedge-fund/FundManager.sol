pragma solidity ^0.6.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import { UniswapV2Library as UniLib } from "./lib/UniswapV2Library.sol";

contract FundManager {
  /* Primary currency used to determine prices for other tokens */
  address public denominator;

  /* Array of supported tokens */
  address[] public tokens;

  /* * @param token0 - sorted first token
   * @param token1 - sorted second token
   * @param reserves0 - uniswap reserves for token0
   * @param reserves1 - uniswap reserves for token1 */
  /**
   * @param pair - uniswap token pair address
   * @param token - main token
   * @param balance - owned tokens
   * @param ownedValue - value of tokens owned by contract
   */
  struct TokenPair {
    IUniswapV2Pair pair;
    IERC20 token;
    uint256 balance;
    uint256 ownedValue;
    uint256 relativeValue;
  }

  struct RelativeValue {
    IERC20 token;
    uint256 percent; /* Relative portion of held assets */
  }

  function _addToken(address token) internal returns (uint256 index) {
    tokens.push(token);
    return tokens.length - 1;
  }

  function getTokenDetails(address token, address _denominator)
  internal view returns (TokenPair memory) {
    (address token0, address token1) = UniLib.sortTokens(token, _denominator);
    IUniswapV2Pair pair = IUniswapV2Pair(UniLib.pairFor(token0, token1));
    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
    uint256 _balance = IERC20(token).balanceOf(address(this));
    uint256 ownedValue;
    if (token == token0) ownedValue = UniLib.quote(_balance, reserve0, reserve1);
    else ownedValue = UniLib.quote(_balance, reserve1, reserve0);
    return TokenPair(pair, IERC20(token), _balance, ownedValue, 0);
  }

  function getTokenHoldings() internal view returns(TokenPair[] memory _pairs) {
    uint256 len = tokens.length;
    address _denominator = denominator;
    _pairs = new TokenPair[](len);
    IERC20[] memory _tokens = new IERC20[](len);
    // uint256[] memory _values = new uint256[](len);
    uint256 totalValue;
    for (uint256 i = 0; i < len; i++) {
      address _token = tokens[i];
      TokenPair memory _pair = getTokenDetails(_token, _denominator);
      _tokens[i] = IERC20(_token);
      _pairs[i] = _pair;
      totalValue += _pair.ownedValue;
    }
    for (uint256 i = 0; i < len; i++) {
      TokenPair memory _pair = _pairs[i];
      _pairs[i].relativeValue = (_pair.ownedValue * 10000) / (totalValue * 100);
    }
  }
}
