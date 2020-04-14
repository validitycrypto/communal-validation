pragma solidity ^0.6.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract DAO {

  using SafeMath for uint256;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x4e65757472616c00000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  enum topic { committee, listing, action }

  struct Ballot {
    mapping (address => bytes32) verdict;
    uint16 participants;
    uint256 expiryBlock;
    uint256 negative;
    uint256 positive;
  }

  struct Listing {
    mapping (address => bool) endorsers;
    uint16 endorsements;
    uint256 bid;
    bool ballot;
    bool status;
  }

  struct Proposal {
    uint256 withdrawal;
    bytes32 ipfsHash;
    address proposee;
    address target;
    bytes metadata;
    topic variety;
    bool action;
  }

  struct Member {
    uint256 blockNumber;
    uint256 roleIndex;
    uint256 reputation;
  }

  mapping (address => Member) public committee;

  mapping (string => Listing) public listings;

  mapping (bytes => bytes32) public proposals;

  mapping (bytes => Ballot) public ballots;

  address[] public committeeMembers;

  constructor() public {
    committee[msg.sender].reputation = 99; // Founders Shares
    addCommitteeMember(msg.sender);
  }

  modifier _isActiveListing(string memory _subject, bool _state) {
    if(_state) {
      require(listings[_subject].ballot && !listings[_subject].status);
    } else {
      require(!listings[_subject].ballot && !listings[_subject].status);
    } _;
  }

  modifier _isVotable(bytes memory _proposalId, bool _state) {
    if(_state) {
      require(ballots[_proposalId].expiryBlock >= block.number);
      require(ballots[_proposalId].verdict[msg.sender] == 0x0);
    } else {
      require(ballots[_proposalId].expiryBlock < block.number);
    } _;
  }

  modifier _isActiveBallot(bytes memory _proposalId, bool _state) {
    if(_state) require(ballots[_proposalId].expiryBlock != 0);
    else require(ballots[_proposalId].expiryBlock == 0);
    _;
  }

  modifier _isActiveProposal(bytes memory _proposalId, bool _state) {
    if(_state) require(proposals[_proposalId] == NEU);
    else require(proposals[_proposalId] == 0x0);
    _;
  }

  modifier _isValidListing(string memory _subject, bool _state) {
    if(_state) require(listings[_subject].endorsements != 0);
    else require(listings[_subject].endorsements == 0);
    _;
  }

  modifier _isVerifiedUser(address _account) { _; }

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

  function changeCommittee(Proposal memory _proposal) private {
    if(!_proposal.action) removeCommitteeMember(_proposal.target);
    else if(_proposal.action) addCommitteeMember(_proposal.target);
  }

  function submitProposal(bytes memory _proposalId, topic _type)
    _isActiveProposal(_proposalId, false)
  private {
    emit Proposition(_proposalId, msg.sender, _type);

    proposals[_proposalId] = NEU;
  }

  function createProposal(Proposal memory _proposal, string memory _listing)
  public {
    require(isCommitteeMember(msg.sender, true));

    _proposal.proposee = msg.sender;
    bytes memory proposalId;

    if(_proposal.variety == topic.committee) {
      uint256 memberState = committee[_proposal.target].blockNumber;

      if(memberState == 0) _proposal.action = true;
      else _proposal.action = false;

      proposalId = abi.encode(_proposal);
    } else if(_proposal.variety == topic.listing) {
      proposalId = abi.encode(_listing);
      pushListing(proposalId);
    }

    submitProposal(proposalId, _proposal.variety);
    createBallot(proposalId);
  }

  function createBallot(bytes memory _proposalId)
    _isActiveProposal(_proposalId, true)
    _isActiveBallot(_proposalId, false)
    _isVotable(_proposalId, false)
  private {
    ballots[_proposalId].expiryBlock = block.number.add(1000);

    emit Poll(_proposalId);
  }

  function vote(bytes memory _proposalId, bytes32 _choice, bool _listing)
    _isActiveListing(string(_proposalId), _listing)
    _isActiveProposal(_proposalId, true)
    _isActiveBallot(_proposalId, true)
    _isVotable(_proposalId, true)
  public {
    require(isCommitteeMember(msg.sender, true));

    if(_choice == POS) {
      ballots[_proposalId].positive = getVotingWeight(_proposalId, true);
    } else if(_choice == NEG) {
      ballots[_proposalId].negative = getVotingWeight(_proposalId, false);
    } else revert();

    ballots[_proposalId].verdict[msg.sender] = _choice;
    ballots[_proposalId].participants++;
    committee[msg.sender].reputation++;

    emit Vote(_proposalId, msg.sender, _choice);
 }

  function concludeVote(bytes memory _proposalId)
    _isActiveBallot(_proposalId, true)
    _isVotable(_proposalId, false)
  public {
    require(getQuorum() <= ballots[_proposalId].participants);
    require(isCommitteeMember(msg.sender, true));

    uint256 approvals = ballots[_proposalId].positive;
    uint256 rejections = ballots[_proposalId].negative;

    if(approvals >= rejections) execute(_proposalId);
    else proposals[_proposalId] = NEG;

    emit Outcome(_proposalId, approvals, rejections);
  }

  function execute(bytes memory _proposalId) private {
    Proposal memory proposition = abi.decode(_proposalId, (Proposal));

    if(proposition.variety == topic.committee) changeCommittee(proposition);
    else if(proposition.variety == topic.listing) pushListing(_proposalId);
    else if (proposition.variety == topic.action) makeTransaction(proposition);

    committee[proposition.proposee].reputation++;
    proposals[_proposalId] = POS;
    delete ballots[_proposalId];
  }

  function makeTransaction(Proposal memory _proposal)
  private {
    return _proposal.target.call.value(_proposal.withdrawal)(_proposal.metadata);
  }

  function createListing(string memory _subject)
    _isActiveListing(_subject, false)
    _isValidListing(_subject, false)
  public payable {
    require(bytes(_subject).length != 0);

    listings[_subject].endorsers[msg.sender] = true;
    listings[_subject].bid = msg.value;
    listings[_subject].endorsements++;

    emit List(_subject, msg.sender, msg.value);
  }

  function fundListing(string memory _subject)
    _isValidListing(_subject, true)
  public payable {
    uint256 existingBid = listings[_subject].bid;

    listings[_subject].bid = existingBid.add(msg.value);

    emit Endowment(_subject, msg.sender, msg.value);
  }

  function endorseListing(string memory _subject)
    _isValidListing(_subject, true)
    _isVerifiedUser(msg.sender)
  public {
    require(!listings[_subject].endorsers[msg.sender]);

    listings[_subject].endorsers[msg.sender] = true;
    listings[_subject].endorsements++;

    emit Endorsement(_subject, msg.sender);
  }

  function pushListing(bytes memory _subject)
    _isActiveListing(string(_subject), true)
    _isValidListing(string(_subject), true)
  private {
    listings[string(_subject)].ballot = false;
    listing[string(_subject)].status = true;
  }

  function getVotingWeight(bytes memory _proposalId, bool _option)
  private returns (uint256) {
    uint256 reputation = committee[msg.sender].reputation;

    if(_option) return ballots[_proposalId].positive.add(reputation);
    else return ballots[_proposalId].negative.add(reputation);
  }

  function getQuorum()
  public view returns (uint) {
    uint256 committeeCount = committeeMembers.length;

    if(committeeCount % 2 == 0) return committeeCount.div(2);
    else return committeeCount.sub(1).div(2);
  }

  function getProposalTopic(bytes _proposalId)
  public view returns (topic) {
    Proposal memory proposition = abi.decode(_proposalId, (Proposal));
    return proposition.variety;
  }

  function getTargetAddress(bytes _proposalId)
  public view returns (address) {
    Proposal memory proposition = abi.decode(_proposalId, (Proposal));
    return proposition.target;
  }

  function getProposalState(bytes _proposalId)
  public view returns (bytes32) {
    return proposals[_proposalId];
  }

  event Proposition(bytes proposalId, address indexed proposee, topic variant);

  event Outcome(bytes proposalId, uint256 approvals, uint256 rejections);

  event Endowment(string listing, address indexed endowee, uint256 bid);

  event Vote(bytes proposalId, address indexed member, bytes32 option);

  event List(string listing, address indexed proposee, uint256 bid);

  event Endorsement(string listing, address indexed endorsee);

  event Poll(bytes proposalId);

}
