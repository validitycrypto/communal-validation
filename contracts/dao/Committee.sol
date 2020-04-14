pragma solidity ^0.6.4;

contract Committee {

  struct Member {
    uint256 blockNumber;
    uint256 roleIndex;
    uint256 reputation;
  }

  mapping (address => Member) public committee;

  address[] public committeeMembers;

  constructor() public {
    committee[msg.sender].reputation = 99; // Founders Shares
    addCommitteeMember(msg.sender);
  }

  function isCommitteeMember(address _account, bool _state)
  public returns (bool) {
    if(_state) return committee[_account].blockNumber != 0;
    else return committee[_account].blockNumber == 0;
  }

  function addCommitteeMember(address _individual)
  private {
    require(isCommitteeMember(_individual, false));

    committee[_individual].roleIndex = committeeMembers.length;
    committee[_individual].blockNumber = block.number;
    committee[_individual].reputation++;
    committeeMembers.push(_individual);
  }

  function removeCommitteeMember(address _individual)
  private {
    require(isCommitteeMember(_individual, true));

    uint256 replacementIndex = committee[_individual].roleIndex;
    uint256 lastIndex = committeeMembers.length-1;

    committeeMembers[replacementIndex] = committeeMembers[lastIndex];
    delete committee[_individual];
    committeeMembers.pop();
  }

}
