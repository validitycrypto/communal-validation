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

    ballots[_listing].verdict[msg.sender] = _choice;

    if(_choice == POS) {
      ballots[_listing].positive = ballots[_listing].positive.add(weight)'
    } else if (_choice == NEU) {
      ballots[_listing].neutral = ballots[_listing].neutral.add(weight);
    } else if (_choice == NEG) {
      ballots[_listing].negative = ballots[_listing].negative.add(weight);
    }

    return ERC20d.validationEvent(id, bytes32(listing), _choice, weight);
  }

  function finaliseRating(string _listing)
    _isActiveSentiment(_listing, false)
    _isValidSentiment(_listing, true)
  public {
    uint32 sentimentRating = quantifyRating(_listing);
    uint32 reportRating = reviews[_listing].rating;

    rateListing(reportRating.add(sentimentRating) / 2);
  }

  function claimReward(string _listing)
    _isActiveSentiment(_listing, false)
    _isValidSentiment(_listing, true)
  public {
    require(ballots[_listing].verdict[msg.sender] != 0x0);

    bytes32 id = ERC20.validityId(msg.sender);

    ERC20d.validationReward(id, msg.sender, tokenReward());
  }

  function getVotingWeight(bytes32 _id)
  public returns (uint256) {
    uint256 tokenBalance = ERC20d.balanceOf(ERC20d.getAddress(_id));

    return tokenBalance * (ERC20d.viability(_id) / 100);
  }

  function quantifyRating(string _listing)
  public view returns (uint32) {
    uint256 positive = ballots[_listing].positive;
    uint256 neutral = ballots[_listing].neutral;
    uint256 negative = ballots[_listing].negative;
    uint256 total = positive.add(negative).add(neutral);

    return ((positive / total) * 100)
    .add((neutral / total) * 100).add((negative / total) * 100) / 3
  }

  function tokenReward() public view returns (uint256) {}

}
