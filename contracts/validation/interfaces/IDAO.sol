pragma solidity ^0.6.4;

interface IDAO {

  function getTargetAddress(bytes _proposalId) public view returns (address) { }

  function getProposalState(bytes _proposalId) public view returns (bytes32) { }

  function isCommitteeMember(address _account) public view returns (bool) { }

}
