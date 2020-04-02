pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract DAO {

  using SafeMath for uint;

  struct Proposal {
    mapping (address => bool) endorsers;
    uint endorsementCount;
    bool approvalState;
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

  modifier _isVerifiedUser(address account) { _; }

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
  }

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
