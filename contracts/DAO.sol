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
    address subject;
    bytes ipfsHash;
    bytes metadata;
    uint negative;
    uint positive;
    topic type;
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
  mapping (bytes => Ballot) public _ballots;

  address[] public members;

  constructor() public {
    addCommitteeMember(msg.sender);
  }

  modifier _isVotable(bytes _subject, bool _state) {
    if(_state) {
      require(ballots[_subject].expirationDate >= block.timestamp);
      require(ballots[_subject].accreditors[msg.sender] == 0x0);
    } else {
      require(ballots[_subject].expirationDate < block.timestamp);
    }
    _;
  }

  modifier _isActiveProposal(string memory _subject, bool _state) {
    if(_state) {
      require(proposals[_subject].ballotState);
      require(!proposals[_subject].queryState);
    } else {
      require(!proposals[_subject].ballotState);
      require(!proposals[_subject].queryState);
    }
  }

  modifier _isActiveBallot(bytes _subject, bool _state){
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
    else require(proposals[_subject].ipfsHash.length == 0)
    _;
  }

  modifier _isVerifiedUser(address _account) { _; }

  function getQuorum() public view returns (uint) {
    if(members.length % 2 == 0) return members.length.div(2);
    else return members.length.sub(1).div(2);
  }

  function addCommitteeMember(address _individual)
    _isCommitteeMember(_individual, false)
  private {
    committee[_individual].blockNumber = block.number;
    members.push(_individual);
  }

  function proposalBallot(string _subject, bytes _ipfsHash)
    _isActiveBallot(bytes(_subject), false)
    _isCommitteeMember(msg.sender, true)
    _isVotable(bytes(_subject), false)
    _isActiveProposal(_subject, false)
    _isValidProposal(_subject, true)
  public {
    uint expiryTimestamp = block.timestamp.add(604800);

    ballots[bytes(_subject)].expirationDate = expiryTimestamp;
    ballots[bytes(_subject)].proposee = msg.sender;
    ballots[bytes(subject)].ipfsHash = _ipfsHash;
    proposals[_subject].queryState = true;

    emit Poll(bytes(_individual), msg.sender, topic.proposal);
  }

  function committeeBallot(address _individual, bytes _ipfsHash)
    _isActiveBallot(bytes(_individual), false)
    _isVotable(bytes(_individual), false)
    _isCommitteeMember(msg.sender, true)
  public {
    uint memberState = committee[_individual].blockNumber;
    uint expiryTimestamp = block.timestamp.add(604800);

    if(memberState == 0) ballots[bytes(_individual)].act = true;
    else ballots[bytes(_individual)].act = false;

    ballots[bytes(_individual)].expirationDate = expiryTimestamp;
    ballots[bytes(_individual)].proposee = msg.sender;
    ballots[bytes(_individual)].ipfsHash = _ipfsHash;

    emit Poll(bytes(_individual), msg.sender, topic.committee);
  }

  function metaBallot(bytes _metadata, bytes _ipfsHash)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(_metadata, false)
    _isVotable(_metadata, false)
  public {
    uint expiryTimestamp = block.timestamp.add(604800);

    ballots[_metadata].expirationDate = expiryTimestamp;
    ballots[_metadata].proposee = msg.sender;
    ballots[_metadata].ipfsHash = _ipfsHash;

    emit Poll(_metadata, msg.sender, topic.action);
  }

  function vote(bytes _subject, bool _choice, bool _proposal)
    _isActiveProposal(string(subject), _proposal)
    _isValidProposal(string(subject), _proposal)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(_subject, true)
    _isVotable(_subject, true)
  public {
    ballots[_subject].accreditors[msg.sender] = _choice;

    if(_choice) ballots[_subject].positive++;
    else ballots[_subject].negative++;

    emit Vote(_subject, msg.sender, _choice);
 }

  function concludeVote(bytes _subject, bool _proposal)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(_subject, true)
    _isVotable(_subject, false)
  public {
    uint approvals = ballots[_subject].positive;
    uint rejections = ballots[_subject].negative;

    require(getQuorum() <= approvals.add(rejections));

    if(approvals >= rejections) {
      if(_proposal) executeProposal(_subject);
      else executeBallot(_subject);
    }

    emit Outcome(_subject, approvals, rejections);
    delete ballots[_subject];
  }

  function executeProposal(bytes _subject)
    _isActiveProposal(string(subject), true)
    _isValidProposal(string(subject), true)
  private {
    proposals[string(_subject)].ballotstate = true;
    proposals[string(_subject)].queryState = false;
  }

  function executeBallot(bytes _subject)
  private { }

  function createProposal(string memory _subject, bytes memory _ipfsHash)
    _isActiveProposal(subject, false)
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

  event Poll(string subject, address indexed proposee, topic type);

  event Vote(string subject, address indexed member, bool choice);

  event Outcome(string subject, uint approvals, uint rejections);

  event Endorsement(string subject, address indexed endorsee);

}
