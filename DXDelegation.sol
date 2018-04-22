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
  
  function initialiseToken(address token) public {
  
      DX = ERC20(token);
  
  }
    
  function delegationReward(address target) internal constant returns (uint256) 
  {

    uint256 wager = DX.balanceOf(msg.sender);
    require(wager >= VOTE);
    uint256 reward = wager/VOTE;
    DX.transferFrom(this,target,reward);
    return wager;

  }

  function delegationCreate(string project, string ticker, string ctype) only_admin
  {
  
    Proposal memory input = Proposal({tickr: ticker, ctype: ctype, negative: 0 , positive: 0, result: NA}); 
    delegate[project] = input; 

  }

  function delegationResults() public
  {


   

  }

  function voteSubmission(string name, string project, byte OPTION) public
  {

    string prev;
    string user;
    string[] exec;
    uint del_count;
    uint v_count;
    uint p_vote;
    uint n_vote;
    require(OPTION == NEG || OPTION == POS);
    (user,exec,del_count,v_count,p_vote,n_vote) = DX.viewStats();
    
    if(del_count == 0){voteRegister();}
    
    for(y = 0 ; y < x.delegates.length ; y++)
    {

        prev = x.delegates[y];
        
        if(keccak256(prev) == keccak256(project)){revert();}
        else if(keccak256(prev) != keccak256(project)){continue;}

    }

    Proposal storage output = delegate[project];
    require(output.result == NA);
    uint256 voting_weight = delegationReward();
    output..push(msg.sender);
    output.weight.push(voting_weight);
    if(OPTION == POS{output.negative += voting_weight;}
    else if{output.positive += voting_weight;}
    Proposal memory input = Proposal({tickr: output.ticker, ctype: output.ctype, negative: output.negative , positive: output.positive, voted: output.voted, weight: output.weight, result: NA}); 
    DX.delegationEvent(msg.sender, voting_weight, OPTION, project);

  }


  function voteCount() only_admin
  {
    
  


  }
  
  }
