pragma solidity ^0.6.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract DAO {

  using SafeMath for uint256;
  using SafeMath for uint16;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  enum topic { committee, listing, action }

  struct Ballot {
    mapping (address => bytes32) verdict;
    uint256 expiryBlock;
    uint16 negative;
    uint16 positive;
  }

  struct Listing {
    mapping (address => bool) endorsers;
    uint16 endorsements;
    uint256 bid;
    bool ballot;
    bool status;
  }

  struct Proposal {
    bytes32 ipfsHash;
    address proposee;
    address target;
    topic variety;
    bool action;
  }

  struct Member {
    uint256 blockNumber;
    uint32 reputation;
    uint16 operations;
    uint16 ballots;
  }

  mapping (address => Member) public committee;

  mapping (string => Listing) public listings;

  mapping (bytes => Proposal) public proposals;

  mapping (bytes => Ballot) public ballots;

  address[] public committeeMembers;

  constructor() public {
    addCommitteeMember(msg.sender);
  }

  modifier _isVotable(bytes memory _proposalId, bool _state) {
    if(_state) {
      require(ballots[_proposalId].expiryBlock >= block.number);
      require(ballots[_proposalId].verdict[msg.sender] == 0x0);
    } else {
      require(ballots[_proposalId].expiryBlock < block.number);
    } _;
  }

  modifier _isActiveListing(string memory _subject, bool _state) {
    if(_state) {
      require(listings[_subject].ballot && !listings[_subject].status);
    } else {
      require(!listings[_subject].ballot && !listings[_subject].status);
    } _;
  }

  modifier _isActiveBallot(bytes memory _proposalId, bool _state) {
    if(_state) require(ballots[_proposalId].expiryBlock != 0);
    else require(ballots[_proposalId].expiryBlock == 0);
    _;
  }

  modifier _isCommitteeMember(address _account, bool _state) {
    if(_state) require(committee[_account].blockNumber != 0);
    else require(committee[_account].blockNumber == 0);
    _;
  }

  modifier _isValidProposal(bytes memory _proposalId, bool _state) {
    if(_state) require(proposals[_proposalId].ipfsHash.length != 0);
    else require(proposals[_proposalId].ipfsHash.length == 0);
    _;
  }

  modifier _isValidListing(string memory _subject, bool _state) {
    if(_state) require(listings[_subject].endorsements != 0);
    else require(listings[_subject].endorsements == 0);
    _;
  }

  modifier _isVerifiedUser(address _account) { _; }

  function getQuorum() public view returns (uint) {
    uint256 committeeCount = committeeMembers.length;

    if(committeeCount % 2 == 0) return committeeCount.div(2);
    else return committeeCount.sub(1).div(2);
  }

  function addCommitteeMember(address _individual)
    _isCommitteeMember(_individual, false)
  private {
    committee[_individual].blockNumber = block.number;
    committeeMembers.push(_individual);
  }

  function checkProposal(bytes memory _proposalId)
    _isValidProposal(_proposalId, false)
  private returns (bool) { return true; }

  function createProposal(Proposal memory _proposal, string memory _listing)
    _isCommitteeMember(msg.sender, true)
  public {
    bytes memory proposalId = abi.encode(_proposal);

    if(_proposal.variety == topic.listing) proposalId = abi.encode(_listing);

    require(checkProposal(proposalId));

    proposals[proposalId] = _proposal;
    proposals[proposalId].proposee = msg.sender;

    return createBallot(proposalId);
  }

  function createBallot(bytes memory _proposalId)
    _isValidProposal(_proposalId, false)
    _isActiveBallot(_proposalId, false)
    _isVotable(_proposalId, false)
  private {
    topic ballotType = proposals[_proposalId].variety;

    if(ballotType == topic.committee) checkCommittee(_proposalId);
    else if(ballotType == topic.listing) pushListing(_proposalId);

    ballots[_proposalId].expiryBlock = block.number.add(1000);

    emit Poll(_proposalId, msg.sender, ballotType);
  }

  function pushListing(bytes memory _subject)
    _isActiveListing(string(_subject), false)
    _isValidListing(string(_subject), true)
  private {
    listings[string(_subject)].ballot = true;
  }

  function checkCommittee(bytes memory _proposalId)
  public {
    address _subject = proposals[_proposalId].target;
    uint256 memberState = committee[_subject].blockNumber;

    if(memberState == 0) proposals[_proposalId].action = true;
    else proposals[_proposalId].action = false;
  }

  function vote(bytes memory _proposalId, bytes32 _choice, bool _listing)
    _isActiveListing(string(_proposalId), _listing)
    _isCommitteeMember(msg.sender, true)
    _isValidProposal(_proposalId, true)
    _isActiveBallot(_proposalId, true)
    _isVotable(_proposalId, true)
  public {
    ballots[_proposalId].verdict[msg.sender] = _choice;

    if(_choice == POS) ballots[_proposalId].positive++;
    else if(_choice == NEG) ballots[_proposalId].negative++;
    else revert();

    emit Vote(_proposalId, msg.sender, _choice);
 }

  function concludeVote(bytes memory _proposalId)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(_proposalId, true)
    _isVotable(_proposalId, false)
  public {
    uint16 approvals = ballots[_proposalId].positive;
    uint16 rejections = ballots[_proposalId].negative;

    require(getQuorum() <= approvals.add(rejections));

    if(approvals >= rejections) execute(_proposalId);

    emit Outcome(_proposalId, approvals, rejections);
    delete ballots[_proposalId];
  }

  function execute(bytes memory _proposalId) private {}

  function createListing(string memory _subject)
    _isActiveListing(_subject, false)
    _isValidListing(_subject, false)
  public payable {
    require(bytes(_subject).length != 0);

    listings[_subject].endorsers[msg.sender] = true;
    listings[_subject].bid = msg.value;
    listings[_subject].endorsements++;

    emit List(_subject, msg.sender, msg.value);
  }

  function fundListing(string memory _subject)
    _isValidListing(_subject, true)
  public payable {
    uint256 existingBid = listings[_subject].bid;

    listings[_subject].bid = existingBid.add(msg.value);

    emit Endowment(_subject, msg.sender, msg.value);
  }

  function endorseListing(string memory _subject)
    _isValidListing(_subject, true)
    _isVerifiedUser(msg.sender)
  public {
    require(!listings[_subject].endorsers[msg.sender]);

    listings[_subject].endorsers[msg.sender] = true;
    listings[_subject].endorsements++;

    emit Endorsement(_subject, msg.sender);
  }

  event Endowment(string subject, address indexed endowee, uint256 bid);

  event Poll(bytes subject, address indexed proposee, topic variant);

  event Vote(bytes subject, address indexed member, bytes32 option);

  event List(string subject, address indexed proposee, uint256 bid);

  event Outcome(bytes subject, uint16 approvals, uint16 rejections);

  event Endorsement(string subject, address indexed endorsee);

}
