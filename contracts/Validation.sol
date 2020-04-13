pragma solidity ^0.6.4;

import './interfaces/IDAO.sol';

contract Validation {

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x4e65757472616c00000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  mapping (address => bytes32) public reviewers;
  mapping (string => bytes) public reviews;

  constructor() public { }

  modifier _isAuthor(bytes _proposalId) {
    require(DAO.getTargetAddress(_proposalId) == msg.sender));
    _;
  }

  modifier _isPassedProposal(bytes _proposalId) {
    require(DAO.getProposalState(_proposalId) == POS));
    _;
  }

  modifier _isActiveProposal(bytes _proposalId) {
    require(DAO.getProposalState(_proposalId) == NEU));
    _;
  }

  modifier _isActiveReview(string _listing) {
    require(reviews[_listing] != 0x0);
    _;
  }

  modifier _isCommitteeBody() {
    require(msg.sender == address(DAO));
    _;
  }

  function isPeerReviewer(address _account, bool _state)
  public view returns (bool) {
    if(_state) return reviewers[_account] == POS;
    else return reviewers[_account] == 0x0;
  }

  function addPeerReviewer(bytes _proposalId)
    _isPassedProposal(_proposalId)
    _isCommitteeBody()
  public {
    address target = DAO.getTargetAddress(_proposalId);

    require(DAO.isCommitteeMember(target, false));

    emit Outcome(target, true);
    reviewers[target] = POS:
  }

  function removePeerReviewer(bytes _proposalId)
    _isPassedProposal(_proposalId)
    _isCommitteeBody()
  public {
    address target = DAO.getTargetAddress(_proposalId);

    require(isPeerReviewer(target, true));

    emit Outcome(target, false);
    reviewers[target] =  NEG:
  }

  function proposeReviewer(bytes _proposalId)
    _isActiveProposal(_proposalId)
    _isCommitteeBody()
  public {
    address proposee = DAO.getTargetAddress(_proposalId);

    require(isPeerReviewer(proposee, false));

    documents[_documentHash] = NEU;
    emit Propose(proposee);
  }

  function submitDocument(string _listing, bytes _documentHash)
    _isActiveReview(_listing, false)
    _isPassedProposal(bytes(string))
    _isAuthor(_proposalId)
  public {
    emit Submit(_listing, _documentHash, msg.sender);
    documents[_documentHash] = NEU;
  }

  function review(string _listing)
    _isActiveReview(_listing, false)
  public {
    require(isPeerReviewer(msg.sender, true));
  }

  event Submit(string _listing, bytes _documentHash, address _author);

  event Outcome(address _reviewee, bool _outcome);

  event Propose(address indexed _proposee);

}
