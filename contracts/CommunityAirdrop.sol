// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/IManageCommunityToken.sol";

import "./constant.sol";

contract CommunityAirdrop {
    mapping(uint => AirdropProposal) _airdropProposals;
    uint _airdropProposalCount;

    uint[] _airdropProposalIds;

    address _daoContractAddress;
    address _manageCommunityTokenContractAddress;

    constructor(address daoContractAddress, address manageCommunityTokenContractAddress) {
        _daoContractAddress = daoContractAddress;
        _manageCommunityTokenContractAddress = manageCommunityTokenContractAddress;
    }

    function getAirdropProposalCount() public view returns(uint) {
        return _airdropProposalCount;
    }

    function getAirdropProposalIds(uint index) public view returns(uint) {
        return _airdropProposalIds[index];
    }

    function getAirdropProposal(uint proposalId) public view returns(AirdropProposal memory) {
        require(
            _airdropProposals[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _airdropProposals[proposalId];
    }

    function getAirdropSum(Airdrop memory airdrop) public pure returns(address[] memory, uint) {
        address[] memory receipments = new address[](airdrop.recipientCount);
        uint airdropSum = 0;
        for(uint i = 0; i < airdrop.recipientCount; i++) {
            receipments[i] = airdrop.recipients[i];
            airdropSum += airdrop.amounts[i];
        }
        return (receipments, airdropSum);
    }

    function checkPropertiesOfAirdrop(Airdrop memory airdrop) internal view {
        require(airdrop.communityId != address(0), "communityId has to be defined");
        require(airdrop.recipientCount != 0, "recipients cant be empty");
        for(uint i = 0; i < airdrop.recipientCount; i++) {
            require(
                airdrop.amounts[i] != 0, 
                "amount of airdrop per address has to be positive number"
            );
        }

        Community memory community;
        community = IPRIVIDAO(_daoContractAddress).getCommunity(airdrop.communityId);

        require(community.communityAddress != address(0), "community does not exist");

        uint airdropSum;
        (,airdropSum) = getAirdropSum(airdrop);
        
        CommunityToken memory communityToken;
        communityToken = IManageCommunityToken(_manageCommunityTokenContractAddress).getCommunityToken(community.tokenId);

        require(
            (communityToken.initialSupply - communityToken.allocationAmount - communityToken.airdropAmount) >= airdropSum,
            "not enough tokens to propose this airdrop"
        );
    }

    function updateCommunityTokenWithNewAirdropSum(uint tokenId, AirdropProposal memory airdropProposal, bool isAddition) public 
        returns(CommunityToken memory) {
        CommunityToken memory communityToken;
        uint airdropSum;

        communityToken = IManageCommunityToken(_manageCommunityTokenContractAddress).getCommunityToken(tokenId);
                
        (,airdropSum) = getAirdropSum(airdropProposal.proposal);
        
        if(isAddition) {
            communityToken.airdropAmount += airdropSum;
        } else {
            communityToken.airdropAmount -= airdropSum;
        }

        IManageCommunityToken(_manageCommunityTokenContractAddress).updateCommunityToken(communityToken);
        return communityToken;
    }

    function updateAirdropProposal(AirdropProposal memory airdropProposal) internal {
        bool flag = false;

        for(uint i = 0; i < _airdropProposalCount; i++) {
            if(_airdropProposalIds[i] == airdropProposal.proposalId) {
                flag = true;
            }
        }

        if(!flag) {
            _airdropProposalCount++;
            _airdropProposalIds.push(airdropProposal.proposalId);
        }

        _airdropProposals[airdropProposal.proposalId].proposalId = airdropProposal.proposalId;
        _airdropProposals[airdropProposal.proposalId].communityId = airdropProposal.communityId;
        _airdropProposals[airdropProposal.proposalId].proposalCreator = airdropProposal.proposalCreator;
        _airdropProposals[airdropProposal.proposalId].proposal = airdropProposal.proposal;
        _airdropProposals[airdropProposal.proposalId].date = airdropProposal.date;

        for(uint j = 0; j < 20; j++) {
            _airdropProposals[airdropProposal.proposalId].approvals[j].IsVoted = airdropProposal.approvals[j].IsVoted;
            _airdropProposals[airdropProposal.proposalId].approvals[j].Vote = airdropProposal.approvals[j].Vote;
        }
    }

    function deleteAirdropProposal(uint proposalId) internal {
        delete _airdropProposals[proposalId]; 
    }

    function cancelAirdropProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        AirdropProposal memory airdropProposal;
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);

        airdropProposal = getAirdropProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - airdropProposal.date);

        require(
            (airdropProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.foundersVotingTime),
            "just proposal creator can cancel proposal"
        );

        CommunityToken memory communityToken;
        communityToken  = updateCommunityTokenWithNewAirdropSum(community.tokenId, airdropProposal, false);

        uint airdropSum;
        (, airdropSum) = getAirdropSum(airdropProposal.proposal);

        address tokenContractAddress;

        (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(communityToken.tokenSymbol);
        require(result, "token contract address is not valid");
        
        IERC20(tokenContractAddress).transferFrom(community.escrowAddress, community.communityAddress, airdropSum);
        deleteAirdropProposal(cancelProposalRequest.proposalId);
    }

    function performAirdrop(Community memory community, Airdrop memory airdrop, bool withEscrowTransfer) internal {
        CommunityToken memory airdropToken;
        bool result;

        airdropToken = IManageCommunityToken(_manageCommunityTokenContractAddress).getCommunityToken(community.tokenId);

        uint airdropSum = 0;
        address tokenContractAddress;

        (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(airdropToken.tokenSymbol);
        require(result, "token contract address is not valid");

        for(uint i = 0; i < airdrop.recipientCount; i++) {
            IERC20(tokenContractAddress).transferFrom(community.escrowAddress, airdrop.recipients[i], airdrop.amounts[i]);
            airdropSum += airdrop.amounts[i];
        }

        if(withEscrowTransfer) {
            IERC20(tokenContractAddress).transferFrom(community.communityAddress, community.escrowAddress, airdropSum);
        }
    }

    function transferAirdropTokensToEscrow(Airdrop memory airdrop, Community memory community) internal {
        CommunityToken memory airdropToken;
        address tokenContractAddress;
        uint airdropAmount = 0;
        bool result;
        
        airdropToken = IManageCommunityToken(_manageCommunityTokenContractAddress).getCommunityToken(community.tokenId);

        (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(airdropToken.tokenSymbol);
        require(result, "token contract address is not valid");

        for(uint i = 0; i < airdrop.recipientCount; i++) {
            airdropAmount += airdrop.amounts[i];
        }

        IERC20(tokenContractAddress).transferFrom(community.communityAddress, community.escrowAddress, airdropAmount);
    }

    function AirdropCommunityToken(Airdrop calldata airdrop) external{
        checkPropertiesOfAirdrop(airdrop);

        AirdropProposal memory airdropProposal;

        Community memory community;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(airdrop.communityId);

        uint founderIndex;
        bool result;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "airdrop creator should be founder");

        for(uint i = 0; i < community.foundersCount; i++) {
            airdropProposal.approvals[i].IsVoted = false;
            airdropProposal.approvals[i].Vote = false;
        }

        airdropProposal.date = block.timestamp;
        airdropProposal.proposal = airdrop;

        if((community.foundersCount == 1) && (community.foundersShares[founderIndex] > 0)) {
            performAirdrop(community, airdrop, true);
            updateCommunityTokenWithNewAirdropSum(community.tokenId, airdropProposal, true);
            return;
        }

        airdropProposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _airdropProposalCount + 1)));
        airdropProposal.communityId = community.communityAddress;
        airdropProposal.proposalCreator = msg.sender;

        CommunityToken memory communityToken;

        communityToken = updateCommunityTokenWithNewAirdropSum(community.tokenId, airdropProposal, true);

        updateAirdropProposal(airdropProposal);

        transferAirdropTokensToEscrow(airdrop, community);
    }    

    function VoteAirdropProposal(VoteProposal calldata voteAirdropInput) external {
        require(voteAirdropInput.proposalId != 0, "proposalId cannot be empty");
        require(voteAirdropInput.communityId != address(0), "communityId cannot be empty");

        AirdropProposal memory airdropProposal;
        Community memory community;
        bool result;

        airdropProposal = getAirdropProposal(voteAirdropInput.proposalId);

        community = IPRIVIDAO(_daoContractAddress).getCommunity(voteAirdropInput.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        
        require(result, "only founders can vote");
        require(!airdropProposal.approvals[founderIndex].IsVoted, "voter can not vote second time");

        uint creationDateDiff = (block.timestamp - airdropProposal.date);
        
        require(creationDateDiff <= community.foundersVotingTime, "voting time is over");
        
        airdropProposal.approvals[founderIndex].IsVoted = true;
        airdropProposal.approvals[founderIndex].Vote = voteAirdropInput.decision;

        uint consensusScoreRequirement = community.foundersConsensus;
        uint consensusScore;
        uint negativeConsensusScore;

        for(uint i = 0; i < community.foundersCount; i++) {
            if(airdropProposal.approvals[i].Vote) {
                consensusScore += community.foundersShares[i];
            }

            if(!airdropProposal.approvals[i].Vote && airdropProposal.approvals[i].IsVoted) {
                negativeConsensusScore += community.foundersShares[i];
            }
        }

        if(consensusScore >= consensusScoreRequirement) {
            performAirdrop(community, airdropProposal.proposal, false);
            deleteAirdropProposal(airdropProposal.proposalId);
            return;
        }

        if(negativeConsensusScore >= (10000 - consensusScoreRequirement)) { // *10^4
            deleteAirdropProposal(airdropProposal.proposalId);
            CommunityToken memory airdropToken;
            airdropToken = updateCommunityTokenWithNewAirdropSum(community.tokenId, airdropProposal, false);
            
            uint airdropSum;
            (, airdropSum) = getAirdropSum(airdropProposal.proposal);

            address tokenContractAddress;
            (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
                .getTokenContractAddress(airdropToken.tokenSymbol);
            require(result, "token contract address is not valid");

            IERC20(tokenContractAddress).transferFrom(community.escrowAddress, community.communityAddress, airdropSum);
            return;
        }

        updateAirdropProposal(airdropProposal);
    }
}