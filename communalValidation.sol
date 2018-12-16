pragma solidity ^0.4.24;

import "./ERC20d.sol";

contract communalValidation
{

    bytes32 constant public POS = 0x506f736974697665000000000000000000000000000000000000000000000000;
    bytes32 constant public NEG = 0x4e65676174697665000000000000000000000000000000000000000000000000;
    uint256 constant public VOTE = 10000;
    address public admin  = msg.sender;

    struct Proposal
    {

        bytes32 name;
        bytes32 sym;
        bytes32 ctype;
        uint256 positive;
        uint256 negative;
        address[] voted;
        uint256[] weight;
        bytes32[] optn;
        uint256 result;

    }

    modifier only_admin(){ if(msg.sender != admin){revert();} _;  }

    ERCDX public DXTOKEN;
    uint256 public del_count;
    uint256 public v_count;
    uint256 public p_count;
    uint256 public n_count;
    bytes32 public bonus;
    bytes32 public user;

    event create(bytes32 indexed ident, bytes32 indexed note, bytes32 indexed asset);
    mapping(bytes32 => Proposal) public delegate;

    function initialiseToken(address token) public only_admin
    {

        DXTOKEN = ERCDX(token);

    }

    function delegationCreate(bytes32 project, bytes32 tick, bytes32 ct) public only_admin
    {

        address[] memory x;
        uint256[] memory y;
        bytes32[] memory z;
        uint256 q;
        memStore(project, tick, ct, q, q, x, y, z, q);
        emit create(project, tick, ct);

    }

    function delegationRetrial(bytes32 project, bytes32 ticker, bytes32 ctype) public only_admin
    {

        delete delegate[project];
        delegationCreate(project, ticker, ctype);

    }

    function delegationResult(bytes32 project) public constant returns (bytes32, bytes32, bytes32,  uint256, uint256, address[], uint256[], bytes32[], uint256)
    {

        Proposal storage output = delegate[project];
        return(output.name, output.sym, output.ctype, output.positive, output.negative,  output.voted, output.weight, output.optn, output.result);

    }

    function voteSubmit(bytes32 name, bytes32 project, bytes32 OPTION) public
    {

        bytes32[25] memory dtabase;
        require(OPTION == POS || OPTION == NEG);
        (user, dtabase, p_count, n_count, del_count, v_count, bonus) = DXTOKEN.viewStats(msg.sender);
        if(name == 0){DXTOKEN.registerVoter(name);}

        for(uint y = 0 ; y < dtabase.length ; y++)
        {

            bytes32 prev = dtabase[y];
            if(prev == project){revert();}

        }

        Proposal storage output = delegate[project];
        uint256 voting_weight = delegationCount(msg.sender);
        output.voted.push(msg.sender);
        output.weight.push(voting_weight);
        output.optn.push(OPTION);
        require(output.result == 0);
        if(OPTION == NEG){output.negative = output.negative + voting_weight;}
        else if(OPTION == POS){output.positive = output.positive + voting_weight;}
        memStore(output.name, output.sym, output.ctype, output.negative, output.positive, output.voted, output.weight, output.optn, output.result);
        DXTOKEN.delegationEvent(msg.sender, voting_weight, OPTION, project);

    }

    function memStore(bytes32 ax, bytes32 bx, bytes32 cx, uint256 dx, uint256 ex, address[] fx, uint256[] gx, bytes32[] hx, uint256 lx) internal
    {

      Proposal memory input = Proposal({
          name:  ax,
          sym: bx,
          ctype: cx,
          negative: dx,
          positive: ex,
          voted: fx,
          weight: gx,
          optn: hx,
          result: lx});
      delegate[ax] = input;

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
