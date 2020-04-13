pragma solidity ^0.6.4;

contract Validation {

  enum role { engineer, designer, analyst, lawyer, executive }

  struct Reviewer {
    uint256 reviews;
    string title;
    role forte;
  }

  mapping (address => Reviewer) public reviewers;

  function isPeerReviewer(address _account)
  public view returns (bool) {
    return bytes(reviewers[_account].title).length != 0;
  }

}
