pragma solidity ^0.6.4;

interface IERC20d {

  function validationEvent(bytes32 _id, bytes32 _subject, bytes32 _choice, uint256 _weight) public { }

  function validationReward(bytes32 _id, address _account, uint256 _reward) public { }

  function validityId(address _account) public view returns (bytes32) {}

  function balanceOf(address _account) public view returns (uint256) {}

  function getAddress(bytes _id) public view returns (address) {}

  function toggleStake() public {}

}
