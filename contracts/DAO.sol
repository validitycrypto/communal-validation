pragma solidity ^0.6.4;

contract DAO {

  struct Member {
    uint blockNumber;
    uint proposalCount;
    uint reportCount;
    uint qualityRep;
  }

  struct Proposal {
    mapping (address => bool) endorsers;
    unit endorsementCount;
    bool approvalState;
    bytes32 ipfsHash;
    uint bidAmount;
  }

  mapping (address => Proposal) public proposals;
  mapping (address => Member) public committee;

  address[] public members;

  constructor() addCommitteeMember(msg.sender) public { }

  modifier _isCommitteeMember(address acc, bool state) {
    if(state) require(committee[acc].blockNumber != 0)
    else require(committee[acc].blockNumber == 0)
    _;
  }

  modifier _isValidProposal(string subject) {
    require(proposal[subject].ipfsHash != bytes32(0x0));
    require(proposal[subject].endorsementCount != 0);
    _;
  }

  modifier _isVerifiedUser(address subject) { }

  function addCommitteeMember(address individual)
    _isCommitteeMember(individual, false)
  private {
    committee[individual].blockNumber = block.number
    members.push(individual)
  }

  function createProposal(string subject, bytes32 ipfsHash)
  public payable {
    require(ipfsHash != bytes(0x0) && subject.length != 0)
    require(proposal[subject].ipfsHash == bytes32(0x0))

    proposal[subject].bidAmount = msg.value;
    proposal[subject].ipfsHash = ipfsHash;
  }

  function fundProposal(string subject)
    _isValidProposal(subject)
  public payable {
    require(msg.value > 1 wei);

    uint existingBid = proposal[subject].bidAmount;
    proposal[subject].bidAmount = existingBid.add(msg.value);
  }

  function endorseProposal(string subject)
    _isValidProposal(subject) _isVerifiedUser(msg.sender)
  public {
    require(!proposal[subject].endorsers[msg.sender])
    
    proposal[subject].endorsers[msg.sender] = true;
    proposal[subject].endorsementCount++;
  }

}
