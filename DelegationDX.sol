pragma solidity ^0.4.19;

import "./DX.sol";

contract DelegationDX
{

    struct Proposal
    {

        string tickr;
        string ctype;
        uint256 positive;
        uint256 negative;
        address[] voted;
        uint256[] weight;
        bytes1[] optn;
        bytes1 result;

    }

    modifier only_admin()
    {

        if(msg.sender != admin){revert();}
        _;

    }

    DX public DXTOKEN;
    bytes1 constant POS = 0x01;
    bytes1 constant NEG = 0x02;
    bytes1 constant NA = 0xff;
    uint256 constant VOTE = 10000;
    address public admin  = msg.sender;

    mapping(bytes32 => Proposal) delegate;

    function initialiseToken(address token) public only_admin
    {

        DXTOKEN = DX(token);

    }

    function delegationCreate(bytes32 project, string ticker, string ctype) public only_admin
    {

        Proposal storage output = delegate[project];
        Proposal memory input = Proposal({
            tickr: ticker,
            ctype: ctype,
            negative: 0,
            positive: 0,
            voted: output.voted,
            weight: output.weight,
            optn: output.optn,
            result: NA});
        delegate[project] = input;

    }

    function delegationRetrial(bytes32 project, string ticker, string ctype) public only_admin
    {

        delete delegate[project];
        delegationCreate(project, ticker, ctype);

    }

    function delegationResult(bytes32 project) public constant returns (string, string, uint256, uint256, bytes1)
    {

        Proposal storage output = delegate[project];
        return (output.tickr, output.ctype, output.positive, output.negative, output.result);

    }

    function voteSubmit(bytes32 name, bytes32 project, bytes1 OPTION) public
    {

        uint256 del_count;
        uint256 v_count;
        bytes32 user;
        bytes32[25] memory dtabase;
        require(OPTION == NEG || OPTION == POS);
        (user, dtabase, del_count, v_count) = DXTOKEN.viewStats(msg.sender);
        if(del_count == 0){DXTOKEN.registerVoter(name);}

        for(uint y = 0 ; y < dtabase.length ; y++)
        {

            bytes32 prev = dtabase[y];
            if(keccak256(prev) == keccak256(project)){revert();}

        }

        Proposal storage output = delegate[project];
        require(output.result == NA);
        uint256 voting_weight = delegationCount(msg.sender);
        output.voted.push(msg.sender);
        output.weight.push(voting_weight);
        output.optn.push(OPTION);
        if(OPTION == POS){output.negative += voting_weight;}
        else if(OPTION == NEG){output.positive += voting_weight;}
        Proposal memory input = Proposal({
            tickr: output.tickr,
            ctype: output.ctype,
            negative: output.negative,
            positive: output.positive,
            voted: output.voted,
            weight: output.weight,
            optn: output.optn,
            result: NA});
        delegate[project] = input;
        DXTOKEN.delegationEvent(msg.sender, voting_weight, OPTION, project);

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
        bytes1 option;
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

                if(option == POS){output.positive -= votebalance; output.positive += livebalance;}
                else if(option == NEG){output.negative -= votebalance; output.negative += livebalance;}

            }

            delegationReward(voter);

        }

        if(output.negative > output.positive){output.result = NEG;}
        else if(output.positive > output.negative){output.result = POS;}

    }

    function delegationReward(address target) public
    {

        uint256 weight = delegationCount(target);
        DXTOKEN.transferFrom(this, target, weight);

    }

}
