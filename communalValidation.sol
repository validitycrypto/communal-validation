pragma solidity ^0.4.24;

import "./addressSet.sol";
import "./SafeMath.sol";
import "./ERC20d.sol";

contract communalValidation {

  using addressSet for addressSet.Set;
  using SafeMath for uint;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x6e65757472616c00000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  uint constant VOTE = 1000000000000000000000;

  struct _validation {

      addressSet.Set _delegates;
      bytes32 _subject;
      bytes32 _ticker;
      bytes32 _type;
      bytes32 _positive;
      bytes32 _negative;
      bytes32 _neutral;
      bytes32 _rounds;
      bytes32 _result;

  }

  mapping(bytes32 => mapping (uint => _validation)) private _event;
  mapping(bytes32 => bool) private _active;

  address public _admin  = msg.sender;
  ERC20d private _VLDY;
  bytes32 public _live;
  uint public _round;

  modifier _delegateCheck(address _account) {
    require(!_event[_live][_round]._delegates.contains(_account)
            && _VLDY.isStaking(_account)
            && _VLDY.isActive(_account));
    _;
  }

  modifier _onlyAdmin() {
      require(msg.sender == _admin);
      _;
  }

  function initialiseAsset(address _source) _onlyAdmin public {
      _VLDY = ERC20d(_source);
  }

  function currentEvent() public view returns (bytes32 subject) {
      subject = _live;
   }

  function currentRound() public view returns (uint round) {
      round = _round;
  }

  function isVoted(address _voter) public view returns (bool) {
      return _event[_live][_round]._delegates.contains(_voter);
  }

  function eventSubject(bytes32 _entity, uint _index) public view returns (bytes32 subject) {
      subject = _event[_entity][_index]._subject;
  }

  function eventType(bytes32 _entity, uint _index) public view returns (bytes32 class) {
      class = _event[_entity][_index]._type;
  }

  function eventPositive(bytes32 _entity, uint _index) public view returns (uint positive) {
      positive = uint(_event[_entity][_index]._positive);
  }

  function eventNegative(bytes32 _entity, uint _index) public view returns (uint negative) {
      negative = uint(_event[_entity][_index]._negative);
  }

  function eventNeutral(bytes32 _entity, uint _index) public view returns (uint neutral) {
      neutral = uint(_event[_entity][_index]._neutral);
  }

  function createEvent(bytes32 _entity, bytes32 _tick, bytes32 _asset, uint _index) public _onlyAdmin
  {
      _event[_entity][_index]._subject = _entity;
      _event[_entity][_index]._ticker = _tick;
      _event[_entity][_index]._type = _asset;
      _active[_entity] = true;
      _live = _entity;
      _round = _index;
  }

  function voteSubmit(bytes32 _choice) _delegateCheck(msg.sender) public {
      _event[_live][_round]._delegates.insert(msg.sender);
      bytes memory id = _VLDY.getvID(msg.sender);
      uint weight = votingWeight(id, msg.sender);

      if(_choice == POS) {
        _event[_live][_round]._positive = bytes32(eventPositive(_live, _round).add(weight));
      } else if(_choice == NEU) {
        _event[_live][_round]._neutral = bytes32(eventNeutral(_live, _round).add(weight));
      } else if(_choice == NEG) {
        _event[_live][_round]._negative = bytes32(eventNegative(_live, _round).add(weight));
      }

      _VLDY.delegationEvent(id, _choice, weight);
  }

  function votingWeight(bytes _id, address _voter) public view returns (uint stake) {
      require(_VLDY.balanceOf(_voter) >= VOTE);

      uint wager = _VLDY.balanceOf(_voter);
      uint trust = _VLDY.trustLevel(_id);
      uint weightUsage;

      if(trust == 0){
        weightUsage = 25;
      } else if(trust > 0) {
        weightUsage = 50;
      } else if(trust > 5) {
        weightUsage = 75;
      } else if(trust > 10) {
        weightUsage = 100;
      }
      wager = wager.mul(weightUsage.div(100));
      stake = wager.div(VOTE);
  }

  function distributeRewards() _onlyAdmin public {
      uint totalDelegates = _event[_live][_round]._delegates.length();
      for(uint v = 0; v < totalDelegates ; v++) {
        address voter = _event[_live][_round]._delegates.members[v];
        bytes memory id = _VLDY.getvID(voter);
        uint reward = votingWeight(id, voter);
        _VLDY.delegationReward(id, voter, reward);
        _VLDY.increaseTrust(id);
      }
  }

}
