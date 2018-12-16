pragma solidity ^0.4.24;

import "./addressSet.sol";
import "./SafeMath.sol";
import "./ERC20d.sol";

contract communalValidation
{

  using addressSet.Set for address;
  using SafeMath for uint;

  bytes32 constant POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
  bytes32 constant NEU = 0x6e65757472616c00000000000000000000000000000000000000000000000000;
  bytes32 constant NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;

  uint constant VOTE = uint(1000).mul(10**uint(18));

  struct _validation {

      addressSet.Set _delegates;
      bytes32 _subject;
      bytes32 _ticker;
      bytes32 _type;
      bytes32 _postive;
      bytes32 _negative;
      bytes32 _neutral;
      bytes32 _events;
      bytes32 _result;

  }

  mapping(bytes32 => mapping (uint => _validation)) private _event;
  mapping(bytes32 => bool) private _active;

  address public _admin  = msg.sender;
  ERC20d private _VLDY;
  bytes32 public _live;
  uint public _round;

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

  function createEvent(bytes32 _entity, bytes32 _tick, bytes32 _asset, uint _index) public _onlyAdmin
  {
      _event[_round][_entity]._subject = _entity;
      _event[_round][_entity]._ticker = _tick;
      _event[_round][_entity]._type = _asset;
      _active[_entity] = true;
      _live = _entity;
      _round = _index;
  }

    function voteSubmit(bytes32 _choice) public
    {
      require(!_event[_round][_live]._delegates.contains(msg.sender));

    }

    function delegationCount(address target) internal constant returns (uint256)
    {

        uint256 wager = DXTOKEN.balanceOf(target);
        require(wager >= VOTE);
        uint256 reward = wager/VOTE;
        return reward;

    }

    function voteCount(bytes32 project) public only_admin
    {
        uint256 livebalance;
        uint256 votebalance;
        address voter;
        bytes32 option;
        Proposal storage output = delegate[project];

        for(uint x = 0 ; x < output.voted.length ; x++)
        {

            voter = output.voted[x];
            votebalance = output.weight[x];
            option = output.optn[x];
            livebalance = DXTOKEN.balanceOf(voter);
            livebalance = livebalance/VOTE;

            if(votebalance > livebalance)
            {

                if(option == POS){output.positive = output.positive - votebalance; output.positive = output.positive + livebalance;}
                else if(option == NEG){output.negative = output.negative - votebalance; output.negative = output.negative + livebalance;}

            }


        }


        if(output.negative > output.positive){output.result = output.negative;}
        else if(output.positive > output.negative){output.result = output.positive;}
        memStore(output.name, output.sym, output.ctype, output.negative, output.positive, output.voted, output.weight, output.optn, output.result);

    }

    function delegationReward(address target) public
    {

        uint256 weight = delegationCount(target);
        DXTOKEN.transferFrom(this, target, weight);

    }

}
