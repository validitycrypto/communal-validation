pragma solidity ^0.4.18;

contract DelegationDX {

    struct Dta 
    {

        string tickr;
        string ctype;
        uint256 positive;
        uint256 negative;
        string result;

    }

  struct Votee {

        string username;
        string[] delegates;
        uint256 delegation_count;
        uint256 vote_count;
        uint256 neg_votes;
        uint256 pos_votes;

  } 


  uint256 constant VOTE = 10000;
  byte constant POS = 0x01;
  byte constant NEG = 0x01;
  string constant NA = "NA";

  mapping (address => mapping (address => uint256)) internal allowed;
  mapping(string => Dta) delegate; 
  mapping(address => Votee) voter; 

  function delegationReward() private constant returns (uint256) {

    uint256 wager = balances[tx.origin];
    require(wager >= VOTE);
    uint256 reward = wager/VOTE;
    balances[tx.origin] += reward;

    return wager;

  }

  function delegationCreate(string project,string ticker,string ctype) {

    Dta memory input = Dta({tickr: ticker, ctype: ctype, negative: 0 , positive: 0, result: NA}); 
    delegate[project] = input; 

  }

  function delegationResults() {


   

  }


  function voteSubmission(string name, string project, byte OPTION) {

    require(OPTION == NEG || OPTION == POS);

    Votee storage x = voter[msg.sender];
    if(x.delegation_count == 0){ voteRegister();}
    uint y = 0;
    string prev;

    for (y; y < x.delegates.length ; y++) {

        prev = x.delegates[y];

        if(keccak256(prev) == keccak256(project)){ revert; }
        else if(keccak256(prev) != keccak256(project)){ continue; }

    }

    Dta storage output = delegate[project];
    require(output.result == NA);
    uint256 voting_weight = delegationReward();

    if(OPTION == POS){ output.positive += voting_weight;
                           x.pos_vote  += voting_weight; } 
    else if(OPTION == NEG){ output.negative += voting_weight;
                                x.neg_vote  += voting_weight; } 
    x.delegation_count++;
    x.vote_count += voting_weight;
    x.delgates.push(name)

  }


  function voteRegister() {

      Votee memory x = Votee({username: name, delegation_count: 0, vote_count: 0, pos_votes: 0, neg_votes: 0});

      voter[msg.sender] = x; 

  }



  function voteCount() {




  }
  
  }
