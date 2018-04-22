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

    if(msg.sender != admin) throw;
       _;

  }

  ERC20 public DX;
  uint256 constant VOTE = 10000;
  byte constant POS = 0x01;
  byte constant NEG = 0x01;
  string constant NA = "NA";

  mapping(string => Proposal) delegate; 
  
  function initialiseToken(address token) public
  {
  
      DX = ERC20(token);
  
  }
    
  function delegationCreate(string project, string ticker, string ctype) only_admin
  {
  
    Proposal storage output = delegate[project];
    Proposal memory input = Proposal({tickr: ticker,
                                     ctype: ctype, 
                                     negative: 0, 
                                     positive: 0,
                                     voted: output.voted,
                                     weight: output.weight,
                                     result: NA}); 
    delegate[project] = input; 

  }
   
  function delegationRetrial(string project,string ticker, string ctype) only_admin
  {
  
    delete delegate[project];
    delegationCreate(project, ticker, ctype);
  
  }
   
  function delegationResult() public constant returns (string, uint256, uint256, address[], uint256[], string)
  {

     Proposal storage output = delegate[project];
     return (output.tickr, output.ctype, output.positive, output.negative, output.voted, output.weight, output.result);

  }

  function voteSubmit(string name, string project, byte OPTION) public
  {

    string prev;
    string user;
    string[] dtabase;
    uint del_count;
    uint v_count;
    uint p_vote;
    uint n_vote;
    require(OPTION == NEG || OPTION == POS);
    (user, dtabase, del_count, v_count ,p_vote, n_vote) = DX.viewStats();
    if(del_count == 0){DX.voteRegister();}
    
    for(y = 0 ; y < dtabase.length ; y++)
    {

        prev = dtabase[y];
        if(keccak256(prev) == keccak256(project)){revert();}

    }

    Proposal storage output = delegate[project];
    require(output.result == NA);
    uint256 voting_weight = delegationReward(msg.sender);
    output.voted.push(msg.sender);
    output.weight.push(voting_weight);
    output.optn.push(OPTION);
    if(OPTION == POS{output.negative += voting_weight;}
    else if(OPTION == NEG){output.positive += voting_weight;}
    Proposal memory input = Proposal({tickr: output.ticker, 
                                      ctype: output.ctype,
                                      negative: output.negative,
                                      positive: output.positive,
                                      voted: output.voted,
                                      weight: output.weight,
                                      result: NA}); 
    DX.delegationEvent(msg.sender, voting_weight, OPTION, project);

  }

    function delegationCount(address target) internal constant returns (uint256) 
  {

    uint256 wager = DX.balanceOf(target);
    require(wager >= VOTE);
    uint256 reward = wager/VOTE;
    return wager;

  }

  function voteCount(string project) only_admin
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
        option = output.optn;
        livebalance = DX.balanceOf(voter);
        livebalance = livebalance/VOTE;
        
        if(votebalance > livebalance)
        {
             
             if(option == POS){output.positive -= votebalance; output.positive += livebalance;} 
             else if(option == NEG){output.negative -= votebalance; output.negative += livebalance;} 
        
        }
            
        delegationReward(voter);

  }
  
  }
