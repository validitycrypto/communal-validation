pragma solidity ^0.4.18;

import "./ERC20.sol";

contract DXDelegation
{

    struct Proposal
    {

        string tickr;
        string ctype;
        uint256 positive;
        uint256 negative;
        address[] voted;
        uint256[] weight;
        byte[] optn;
        string result;

    }

    modifier only_admin()
    {

        if(msg.sender != admin){revert();}
        _;

    }

    ERC20 public DX;
    uint256 constant VOTE = 10000;
    byte constant POS = 0x01;
    byte constant NEG = 0x02;
    string constant NA = "NA";
    address public admin  = msg.sender;

    mapping(string => Proposal) delegate;

    function initialiseToken(address token) public
    {

        DX = ERC20(token);

    }

    function delegationCreate(string project, string ticker, string ctype) public only_admin
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

    function delegationRetrial(string project,string ticker, string ctype) public only_admin
    {

        delete delegate[project];
        delegationCreate(project, ticker, ctype);

    }

    function delegationResult(string project) public constant returns (string, string, uint256, uint256, string)
    {

        Proposal storage output = delegate[project];
        return (output.tickr, output.ctype, output.positive, output.negative, output.result);

    }

    function voteSubmit(string name, string project, byte OPTION) public
    {

        uint del_count;
        uint v_count;
        uint p_vote;
        uint n_vote;
        string storage user;
        string[] storage dtabase;
        require(OPTION == NEG || OPTION == POS);
        (user, dtabase, del_count, v_count ,p_vote, n_vote) = DX.viewStats();
        if(del_count == 0){DX.voteRegister();}

        for(uint y = 0 ; y < dtabase.length ; y++)
        {

            string storage prev = dtabase[y];
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
            tickr: output.ticker,
            ctype: output.ctype,
            negative: output.negative,
            positive: output.positive,
            voted: output.voted,
            weight: output.weight,
            result: NA});
        delegate[project] = input;
        DX.delegationEvent(msg.sender, voting_weight, OPTION, project);

    }

    function delegationCount(address target) internal constant returns (uint256)
    {

        uint256 wager = DX.balanceOf(target);
        require(wager >= VOTE);
        uint256 reward = wager/VOTE;
        return reward;

    }

    function voteCount(string project) public only_admin
    {
        uint256 livebalance;
        uint256 votebalance;
        address voter;
        byte option;
        Proposal storage output = delegate[project];

        for(uint x = 0 ; x < output.voted ; x++)
        {

            voter = output.voted[x];
            votebalance = output.weight[x];
            option = output.optn[x];
            livebalance = DX.balanceOf(voter);
            livebalance = livebalance/VOTE;

            if(votebalance > livebalance)
            {

                if(option == POS){output.positive -= votebalance; output.positive += livebalance;}
                else if(option == NEG){output.negative -= votebalance; output.negative += livebalance;}

            }

            delegationReward(voter);

        }

        if(output.negative > output.postive){output.result = NEG;}
        else if(output.postive > output.negative){output.result = POS;}

    }

    function delegationReward(address target) public
    {

        uint256 weight = delegationCount(target);
        DX.transferFrom(this, target, weight);

    }

}
