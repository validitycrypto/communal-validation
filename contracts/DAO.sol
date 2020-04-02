pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract DAO {

  using SafeMath for uint;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x4e65757472616c00000000000000000000000000000000000000000000000000;

  struct Approval {
    mapping (address => bytes32) accreditors;
    address[] participants;
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

  modifier _isCommitteeMember(address account, bool state) {
    if(state) require(committee[account].blockNumber != 0);
    else require(committee[account].blockNumber == 0);
    _;
  }

  modifier _isValidProposal(string memory subject) {
    require(proposals[subject].ipfsHash.length != 0);
    require(proposals[subject].endorsementCount != 0);
    _;
  }

  modifier _canVote(string memory subject) {
    require(approvals[subject].accreditors[msg.sender] == bytes(0x0));
    require(approvals[subject].expirationDate >= block.timestamp);
    require(!proposals[subject].approvalState);
    require(proposals[subject].queryState);
    _;
  }

  modifier _isVerifiedUser(address account) { _; }

  function getQuorum() public view returns (uint) {
    if(members.length % 2 == 0) return members.length.div(2);
    else return members.length.sub(1).div(2);
  }

  function addCommitteeMember(address individual)
    _isCommitteeMember(individual, false)
  private {
    committee[individual].blockNumber = block.number;
    members.push(individual);
  }

  function proposeApproval(string memory subject)
    _isCommitteeMember(msg.sender, true)
  public {
    require(!proposals[subject].approvalState);
    require(!proposals[subject].queryState);

    uint expiryTimestamp = block.timestamp + 604800;

    approvals[subject].expirationDate = expiryTimestamp;
    approvals[subject].proposee = msg.sender;
    proposals[subject].queryState = true;
  }

  function voteApproval(string memory _subject, bytes32 _choice)
    _isCommitteeMember(msg.sender, true) _canVote(subject)
  public {
    require(_choice == NEG || _choice == POS);

    approvals[subject].accreditors[msg.sender] = _choice;
    approvals[subject].participants.push(msg.sender);
  }

  function concludeApproval(string memory _subject)
    _isCommitteeMember(msg.sender)
  public {
    require(approvals[subject].expirationDate < block.timestamp);

    for(var x = 0 ; x < approvals[subject].participants ; x++) {
      var focusPoint = approvals[subject].participants[x];
      var decision = approvals[subject].accreditors[focusPoint];

      if(decision == POS) approvals[subject].positiveCount++;
      else if(decision == NEG) approvals[subject].negativeCount++;
    }

    var confirmations = approvals[subject].positiveCount;
    var rejections = approvals[subject].negativeCount;

    if(approvals => rejections) executeProposal(subject)

    emit Approval(subject, confirmations, rejections);
    delete approvals[subject];
  }

  function executeProposal(string memory subject) { }

  function createProposal(string memory subject, bytes memory ipfsHash)
  public payable {
    require(ipfsHash.length != 0 && bytes(subject).length != 0);
    require(proposals[subject].ipfsHash.length == 0);

    proposals[subject].bidAmount = msg.value;
    proposals[subject].ipfsHash = ipfsHash;
  }

  function fundProposal(string memory subject)
    _isValidProposal(subject)
  public payable {
    uint existingBid = proposals[subject].bidAmount;

    proposals[subject].bidAmount = existingBid.add(msg.value);
  }

  function endorseProposal(string memory subject)
    _isValidProposal(subject) _isVerifiedUser(msg.sender)
  public {
    require(!proposals[subject].endorsers[msg.sender]);

    proposals[subject].endorsers[msg.sender] = true;
    proposals[subject].endorsementCount++;
  }

}
