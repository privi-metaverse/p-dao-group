// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./interfaces/IManageCommunityToken.sol";
import "./interfaces/ICommunityEjectMember.sol";

import "./constant.sol";

contract PRIVIDAO {
    mapping(uint => CommunityCreationProposal) _communityCPs;
    mapping(address => Community) _communities;

    uint[] _communityCPIds;
    address[] _communityIds;

    address _exchangeContractAddress;
    address _auctionContractAddress;

    address _manageCommunityTokenContractAddress;
    address _ejectMemberContractAddress;

    uint _communityCPCounter;
    uint _communityCounter;

    constructor(address exchangeContractAddress, address auctionContractAddress) {
        _exchangeContractAddress = exchangeContractAddress;
        _auctionContractAddress = auctionContractAddress;
    }

    function getCommunityIdByIndex(uint index) public view returns(address){
        return _communityIds[index];
    }

    function getCommunityCounter() public view returns(uint) {
        return _communityCounter;
    }

    function getCommunityCPIdByIndex(uint index) public view returns(uint){
        return _communityCPIds[index];
    }

    function getCommunityCPCounter() public view returns(uint) {
        return _communityCPCounter;
    }

    function getExchangeContractAddress() public view returns(address) {
        return _exchangeContractAddress;
    }

    function getAuctionContractAddress() public view returns(address) {
        return _auctionContractAddress;
    }
    
    function getIdOfFounders(Community memory community, address founder) public pure returns(uint, bool) {
        for(uint i = 0; i < community.foundersCount; i++) {
            if(community.founders[i] == founder) {
                return (i, true);
            }
        }
        return (0, false);
    }

    function getCreationProposal(uint proposalId) public view returns(CommunityCreationProposal memory){
        return _communityCPs[proposalId];
    }

    function getCommunity(address communityId) public view returns(Community memory) {
        return _communities[communityId];
    }

    function updateCommunity(Community memory community) public {
        uint index;
        bool flag = false;

        for(uint i = 0; i < _communityCounter; i++) {
            if(_communityIds[i] == community.communityAddress) {
                index = i;
                flag = true;
                break;
            }
        }
        
        require(flag, "community is not exist");

        _communityIds[index] = community.communityAddress;
        _communities[community.communityAddress] = community;
    }

    function updateCommunityCreationProposal(CommunityCreationProposal memory communityCP) internal {
        uint index;
        bool flag = false;

        for(uint i = 0; i < _communityCPCounter; i++) {
            if(_communityCPIds[i] == communityCP.proposalId) {
                index = i;
                flag = true;
                break;
            }
        }
        
        require(flag, "community creation proposal is not exist");

        _communityCPIds[index] = communityCP.proposalId;
        
        _communityCPs[communityCP.proposalId].proposal = communityCP.proposal;
        _communityCPs[communityCP.proposalId].proposalCreator = communityCP.proposalCreator;
        _communityCPs[communityCP.proposalId].proposalId = communityCP.proposalId;
        _communityCPs[communityCP.proposalId].date = communityCP.date;

        for(uint j = 0; j < communityCP.proposal.foundersCount; j++) {
            _communityCPs[communityCP.proposalId].approvals[j].IsVoted = communityCP.approvals[j].IsVoted;
            _communityCPs[communityCP.proposalId].approvals[j].Vote = communityCP.approvals[j].Vote;
        }
    }

    function setManageCommunityTokenContractAddress(address manageCommunityTokenContractAddress) external {
        _manageCommunityTokenContractAddress = manageCommunityTokenContractAddress;
    }

    function setEjectMemberContractAddress(address ejectMemberContractAddress) external {
        _ejectMemberContractAddress = ejectMemberContractAddress;
    }

    function deleteCommunityCreationProposal(uint proposalId) public {
        delete _communityCPs[proposalId];
    }

    function cancelCreationProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        CommunityCreationProposal memory communityCreationProposal;
        communityCreationProposal = getCreationProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - communityCreationProposal.date);

        require(
            (communityCreationProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= (7 * 24 * 3600)),
            "just proposal creator can cancel proposal"
        );

        deleteCommunityCreationProposal(cancelProposalRequest.proposalId);
    }

    function CreateCommunity(Community calldata community) external {
        uint founderIndex;
        bool result;
        (founderIndex, result) = getIdOfFounders(community, msg.sender);
        require(result == true, "creator should be one of founders");
        require((keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeApproval))) ||
            (keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeOpenToJoin))) ||
            (keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeStaking)))
            , "Wrong entry type of the community");
        require((keccak256(abi.encodePacked(community.entryType)) != keccak256(abi.encodePacked(CommunityEntryTypeStaking))) ||
            (community.entryConditionCount != 0), "entry conditions should be defined by staking option");
        require((keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeStaking))) ||
            (community.entryConditionCount == 0), "entry conditions should not be defined by not staking option");
        uint foundersSharesSum = 0;
        for(uint i = 0; i < community.foundersCount; i++) {
            foundersSharesSum += community.foundersShares[i];
        }
        require(foundersSharesSum == 10000, "founders shares sum shoud be 10000");// *10^4
        require(community.foundersVotingTime >= (3600 * 24), "founders Voting Time should be longer than 1 day");
        require(community.treasuryVotingTime >= (3600 * 24), "treasury Voting Time should be longer than 1 day");
        require(
            (community.foundersConsensus >= 0) && (community.foundersConsensus < 10000), 
            "founders Consensus should be between 0 and 10000"
        );
        require(
            (community.treasuryConsensus >= 0) && (community.treasuryConsensus < 10000), 
            "treasury Consensus should be between 0 and 10000"
        );

        if(keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeStaking))) {
            for(uint i = 0; i < community.entryConditionCount; i++) {
                bool isTokenExist = IManageCommunityToken(_manageCommunityTokenContractAddress).isTokenExist(community.entryConditionSymbols[i]);
                require(
                    isTokenExist, 
                    "entry conditions token with symbol does not exist"
                );
                require(community.entryConditionValues[i] > 0, "entry condition token amount should be greater than 0");
            }
        }
        
        if(community.foundersCount == 1) {
            for(uint i = 0; i < community.foundersCount; i++) {
                Member memory founder;
                founder.communityId = community.communityAddress;
                founder.memberAddress = msg.sender;
                founder.memberType = FounderMemberType;
                founder.share = community.foundersShares[i];

                ICommunityEjectMember(_ejectMemberContractAddress).updateMember(founder);
            }

            _communities[community.communityAddress] = community;
            _communityIds.push(community.communityAddress);
            _communityCounter++;            
            return;
        }

        uint proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _communityCPCounter)));
        _communityCPs[proposalId].proposal = community;
        _communityCPs[proposalId].proposal.date = block.timestamp;
        _communityCPs[proposalId].proposalCreator = msg.sender;
        _communityCPs[proposalId].proposalId = proposalId;
        
        for(uint i = 0; i < community.foundersCount; i++) {
            _communityCPs[proposalId].approvals[i] = Vote(false, false);
        }
        _communityCPs[proposalId].date = block.timestamp;
        _communityCPIds.push(proposalId);
        _communityCPCounter++;
    }

    function VoteCreationProposal(VoteProposal calldata voteProposal) external {
        require(voteProposal.communityId != address(0), "community id is not valid");
        require(voteProposal.proposalId != 0, "community creation proposal id is not valid");

        CommunityCreationProposal memory communityCP;
        communityCP = getCreationProposal(voteProposal.proposalId);
        
        uint voterId;
        bool result;
        (voterId, result) = getIdOfFounders(communityCP.proposal, msg.sender);
        require(result, "voter should be founder");
        require(communityCP.approvals[voterId].IsVoted == false, "voter can not vote second time");

        uint creationDiff = (block.timestamp - communityCP.date);
        require(creationDiff <= (7*24*3600), "voting time is over");

        if(!voteProposal.decision) {
            deleteCommunityCreationProposal(voteProposal.proposalId);
            return;
        }

        communityCP.approvals[voterId].IsVoted = true;
        communityCP.approvals[voterId].Vote = true;
        
        bool creationAppproved = true;

        for(uint i = 0; i < communityCP.proposal.foundersCount; i++) {
            if(communityCP.approvals[i].Vote == false){
                creationAppproved = false;
                break;
            }
        }

        if(creationAppproved) {
            communityCP.date = block.timestamp;

            for(uint i = 0; i < communityCP.proposal.foundersCount; i++) {
                Member memory founder;
                founder.communityId = communityCP.proposal.communityAddress;
                founder.memberAddress = communityCP.proposal.founders[i];
                founder.memberType = FounderMemberType;
                founder.share = communityCP.proposal.foundersShares[i];

                ICommunityEjectMember(_ejectMemberContractAddress).updateMember(founder);
            }

            _communities[voteProposal.communityId] = communityCP.proposal;
            _communityIds.push(voteProposal.communityId);
            _communityCounter++;

            deleteCommunityCreationProposal(voteProposal.proposalId);
            return;
        }

        updateCommunityCreationProposal(communityCP);        
    }
}