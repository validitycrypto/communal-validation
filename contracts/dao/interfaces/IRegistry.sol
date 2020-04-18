pragma solidity ^0.6.4;

interface IRegistry {

  function submitProposal(bytes _proposalId) public {}
  
  function pushListing(bytes _proposalId) public {}

}
