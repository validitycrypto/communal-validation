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
    bool state;
    topic type;
  }

  struct Proposal {
    mapping (address => bool) endorsers;
    bool ballotstate;
    uint endorsements;
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

  modifier _isVotable(string memory _subject) {
    require(ballots[_subject].expirationDate >= block.timestamp);
    require(ballots[_subject].accreditors[msg.sender] == 0x0);
    require(!proposals[_subject].ballotstate);
    require(proposals[_subject].queryState);
    _;
  }

  modifier _isCommitteeMember(address _account, bool _state) {
    if(_state) require(committee[_account].blockNumber != 0);
    else require(committee[_account].blockNumber == 0);
    _;
  }

  modifier _isActiveBallot(bytes _topic) {
    require(ballots[_topic].expirationDate != 0);
    _;
  }

  modifier _isValidProposal(string memory _subject) {
    require(proposals[_subject].ipfsHash.length != 0);
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
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(bytes(_subject))
    _isValidProposal(_subject)
  public {
    require(!proposals[_subject].ballotstate);
    require(!proposals[_subject].queryState);

    uint expiryTimestamp = block.timestamp.add(604800);

    ballots[bytes(_subject)].expirationDate = expiryTimestamp;
    ballots[bytes(_subject)].proposee = msg.sender;
    ballots[bytes(subject)].ipfsHash = _ipfsHash;
    proposals[_subject].queryState = true;
  }

  function committeeBallot(address _individual, bytes _ipfsHash)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(bytes(_individual))
  public {
    uint expiryTimestamp = block.timestamp.add(604800);

    ballots[bytes(_individual)].expirationDate = expiryTimestamp;
    ballots[bytes(_individual)].proposee = msg.sender;
    ballots[bytes(_individual)].ipfsHash = _ipfsHash;

    if(committee[_individual].blockNumber == 0){
      ballots[bytes(_individual)].state = true;
    } else {
      ballots[bytes(_individual)].state = false;
    }
  }

  function metaBallot(bytes _metadata, bytes _ipfsHash)
    _isCommitteeMember(msg.sender, true)
    _isActiveBallot(_metadata)
  public {
    uint expiryTimestamp = block.timestamp.add(604800);

    ballots[_metadata].expirationDate = expiryTimestamp;
    ballots[_metadata].proposee = msg.sender;
    ballots[_metadata].ipfsHash = _ipfsHash;
  }

  function voteApproval(string memory _subject, bool _choice)
    _isCommitteeMember(msg.sender, true)
    _isVotable(_subject)
  public {
    if(_choice) ballots[_subject].positiveCount++;
    else if(!_choice) ballots[_subject].negativeCount++;
    else revert();

    ballots[_subject].accreditors[msg.sender] = _choice;
  }

  function concludeVote(string memory _subject)
    _isCommitteeMember(msg.sender, true)
    _isValidProposal(_subject)
  public {
    require(ballots[_subject].expirationDate < block.timestamp);

    uint confirmations = ballots[_subject].positiveCount;
    uint rejections = ballots[_subject].negativeCount;

    if(confirmations >= rejections) executeProposal(_subject);

    emit Assessment(_subject, confirmations, rejections);
    delete ballots[_subject];
  }

  function executeProposal(string memory _subject)
  private {
    proposals[_subject].ballotstate = true;
    proposals[_subject].queryState = false;
  }

  function createProposal(string memory _subject, bytes memory _ipfsHash)
  public payable {
    require(_ipfsHash.length != 0 && bytes(_subject).length != 0);
    require(proposals[_subject].ipfsHash.length == 0);

    proposals[_subject].bidAmount = msg.value;
    proposals[_subject].ipfsHash = _ipfsHash;

    emit Proposition(_subject, msg.sender, msg.value);
  }

  function fundProposal(string memory _subject)
    _isValidProposal(_subject)
  public payable {
    uint existingBid = proposals[_subject].bidAmount;

    proposals[_subject].bidAmount = existingBid.add(msg.value);

    emit Endowment(_subject, msg.sender, msg.value);
  }

  function endorseProposal(string memory _subject)
    _isVerifiedUser(msg.sender)
    _isValidProposal(_subject)
  public {
    require(!proposals[_subject].endorsers[msg.sender]);

    proposals[_subject].endorsers[msg.sender] = true;
    proposals[_subject].endorsements++;

    emit Endorsement(_subject, msg.sender);
  }

  event Proposition(string subject, address indexed proposee, uint bid);

  event Endowment(string subject, address indexed endowee, uint bid);

  event Assessment(string subject, uint ballots, uint rejections);

  event Endorsement(string subject, address indexed endorsee);
}
