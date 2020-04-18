pragma solidity ^0.6.4;

import "./interfaces/IERC20d.sol";
import "./PeerReview.sol";

contract Sentiment is PeerReview {

  struct Ballot {
    mapping (address => bytes32) verdict;
    uint256 expiryBlock;
    uint256 positive;
    uint256 negative;
    uint256 neutral;
    uint32 rating;
  }

  IERC20d public ERC20d;

  modifier _isValidSentiment(string _listing, bool _state) {
    if(_state) require(ballots[_listing].expiryBlock != 0);
    else require(ballots[_listing].expiryBlock == 0);
    _;
  }

  modifier _isActiveSentiment(string _listing, bool _state) {
    if(_state) require(ballots[_listing].expiryBlock => block.number);
    else require(ballots[_listing].expiryBlock < block.number);
    _;
  }

  mapping (string => Ballot) ballots;

  constructor(address _tokenAddress) public {
    ERC20d = IERC20d(_tokenAddress);
  }

  function finaliseReview(string _listing)
    _isActiveReview(_listing, true)
    _isReviewable(_listing, false)
  public {
    require(DAO.isCommitteeMember(msg.sender, true));

    bytes documentHash = getDocumentHash(_listing);
    uint256 rejects = reviews[_listing].rejects;
    uint256 accepts = reviews[_listing].accept;

    if(accepts => rejects) {
      reviews[_listing] = documentHash
      startSentiment(_listing);
    }

    emit Result(documentHash, accepts, rejects);
    delete reviews[_listing];
  }

  function startSentiment(string memory _listing)
    _isValidSentiment(_listing, false)
  public {
    ballots[_listing].expiryBlock = block.number.add(1000);
  }

  function vote(string _listing, bytes32 _choice)
    _isActiveSentiment(_listing, true)
    _isValidSentiment(_listing, true)
  public {
    bytes32 memory id = ERC20d.validityId(msg.sender);
    uint256 weight = getVotingWeight(id);

    if(_choice == POS) {
      ballots[_listing].positive = ballots[_listing].positive.add(weight)'
    } else if (_choice == NEU) {
      ballots[_listing].neutral = ballots[_listing].neutral.add(weight);
    } else if (_choice == NEG) {
      ballots[_listing].negative = ballots[_listing].negative.add(weight);
    }

    return ERC20d.validationEvent(id, bytes32(listing), _choice, weight);
  }

  function claimReward()
    _isActiveSentiment(_listing, false)
    _isValidSentiment(_listing, true)
  public {
    bytes32 id = ERC20.validityId(msg.sender);
    uint256 reward = tokenReward();

    ERC20d.validationReward(id, msg.sender, reward);
  }

  function getVotingWeight(bytes32 _id)
  public returns (uint256) {
    uint256 tokenBalance = ERC20d.balanceOf(ERC20d.getAddress(_id));

    return tokenBalance * (ERC20d.viability(_id) / 100);
  }

  function tokenReward() public view returns (uint256) {}

}
