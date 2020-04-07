pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract DAO {

  using SafeMath for uint;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  enum subject { committee, listing, action }

  struct Ballot {
    mapping (address => bytes32) verdict;
    uint32 expiryBlock;
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
    uint32 blockNumber;
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

  modifier _isVotable(bytes memory _subject, bool _state) {
    if(_state) {
      require(ballots[_subject].expiryBlock >= block.number);
      require(ballots[_subject].verdict[msg.sender] == 0x0);
    } else {
      require(ballots[_subject].expiryBlock < block.number);
    } _;
  }

  modifier _isActiveListing(string memory _subject, bool _state) {
    if(_state) {
      require(listings[_subject].ballot && !listings[_subject].status);
    } else {
      require(!listings[_subject].ballot && !proposals[_subject].status);
    } _;
  }

  modifier _isActiveBallot(bytes memory _subject, bool _state) {
    if(_state) require(ballots[_subject].id.length != 0);
    else require(ballots[_subject].id.length == 0);
    _;
  }

  modifier _isCommitteeMember(address _account, bool _state) {
    if(_state) require(committee[_account].blockNumber != 0);
    else require(committee[_account].blockNumber == 0);
    _;
  }

  modifier _isValidProposal(string memory _subject, bool _state) {
    if(_state) require(proposals[_subject].ipfsHash.length != 0);
    else require(proposals[_subject].ipfsHash.length == 0);
    _;
  }

  modifier _isVerifiedUser(address _account) { _; }

  function getQuorum() public view returns (uint) {
    uint committeeCount = committeeMembers.length;

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
  private returns (true) { }

  function createProposal(string memory _subject, Proposal memory _proposal)
    _isCommitteeMember(msg.sender, true)
  public {
    bytes memory proposalId = abi.encodePacked(_proposal);

    if(_proposal.variety == topic.listing) proposalId = abi.encodePacked(_subject);

    require(checkProposal(proposalId));

    proposals[proposalId] = _proposal
    proposals[proposalId].proposee = msg.sender;

    createBallot(proposalId);
  }

  function createBallot(bytes memory _proposalId)
    _isActiveBallot(_proposalId, false)
    _isValidProposal(_subject, true)
    _isVotable(_proposalId, false)
  private {
    topic storage ballotType = proposals[_proposalId].variety;

    if(ballotType == topic.committee) checkCommittee(_proposalId);
    else if(ballotType == topic.listing) pushListing(_proposalId);

    ballots[_proposalId].expiryBlock = block.number.add(1000);

    emit Poll(_proposalId, msg.sender, ballotType);
  }

  function pushListing(bytes memory _subject)
    _isActiveListing(string(_subject), false)
    _isValidListing(string(_subject), true)
  private {
    proposals[_subject].ballot = true;
  }

  function checkCommittee(bytes memory _proposalId)
  public {
    address _subject = proposals[_proposalId].target;
    uint memberState = committee[_subject].blockNumber;

    if(memberState == 0) proposals[_subject].action = true;
    else proposals[_subject].action = false;
  }

  function vote(bytes memory _subject, bytes32 _choice, bool _proposal)
    _isActiveListing(string(_subject), _proposal)
    _isValidProposal(string(_subject), _proposal)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(_subject, true)
    _isVotable(_subject, true)
  public {
    ballots[_subject].verdict[msg.sender] = _choice;

    if(_choice == POS) ballots[_subject].positive++;
    else if(_choice == NEG) ballots[_subject].negative++;
    else revert();

    emit Vote(_subject, msg.sender, _choice);
 }

  function concludeVote(bytes memory _subject)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(_subject, true)
    _isVotable(_subject, false)
  public {
    uint approvals = ballots[_subject].positive;
    uint rejections = ballots[_subject].negative;

    require(getQuorum() <= approvals.add(rejections));

    if(approvals >= rejections) execute(_subject);

    emit Outcome(_subject, approvals, rejections);
    delete ballots[_subject];
  }

  function execute(bytes memory _subject) private {
    if(ballots[_subject].variety == topic.proposal) executeProposal(_subject);
    else if(ballots[_subject].variety == topic.committee) executeBallot(_subject);
    else if(ballots[_subject].variety == topic.action) executeMeta(_subject);
  }

  function executeMeta(bytes memory _subject) private { }

  function executeProposal(bytes memory _subject)
    _isActiveListing(string(_subject), true)
    _isValidProposal(string(_subject), true)
  private {
    proposals[string(_subject)].ballotState = false;
    proposals[string(_subject)].queryState = true;
  }

  function executeBallot(bytes memory _subject)
  private { }

  function createListing(string memory _subject)
    _isActiveListing(_subject, false)
    _isValidProposal(_subject, false)
  public payable {
    require(_ipfsHash.length != 0 && bytes(_subject).length != 0);

    proposals[_subject].bidAmount = msg.value;
    proposals[_subject].ipfsHash = _ipfsHash;

    emit Proposition(_subject, msg.sender, msg.value);
  }

  function fundProposal(string memory _subject)
    _isValidProposal(_subject, true)
  public payable {
    uint existingBid = proposals[_subject].bidAmount;

    proposals[_subject].bidAmount = existingBid.add(msg.value);

    emit Endowment(_subject, msg.sender, msg.value);
  }

  function endorseProposal(string memory _subject)
    _isValidProposal(_subject, true)
    _isVerifiedUser(msg.sender)
  public {
    require(!proposals[_subject].endorsers[msg.sender]);

    proposals[_subject].endorsers[msg.sender] = true;
    proposals[_subject].endorsements++;

    emit Endorsement(_subject, msg.sender);
  }

  event Proposition(string subject, address indexed proposee, uint bid);

  event Endowment(string subject, address indexed endowee, uint bid);

  event Poll(bytes subject, address indexed proposee, topic variant);

  event Vote(bytes subject, address indexed member, bytes32 option);

  event Outcome(bytes subject, uint approvals, uint rejections);

  event Endorsement(string subject, address indexed endorsee);

}
