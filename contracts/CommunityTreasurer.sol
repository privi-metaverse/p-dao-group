// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/ICommunityEjectMember.sol";

import "./constant.sol";

contract CommunityTreasurer {
    mapping(uint => ManageTreasurerProposal) _treasurerProposals;

    uint[] _treasurerProposalIds;
    uint _treasurerProposalCount;

    address _daoContractAddress;
    address _ejectMemberContractAddress;

    constructor(address daoContractAddress, address ejectMemberContractAddress) {
        _daoContractAddress = daoContractAddress;
        _ejectMemberContractAddress = ejectMemberContractAddress;
    }

    function getTreasurerProposalCount() public view returns(uint) {
        return _treasurerProposalCount;
    }

    function getTreasurerProposalIds(uint index) public view returns(uint) {
        return _treasurerProposalIds[index];
    }

    function getTreasurerProposal(uint proposalId) public view returns(ManageTreasurerProposal memory) {
        require(
            _treasurerProposals[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _treasurerProposals[proposalId];
    }

    function checkPrerequisitesToTreasurer(ManageTreasurerProposal memory treasurerProposal) internal view {
        Community memory community;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(treasurerProposal.communityId);
        require(community.communityAddress != address(0), "community not registered");

        for(uint i = 0; i < treasurerProposal.treasurerCount; i++) {
            require(treasurerProposal.treasurerAddresses[i] != address(0), "address invalid");
        }

        Member[] memory treasurers;
        uint treasurersCount;

        (treasurers, treasurersCount) = ICommunityEjectMember(_ejectMemberContractAddress).getMembersByType(community.communityAddress, TreasurerMemberType);
        require(
            (treasurersCount != 0) || (treasurerProposal.isAddingTreasurers), 
            "cannot remove treasurers as no treasurers are registered" 
        );

        if(treasurerProposal.isAddingTreasurers) {
            for(uint i = 0; i < treasurersCount; i++) {
                uint index;
                bool flag = false;
                for(uint j = 0; j < treasurerProposal.treasurerCount; j++) {
                    if(treasurerProposal.treasurerAddresses[j] == treasurers[i].memberAddress) {
                        index = j;
                        flag = true;
                        break;
                    }
                }
                require(!flag, "treasurer with address: is already registered as a treasurer");
            }
        }       
    }

    function updateTreasurerProposal(ManageTreasurerProposal memory treasurerProposal) internal {
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(treasurerProposal.communityId);

        result = false;
        for(uint i = 0; i < _treasurerProposalCount; i++) {
            if(_treasurerProposalIds[i] == treasurerProposal.proposalId) {
                result = true;
                break;
            }
        }

        if(!result) {
            _treasurerProposalCount++;
            _treasurerProposalIds.push(treasurerProposal.proposalId);
        }
        
        _treasurerProposals[treasurerProposal.proposalId].proposalId = treasurerProposal.proposalId;
        _treasurerProposals[treasurerProposal.proposalId].communityId = treasurerProposal.communityId;
        _treasurerProposals[treasurerProposal.proposalId].proposalCreator = treasurerProposal.proposalCreator;
        _treasurerProposals[treasurerProposal.proposalId].treasurerCount = treasurerProposal.treasurerCount;
        _treasurerProposals[treasurerProposal.proposalId].isAddingTreasurers = treasurerProposal.isAddingTreasurers;
        _treasurerProposals[treasurerProposal.proposalId].date = treasurerProposal.date;

        for(uint i = 0; i < community.foundersCount; i++) {
            _treasurerProposals[treasurerProposal.proposalId].approvals[i].IsVoted = treasurerProposal.approvals[i].IsVoted;
            _treasurerProposals[treasurerProposal.proposalId].approvals[i].Vote = treasurerProposal.approvals[i].Vote;
        }

        _treasurerProposals[treasurerProposal.proposalId].treasurerAddresses = treasurerProposal.treasurerAddresses;
    }

    function deleteTreasurerProposal(uint proposalId) internal {
        delete _treasurerProposals[proposalId];
    }

    function cancelTreasurerProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        ManageTreasurerProposal memory treasurerProposal;
        Community memory community;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);

        treasurerProposal = getTreasurerProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - treasurerProposal.date);

        require(
            (treasurerProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.foundersVotingTime),
            "just proposal creator can cancel proposal"
        );

        deleteTreasurerProposal(cancelProposalRequest.proposalId);
    }

    function CreateTreasurerProposal(ManageTreasurerProposal calldata treasurerProposalInput) external {
        checkPrerequisitesToTreasurer(treasurerProposalInput);
        
        ManageTreasurerProposal memory treasurerProposal;
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(treasurerProposalInput.communityId);

        for(uint i = 0; i< community.foundersCount; i++) {
            treasurerProposal.approvals[i].IsVoted = false;
            treasurerProposal.approvals[i].Vote = false;
        }

        treasurerProposal.date = block.timestamp;

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "should be founder");

        if((community.foundersCount == 1) && (community.foundersShares[founderIndex] > 0)) {
            for(uint i = 0; i < treasurerProposalInput.treasurerCount; i++) {
                Member memory treasurer;
                treasurer.communityId = treasurerProposalInput.communityId;
                treasurer.memberAddress = treasurerProposalInput.treasurerAddresses[i];
                treasurer.memberType = TreasurerMemberType;

                if(treasurerProposalInput.isAddingTreasurers) {
                    ICommunityEjectMember(_ejectMemberContractAddress).updateMember(treasurer);
                } else {
                    ICommunityEjectMember(_ejectMemberContractAddress).deleteMember(treasurerProposalInput.treasurerAddresses[i], treasurerProposalInput.communityId, TreasurerMemberType);
                }
            }
            return;
        }

        treasurerProposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, treasurerProposal.date, _treasurerProposalCount + 1)));
        treasurerProposal.communityId = treasurerProposalInput.communityId;
        treasurerProposal.treasurerAddresses = treasurerProposalInput.treasurerAddresses;
        treasurerProposal.treasurerCount = treasurerProposalInput.treasurerCount;           
        treasurerProposal.proposalCreator = msg.sender;
        treasurerProposal.isAddingTreasurers = treasurerProposalInput.isAddingTreasurers;

        updateTreasurerProposal(treasurerProposal);
    }

    function VoteTreasurerProposal(VoteProposal calldata voteTreasurerInput) external {
        ManageTreasurerProposal memory treasurerProposal;
        Community memory community;
        bool result;

        community =  IPRIVIDAO(_daoContractAddress).getCommunity(voteTreasurerInput.communityId);

        treasurerProposal = getTreasurerProposal(voteTreasurerInput.proposalId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "voter has to be an founder of the community");
        require(!treasurerProposal.approvals[founderIndex].IsVoted, "voter can not vote second time");

        uint creationDateDiff = (block.timestamp - treasurerProposal.date);
        require(creationDateDiff <= community.foundersVotingTime, "voting time is over");

        treasurerProposal.approvals[founderIndex].IsVoted = true;
        treasurerProposal.approvals[founderIndex].Vote = voteTreasurerInput.decision;

        uint consensusScoreRequirement = community.foundersConsensus;
        uint consensusScore;
        uint negativeConsensusScore;

        for(uint i = 0; i < community.foundersCount; i++) {
            if(treasurerProposal.approvals[i].Vote) {
                consensusScore += community.foundersShares[i]; 
            }
            
            if(!treasurerProposal.approvals[i].Vote && treasurerProposal.approvals[i].IsVoted) {
                negativeConsensusScore += community.foundersShares[i];
            }
        }

        if(consensusScore >= consensusScoreRequirement) {
            for(uint i = 0; i < treasurerProposal.treasurerCount; i++) {
                Member memory treasurer;
                treasurer.communityId = treasurerProposal.communityId;
                treasurer.memberAddress = treasurerProposal.treasurerAddresses[i];
                treasurer.memberType = TreasurerMemberType;

                if(treasurerProposal.isAddingTreasurers) {
                    ICommunityEjectMember(_ejectMemberContractAddress).updateMember(treasurer);
                } else {
                    ICommunityEjectMember(_ejectMemberContractAddress).deleteMember(treasurerProposal.treasurerAddresses[i], treasurerProposal.communityId, TreasurerMemberType);
                }
            }

            deleteTreasurerProposal(treasurerProposal.proposalId);
            return;
        }

        if(negativeConsensusScore > (10000 - consensusScoreRequirement)) { // *10^4
            deleteTreasurerProposal(treasurerProposal.proposalId);
            return;
        }

        updateTreasurerProposal(treasurerProposal);
    }
}