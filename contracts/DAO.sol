pragma solidity ^0.6.4;

contract DAO {

  struct Member {
    uint blockNumber;
    uint proposalCount;
    uint reportCount;
    uint qualityRep;
  }

  mapping (address => Member) public committee;

  address[] public members;

  constructor() addCommitteeMember(msg.sender) public { }

  modifier _isCommitteeMember(address acc, bool state){
    if(state) require(committee[acc].blockNumber != 0)
    else require(committee[acc].blockNumber == 0)
    _;
  }

  function addCommitteeMember(address individual)
    _isCommitteeMember(individual, false) private {
    committee[individual].blockNumber = block.number
    members.push(individual)
  }

}
