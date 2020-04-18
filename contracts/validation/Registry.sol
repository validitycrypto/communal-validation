pragma solidity ^0.6.4;

import '../interfaces/IDAO.sol';

contract Registry {

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x4e65757472616c00000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  IDAO public DAO;

  struct Listing {
    mapping (address => bool) endorsers;
    uint16 endorsements;
    bytes documentHash;
    uint32 rating;
    uint256 bid;
    bool active;
    bool status;
  }

  mapping (string => Listing) public listings;

  modifier _isActiveListing(string memory _subject, bool _state) {
    if(_state) {
      require(listings[_subject].active && !listings[_subject].status);
    } else {
      require(!listings[_subject].active && !listings[_subject].status);
    } _;
  }

  modifier _isValidListing(string memory _subject, bool _state) {
    if(_state) require(listings[_subject].endorsements != 0);
    else require(listings[_subject].endorsements == 0);
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

  modifier _isCommitteeBody() {
    require(msg.sender == address(DAO));
    _;
  }

  modifier _isVerifiedUser(address _account) { _; }

  constructor(address _daoAddress) public {
    DAO = IDAO(_daoAddress);
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
    _isValidListing(string(_subject), true)
  private {
    listings[_subject].active = true;
  }

  function rateListing(bytes memory _subject, uint32 _rating)
    _isActiveListing(string(_subject), true)
    _isValidListing(string(_subject), true)
    _isPassedProposal(string(_subject))
  private {
    listings[string(_subject)].rating = _rating;
    listings[string(_subject)].status = true;
  }

  event Endowment(string listing, address indexed endowee, uint256 bid);

  event List(string listing, address indexed proposee, uint256 bid);

  event Endorsement(string listing, address indexed endorsee);

}
