pragma solidity ^0.6.4;
pragma experimental ABIEncoderV2;

import "./interfaces/IRegistry.sol";
import "./lib/SafeMath.sol";
import "./Committee.sol";

contract DAO is Committee {

  using SafeMath for uint256;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x4e65757472616c00000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  enum topic { committee, reviewer, listing, action }

  IRegistry public REG;

  struct Ballot {
    mapping (address => bytes32) verdict;
    uint16 participants;
    uint256 expiryBlock;
    uint256 negative;
    uint256 positive;
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

  mapping (bytes => bytes32) public proposals;

  mapping (bytes => Ballot) public ballots;

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

  modifier _isVerifiedUser(address _account) { _; }

  constructor(address _registryAddress) public {
    REG = IRegistry(_registryAddress);
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
      REG.submitProposal(proposalId);
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
    else if(proposition.variety == topic.listing) REG.pushListing(_proposalId);
    else if (proposition.variety == topic.action) makeTransaction(proposition);

    committee[proposition.proposee].reputation++;
    proposals[_proposalId] = POS;
    delete ballots[_proposalId];
  }

  function makeTransaction(Proposal memory _proposal)
  private {
    return _proposal.target.call.value(_proposal.withdrawal)(_proposal.metadata);
  }

  function changeCommittee(Proposal memory _proposal) private {
    if(!_proposal.action) removeCommitteeMember(_proposal.target);
    else if(_proposal.action) addCommitteeMember(_proposal.target);
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

  event Vote(bytes proposalId, address indexed member, bytes32 option);

  event Poll(bytes proposalId);

}
