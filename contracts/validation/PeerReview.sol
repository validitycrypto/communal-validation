pragma solidity ^0.6.4;

import '../interfaces/IDAO.sol';

contract Validation {

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x4e65757472616c00000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  struct Review {
    mapping (address => bytes32) verdict;
    uint256 expiryBlock;
    bytes documentHash;
    uint256 accept;
    uint256 reject;
  }

  mapping (address => bytes32) public reviewers;
  mapping (string => bytes) public reviews;
  mapping (bytes => Review) public critque;

  constructor() public { }

  modifier _isAuthor(bytes _proposalId) {
    require(DAO.getTargetAddress(_proposalId) == msg.sender));
    require(DAO.getProposalTopic(_proposalId) == 0);
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

  modifier _isReviewable(string _listing) {
    if(_state) {
      require(critque[_listing].verdict[msg.sender] ==  0x0);
      requre(critque[_listing].expiryBlock > block.number);
    } else {
      requre(critque[_listing].expiryBlock < block.number);
    }
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
    critque[_listing].expiryBlock = block.number.add(1000);
    critque[_listing].documentHash = documentHash;

    emit Submit(_listing, _documentHash, msg.sender);
  }

  function review(string _listing, bytes32 _decision, bytes32 ipfsHash)
    _isActiveReview(_listing, true)
    _isReviewable(_listing, true)
  public {
    require(isPeerReviewer(msg.sender, true));

    bytes documentHash = getDocumentHash(_listing);

    if(_decision == POS) critque[_listing].accept++;
    else if(_decision == NEG) critque[_listing].reject++;
    else revert();

    emit Vote(documentHash, msg.sender, _decision, _ipfsHash);
    critque[_listing].verdict[msg.sender] = _decision;
  }

  function finaliseDocument(string _listing)
    _isActiveReview(_listing, true)
    _isReviewable(_listing, false)
  public {
    require(isCommitteeMember(msg.sender, true));

    bytes documentHash = getDocumentHash(_listing);
    uint256 rejects = critque[_listing].rejects;
    uint256 accepts = critque[_listing].accept;

    if(accepts => rejects) {
      reviews[_listing] = documentHash
      startSentiment(_listing);
    }

    emit Result(documentHash, accepts, rejects);
    delete critque[_listing];
  }

  function startSentiment(string _listing)
  private {
  }

  function getDocumentHash(string _listing)
  public view returns (bytes) {
    bytes critqueHash = critque[_listing].documentHash;
    bytes reviewHash = reviews[_listing];

    critqueHash != 0x0 ? return critqueHash : return reviewHash;
  }

  event Vote(string listing, address indexed voter, bool decision, bytes32 ipfsHash);

  event Result(bytes documentHash, uint256 accepts, uint256 rejects);

  event Submit(string listing, bytes _documentHash, address author);

  event Outcome(address indexed reviewee, bool outcome);

  event Propose(address indexed proposee);

}
