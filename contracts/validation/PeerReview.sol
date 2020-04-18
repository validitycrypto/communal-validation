pragma solidity ^0.6.4;

import "./Registry.sol";

contract PeerReview is Registry {

  struct Review {
    mapping (address => bytes32) verdict;
    uint256 expiryBlock;
    bytes documentHash;
    uint256 accept;
    uint256 reject;
    uint32 rating;
  }

  mapping (address => bytes32) public reviewers;
  mapping (string => Review) public reviews;

  modifier _isReviewable(string _listing, bool _state) {
    if(_state) {
      require(reviews[_listing].verdict[msg.sender] ==  0x0);
      requre(reviews[_listing].expiryBlock > block.number);
    } else {
      requre(reviews[_listing].expiryBlock < block.number);
    }
    _;
  }

  modifier _isAuthor(bytes _proposalId) {
    require(DAO.getTargetAddress(_proposalId) == msg.sender));
    require(DAO.getProposalTopic(_proposalId) == 1);
    _;
  }

  modifier _isActiveReview(string _listing, bool _state) {
    if(_state) require(reviews[_listing].expiryBlock != 0);
    else require(reviews[_listing].expiryBlock == 0);
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
    reviewers[target] = NEG;
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

  function submitDocument(string _listing, uint32 _rating, bytes _documentHash)
    _isPassedProposal(bytes(string))
    _isActiveReview(_listing, false)
    _isReviewable(_listing, false)
    _isAuthor(_proposalId)
  public {
    reviews[_listing].expiryBlock = block.number.add(1000);
    reviews[_listing].documentHash = documentHash;
    reviews[_listing].rating = _rating;

    emit Submit(_listing, _rating, _documentHash, msg.sender);
  }

  function review(string _listing, bytes32 _decision, bytes32 ipfsHash)
    _isActiveReview(_listing, true)
    _isReviewable(_listing, true)
  public {
    require(isPeerReviewer(msg.sender, true));

    bytes documentHash = getDocumentHash(_listing);

    if(_decision == POS) reviews[_listing].accept++;
    else if(_decision == NEG) reviews[_listing].reject++;
    else revert();

    emit Vote(documentHash, msg.sender, _decision, _ipfsHash);
    reviews[_listing].verdict[msg.sender] = _decision;
  }

  function getDocumentHash(string _listing)
  public view returns (bytes) {
    return reviews[_listing].documentHash;
  }

  event Vote(string listing, address indexed voter, bool decision, bytes32 ipfsHash);

  event Submit(string listing, uint32 rating, bytes documentHash, address author);

  event Result(bytes documentHash, uint256 accepts, uint256 rejects);

  event Outcome(address indexed reviewee, bool outcome);

  event Propose(address indexed proposee);

}
