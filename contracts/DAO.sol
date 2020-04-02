pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract DAO {

  using SafeMath for uint;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  struct Approval {
    mapping (address => bytes32) accreditors;
    uint expirationDate;
    uint negativeCount;
    uint positiveCount;
    address proposee;
  }

  struct Proposal {
    mapping (address => bool) endorsers;
    bool approvalState;
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
  mapping (string => Approval) public approvals;
  mapping (address => Member) public committee;

  address[] public members;

  constructor() public {
    addCommitteeMember(msg.sender);
  }

  modifier _isVotable(string memory _subject) {
    require(approvals[_subject].expirationDate >= block.timestamp);
    require(approvals[_subject].accreditors[msg.sender] == 0x0);
    require(!proposals[_subject].approvalState);
    require(proposals[_subject].queryState);
    _;
  }

  modifier _isCommitteeMember(address _account, bool _state) {
    if(_state) require(committee[_account].blockNumber != 0);
    else require(committee[_account].blockNumber == 0);
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

  function proposeApproval(string memory _subject)
    _isCommitteeMember(msg.sender, true) _isValidProposal(_subject)
  public {
    require(!proposals[_subject].approvalState);
    require(!proposals[_subject].queryState);

    uint expiryTimestamp = block.timestamp + 604800;

    approvals[_subject].expirationDate = expiryTimestamp;
    approvals[_subject].proposee = msg.sender;
    proposals[_subject].queryState = true;
  }

  function voteApproval(string memory _subject, bytes32 _choice)
    _isCommitteeMember(msg.sender, true) _isVotable(_subject)
  public {
    if(_choice == POS) approvals[_subject].positiveCount++;
    else if(_choice == NEG) approvals[_subject].negativeCount++;
    else revert();

    approvals[_subject].accreditors[msg.sender] = _choice;
  }

  function concludeApproval(string memory _subject)
    _isCommitteeMember(msg.sender, true) _isValidProposal(_subject)
  public {
    require(approvals[_subject].expirationDate < block.timestamp);

    uint confirmations = approvals[_subject].positiveCount;
    uint rejections = approvals[_subject].negativeCount;

    if(confirmations >= rejections) executeProposal(_subject);

    emit Assessment(_subject, confirmations, rejections);
    delete approvals[_subject];
  }

  function executeProposal(string memory _subject) private {
    proposals[_subject].approvalState = true;
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
    _isValidProposal(_subject) _isVerifiedUser(msg.sender)
  public {
    require(!proposals[_subject].endorsers[msg.sender]);

    proposals[_subject].endorsers[msg.sender] = true;
    proposals[_subject].endorsements++;

    emit Endorsement(_subject, msg.sender);
  }

  event Proposition(string subject, address indexed proposee, uint bid);

  event Endowment(string subject, address indexed endowee, uint bid);

  event Assessment(string subject, uint approvals, uint rejections);

  event Endorsement(string subject, address indexed endorsee);
}
