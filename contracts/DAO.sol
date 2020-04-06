pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract DAO {

  using SafeMath for uint;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  enum topic { committee, proposal, action }

  struct Ballot {
    mapping (address => bytes32) verdict;
    uint expirationDate;
    address proposee;
    address target;
    bytes ipfsHash;
    uint negative;
    uint positive;
    topic variety;
    bool act;
  }

  struct Proposal {
    mapping (address => bool) endorsers;
    uint endorsements;
    bool ballotState;
    bool queryState;
    bytes ipfsHash;
    uint bidAmount;
  }

  struct Member {
    uint blockNumber;
    uint proposalCount;
    uint reportCount;
    uint qualityRep;
  }

  mapping (string => Proposal) public proposals;
  mapping (address => Member) public committee;
  mapping (bytes => Ballot) public ballots;

  address[] public committeeMembers;

  constructor() public {
    addCommitteeMember(msg.sender);
  }

  modifier _isVotable(bytes memory _subject, bool _state) {
    if(_state) {
      require(ballots[_subject].expirationDate >= block.timestamp);
      require(ballots[_subject].verdict[msg.sender] == 0x0);
    } else {
      require(ballots[_subject].expirationDate < block.timestamp);
    } _;
  }

  modifier _isActiveProposal(string memory _subject, bool _state) {
    if(_state) {
      require(proposals[_subject].ballotState);
      require(!proposals[_subject].queryState);
    } else {
      require(!proposals[_subject].ballotState);
      require(!proposals[_subject].queryState);
    } _;
  }

  modifier _isActiveBallot(bytes memory _subject, bool _state){
    if(_state) require(ballots[_subject].proposee != address(0x0));
    else require(ballots[_subject].proposee == address(0x0));
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

  function proposalBallot(string memory _subject, bytes memory _ipfsHash)
    _isActiveBallot(bytes(_subject), false)
    _isCommitteeMember(msg.sender, true)
    _isVotable(bytes(_subject), false)
    _isActiveProposal(_subject, false)
    _isValidProposal(_subject, true)
  public {
    uint expiryTimestamp = block.timestamp.add(604800);

    ballots[bytes(_subject)].expirationDate = expiryTimestamp;
    ballots[bytes(_subject)].variety = topic.proposal;
    ballots[bytes(_subject)].proposee = msg.sender;
    ballots[bytes(_subject)].ipfsHash = _ipfsHash;
    proposals[_subject].ballotState = true;

    emit Poll(bytes(_subject), msg.sender, topic.proposal);
  }

  function committeeBallot(address _individual, bytes memory _ipfsHash)
    _isActiveBallot(abi.encodePacked(_individual), false)
    _isVotable(abi.encodePacked(_individual), false)
    _isCommitteeMember(msg.sender, true)
  public {
    bytes memory _delegate = abi.encodePacked(_individual);
    uint memberState = committee[_individual].blockNumber;
    uint expiryTimestamp = block.timestamp.add(604800);

    if(memberState == 0) ballots[_delegate].act = true;
    else ballots[_delegate].act = false;

    ballots[_delegate].expirationDate = expiryTimestamp;
    ballots[_delegate].variety = topic.committee;
    ballots[_delegate].proposee = msg.sender;
    ballots[_delegate].target = _individual;
    ballots[_delegate].ipfsHash = _ipfsHash;

    emit Poll(_delegate, msg.sender, topic.committee);
  }

  function metaBallot(address _contract, bytes memory _metadata, bytes memory _ipfsHash)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(_metadata, false)
    _isVotable(_metadata, false)
  public {
    uint expiryTimestamp = block.timestamp.add(604800);

    ballots[_metadata].expirationDate = expiryTimestamp;
    ballots[_metadata].variety = topic.action;
    ballots[_metadata].proposee = msg.sender;
    ballots[_metadata].ipfsHash = _ipfsHash;
    ballots[_metadata].target = _contract;

    emit Poll(_metadata, msg.sender, topic.action);
  }

  function vote(bytes memory _subject, bytes32 _choice, bool _proposal)
    _isActiveProposal(string(_subject), _proposal)
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
    _isActiveProposal(string(_subject), true)
    _isValidProposal(string(_subject), true)
  private {
    proposals[string(_subject)].ballotState = false;
    proposals[string(_subject)].queryState = true;
  }

  function executeBallot(bytes memory _subject)
  private { }

  function createProposal(string memory _subject, bytes memory _ipfsHash)
    _isActiveProposal(_subject, false)
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
