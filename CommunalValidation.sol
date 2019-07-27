pragma solidity ^0.5.8;

import "./addressSet.sol";
import "./ERC20d.sol";

contract communalValidation {

  using addressSet for addressSet.Set;
  using SafeMath for uint;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x4e65757472616c00000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  uint constant VOTE = 10000000000000000000000;

  struct _validation {
      addressSet.Set _delegateRef;
      bytes32 _positiveVotes;
      bytes32 _negativeVotes;
      bytes32 _neutralVotes;
      bytes32 _subjectType;
      bytes32 _assetTicker;
      bytes32 _eventCount;
      bytes32 _quantScore;
  }

  mapping(bytes32 => mapping (uint => _validation)) private _event;
  mapping(bytes32 => bool) private _active;

  address public _admin  = msg.sender;
  ERC20d private VLDY;
  bytes32 public _live;
  uint public _round;

  modifier _delegateCheck(address _account) {
    require(!_event[_live][_round]._delegateRef.contains(_account)
            && VLDY.isStaking(_account)
            && VLDY.isActive(_account));
    _;
  }

  modifier _onlyAdmin() {
      require(msg.sender == _admin);
      _;
  }

  function initialiseAsset(address _source) _onlyAdmin public {
      VLDY = ERC20d(_source);
  }

  function currentEvent() public view returns (bytes32 subject) {
      subject = _live;
   }

  function currentRound() public view returns (uint round) {
      round = _round;
  }

  function currentParticipants() public view returns (uint round) {
    return _event[_live][_round]._delegateRef.length();
  }

  function isVoted(address _voter) public view returns (bool) {
      return _event[_live][_round]._delegateRef.contains(_voter);
  }

  function eventTicker(bytes32 _entity, uint _index) public view returns (bytes32 ticker) {
      ticker = _event[_entity][_index]._assetTicker;
  }

  function eventType(bytes32 _entity, uint _index) public view returns (bytes32 class) {
      class = _event[_entity][_index]._subjectType;
  }

  function eventPositive(bytes32 _entity, uint _index) public view returns (uint positive) {
      positive = uint(_event[_entity][_index]._positiveVotes);
  }

  function eventNegative(bytes32 _entity, uint _index) public view returns (uint negative) {
      negative = uint(_event[_entity][_index]._negativeVotes);
  }

  function eventNeutral(bytes32 _entity, uint _index) public view returns (uint neutral) {
      neutral = uint(_event[_entity][_index]._neutralVotes);
  }

  function createEvent(bytes32 _entity, bytes32 _tick, bytes32 _asset, uint _index) public _onlyAdmin
  {
      _event[_entity][_index]._assetTicker = _tick;
      _event[_entity][_index]._subjectType = _asset;
      _active[_entity] = true;
      _live = _entity;
      _round = _index;
  }

  function voteSubmit(bytes32 _choice) _delegateCheck(msg.sender) public {
      _event[_live][_round]._delegateRef.insert(msg.sender);
      bytes32 id = VLDY.validityId(msg.sender);
      uint weight = votingWeight(msg.sender);

      if(_choice == POS) {
        _event[_live][_round]._positiveVotes = bytes32(eventPositive(_live, _round).add(weight));
      } else if(_choice == NEU) {
        _event[_live][_round]._neutralVotes = bytes32(eventNeutral(_live, _round).add(weight));
      } else if(_choice == NEG) {
        _event[_live][_round]._negativeVotes = bytes32(eventNegative(_live, _round).add(weight));
      }

      VLDY.validationEvent(id, _live, _choice, weight);
  }

  function votingWeight(address _voter) public view returns (uint stake) {
      require(VLDY.balanceOf(_voter) >= VOTE);

      uint wager = VLDY.balanceOf(_voter);
      stake = wager.div(VOTE);
  }

  function concludeValidation() _onlyAdmin public {
      for(uint x = 0; x < currentParticipants(); x++){
        address delegate = _event[_live][_round]._delegateRef.members[x];
        VLDY.validationReward(VLDY.validityId(delegate), delegate, VOTE);
      }
  }

}

