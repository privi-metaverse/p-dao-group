// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/IManageCommunityToken.sol";

import "./constant.sol";

contract CommunityAllocation {
    mapping(uint => AllocationProposal) _allocationProposals;
    mapping(uint => CommunityAllocationStreamingRequest) _communityASRs;

    uint[] _allocationProposalIds;
    uint[] _communityASRIds;

    uint _allocationProposalCount;
    uint _communityASRCount;

    address _daoContractAddress;
    address _manageCommunityTokenContractAddress;

    constructor(address daoContractAddress, address manageCommunityTokenContractAddress) {
        _daoContractAddress = daoContractAddress;
        _manageCommunityTokenContractAddress = manageCommunityTokenContractAddress;
    }

    function getAllocationProposalCount() public view returns(uint) {
        return _allocationProposalCount;
    }

    function getAllocationProposalIds(uint index) public view returns(uint) {
        return _allocationProposalIds[index];
    }

    function getAllocationProposal(uint proposalId) public view returns(AllocationProposal memory) {
        require(
            _allocationProposals[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _allocationProposals[proposalId];
    }

    function getAllocationSum(AllocationProposal memory allocationProposal) public pure returns(address[] memory, uint) {
        uint allocationSum;
        address[] memory allocationAddresses = new address[](allocationProposal.allocateCount);

        for(uint i = 0; i < allocationProposal.allocateCount; i++) {
            allocationSum += allocationProposal.allocateAmounts[i];
            allocationAddresses[i] = allocationProposal.allocateAddresses[i];
        }

        return (allocationAddresses, allocationSum);
    }

    function checkPrerequisitesToAllocation(AllocationProposal memory allocation, address requester) internal view {
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(allocation.communityId);
        require(community.communityAddress != address(0), "community not registered");

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, requester);
        require(result, "requester has to be the founder");

        CommunityToken memory communityToken;
        communityToken = IManageCommunityToken(_manageCommunityTokenContractAddress).getCommunityToken(community.tokenId);

        uint amountToAllocate;

        for(uint i = 0; i < allocation.allocateCount; i++) {
            amountToAllocate += allocation.allocateAmounts[i];
        }

        require(
            (communityToken.initialSupply - communityToken.airdropAmount - communityToken.allocationAmount) >= amountToAllocate,
            "number of free tokens to allocate is not enough"
        );

        for(uint i = 0; i < allocation.allocateCount; i++) {
            require(allocation.allocateAddresses[i] != address(0), "allocation address is not vaild");
        }
    }

    function updateAllocationProposal(AllocationProposal memory allocationProposal) internal {
        bool flag = false;

        for(uint i = 0; i < _allocationProposalCount; i++) {
            if(_allocationProposalIds[i] == allocationProposal.proposalId) {
                flag = true;
                break;
            }
        }

        if(!flag) {
            _allocationProposalCount++;
            _allocationProposalIds.push(allocationProposal.proposalId);
        }

        for(uint j = 0; j < 20; j++) {
            _allocationProposals[allocationProposal.proposalId].approvals[j].IsVoted = allocationProposal.approvals[j].IsVoted;
            _allocationProposals[allocationProposal.proposalId].approvals[j].Vote = allocationProposal.approvals[j].Vote;
        }

        _allocationProposals[allocationProposal.proposalId].proposalId = allocationProposal.proposalId;
        _allocationProposals[allocationProposal.proposalId].communityId = allocationProposal.communityId;
        _allocationProposals[allocationProposal.proposalId].proposalCreator = allocationProposal.proposalCreator;
        _allocationProposals[allocationProposal.proposalId].allocateCount = allocationProposal.allocateCount;

        for(uint j = 0; j < _allocationProposals[allocationProposal.proposalId].allocateCount; j++) {
            _allocationProposals[allocationProposal.proposalId].allocateAddresses.push(allocationProposal.allocateAddresses[j]);
            _allocationProposals[allocationProposal.proposalId].allocateAmounts.push(allocationProposal.allocateAmounts[j]);
        }

        _allocationProposals[allocationProposal.proposalId].date = allocationProposal.date;
    }

    function updateCommunityTokenWithNewAllocationSum(uint tokenId, AllocationProposal memory allocationProposal, bool isAdded) public
     returns(CommunityToken memory){
        CommunityToken memory  communityToken;

        communityToken = IManageCommunityToken(_manageCommunityTokenContractAddress).getCommunityToken(tokenId);

        uint allocationSum;
        (, allocationSum) = getAllocationSum(allocationProposal);

        if(isAdded) {
            communityToken.allocationAmount += allocationSum;
        } else {
            communityToken.allocationAmount -= allocationSum;
        }

        IManageCommunityToken(_manageCommunityTokenContractAddress).updateCommunityToken(communityToken);

        return communityToken;
    }

    function deleteAllocationProposal(uint proposalId) internal {
        delete _allocationProposals[proposalId]; 
    }

    function cancelAllocationProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        AllocationProposal memory proposal;
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);

        proposal = getAllocationProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - proposal.date);

        require(
            (proposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.foundersVotingTime),
            "just proposal creator can cancel proposal"
        );

        CommunityToken memory communityToken;
        communityToken  = updateCommunityTokenWithNewAllocationSum(community.tokenId, proposal, false);

        uint allocationSum;
        (, allocationSum) = getAllocationSum(proposal);

        address tokenContractAddress;

        (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(communityToken.tokenSymbol);
        require(result, "token contract address is not valid");

        IERC20(tokenContractAddress).transferFrom(community.escrowAddress, community.communityAddress, allocationSum);

        deleteAllocationProposal(cancelProposalRequest.proposalId);
    }

    function performAllocation(Community memory community, AllocationProposal memory allocationProposal, bool withEscrowTransfer) internal {
        CommunityToken memory communityToken;
        bool result;

        communityToken = IManageCommunityToken(_manageCommunityTokenContractAddress).getCommunityToken(community.tokenId);

        uint currentDate = block.timestamp;
        uint allocationSum;

        address tokenContractAddress;
        (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(communityToken.tokenSymbol);
        require(result, "token contract address is not valid");

        for(uint i = 0; i < allocationProposal.allocateCount; i++) {
            allocationSum += allocationProposal.allocateAmounts[i];
            uint transferAmount = (allocationProposal.allocateAmounts[i] * communityToken.immediateAllocationPct);
            IERC20(tokenContractAddress).transferFrom(community.escrowAddress, allocationProposal.allocateAddresses[i], transferAmount);

            //streaming
            _communityASRCount++;
            _communityASRs[_communityASRCount].communityId = community.communityAddress;
            _communityASRs[_communityASRCount].senderAddress = community.escrowAddress;
            _communityASRs[_communityASRCount].receiverAddress = allocationProposal.allocateAddresses[i];
            _communityASRs[_communityASRCount].tokenSymbol = communityToken.tokenSymbol;
            _communityASRs[_communityASRCount].frequency = 1;
            _communityASRs[_communityASRCount].amount = communityToken.vestedAllocationPct;
            _communityASRs[_communityASRCount].startingDate = currentDate;
            _communityASRs[_communityASRCount].endingDate = (currentDate + communityToken.vestingTime*30*24*60*60); 
        }

        if(withEscrowTransfer) {
            IERC20(tokenContractAddress).transferFrom(community.communityAddress, community.escrowAddress, allocationSum);
        }
    }

    function transferAllocationTokensToEscrow(AllocationProposal memory allocationProposal, Community memory community) internal {
        CommunityToken memory allocationToken;
        address tokenContractAddress;
        uint allocationAmount;
        bool result;

        for(uint i = 0; i < allocationProposal.allocateCount; i++) {
            allocationAmount += allocationProposal.allocateAmounts[i];
        }

        allocationToken = IManageCommunityToken(_manageCommunityTokenContractAddress).getCommunityToken(community.tokenId);

        (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(allocationToken.tokenSymbol);
        require(result, "token contract address is not valid");

        IERC20(tokenContractAddress).transferFrom(community.communityAddress, community.escrowAddress, allocationAmount);
    }

    function AllocateTokenProposal(AllocationProposal calldata allocationProposalInput) external {
        require(
            allocationProposalInput.allocateCount > 0, 
            "at least one address is required to create allocate token proposal"
        );
        for(uint i = 0; i < allocationProposalInput.allocateCount; i++) {
            require(allocationProposalInput.allocateAmounts[i] > 0, "amount cannot be negative or zero");
        }

        checkPrerequisitesToAllocation(allocationProposalInput, msg.sender);

        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(allocationProposalInput.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "allocation creator should be founder");

        AllocationProposal memory allocationProposal;

        for(uint i = 0; i < community.foundersCount; i++) {
            allocationProposal.approvals[i].IsVoted = false;
            allocationProposal.approvals[i].IsVoted = false;
        }

        allocationProposal.date = block.timestamp;

        if((community.foundersCount == 1) && (community.foundersShares[founderIndex] > 0)) {
            performAllocation(community, allocationProposal, true);
            updateCommunityTokenWithNewAllocationSum(community.tokenId, allocationProposalInput, true);
            return;
        }

        allocationProposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, allocationProposal.date, _allocationProposalCount + 1)));
        allocationProposal.communityId = allocationProposalInput.communityId;
        allocationProposal.allocateAddresses = allocationProposalInput.allocateAddresses;
        allocationProposal.allocateAmounts = allocationProposalInput.allocateAmounts;
        allocationProposal.allocateCount = allocationProposalInput.allocateCount;
        allocationProposal.proposalCreator = msg.sender;

        updateAllocationProposal(allocationProposal);
        
        updateCommunityTokenWithNewAllocationSum(community.tokenId, allocationProposalInput, true);
        transferAllocationTokensToEscrow(allocationProposal, community);
    }

    function VoteAllocateTokenProposal(VoteProposal calldata voteAllocationInput) external {
        AllocationProposal memory allocationProposal;
        Community memory community;
        uint founderIndex;
        uint creationDateDiff;
        uint consensusScoreRequirement;
        uint consensusScore;
        uint negativeConsensusScore;
        bool result;

        allocationProposal = getAllocationProposal(voteAllocationInput.proposalId);

        community = IPRIVIDAO(_daoContractAddress).getCommunity(voteAllocationInput.communityId);

        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "creator should be founder");
        require(!allocationProposal.approvals[founderIndex].IsVoted, "voter can not vote second time");

        creationDateDiff = (block.timestamp - allocationProposal.date);
        require(creationDateDiff <= community.foundersVotingTime, "voting time is over");

        allocationProposal.approvals[founderIndex].IsVoted = true;
        allocationProposal.approvals[founderIndex].Vote = voteAllocationInput.decision;

        consensusScoreRequirement = community.foundersConsensus;
        for(uint i = 0; i < community.foundersCount; i++) {
            if(allocationProposal.approvals[i].Vote) {
                consensusScore += community.foundersShares[i];
            }
            
            if((!allocationProposal.approvals[i].Vote) && (allocationProposal.approvals[i].IsVoted)) {
                negativeConsensusScore += community.foundersShares[i];
            }
        }

        if(consensusScore >= consensusScoreRequirement) {
            performAllocation(community, allocationProposal, false);
            deleteAllocationProposal(allocationProposal.proposalId);                                            
            return;
        }

        if(negativeConsensusScore > (10000 - consensusScoreRequirement)) { // *10^4
            deleteAllocationProposal(allocationProposal.proposalId);

            CommunityToken memory commmunityToken = updateCommunityTokenWithNewAllocationSum(community.tokenId, allocationProposal, false);
            uint allocationSum;
            (, allocationSum) = getAllocationSum(allocationProposal);

            address tokenContractAddress;
            (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
                .getTokenContractAddress(commmunityToken.tokenSymbol);
            require(result, "token contract address is not valid");

            IERC20(tokenContractAddress).transferFrom(community.escrowAddress, community.communityAddress, allocationSum);
            return;
        }

        updateAllocationProposal(allocationProposal);
    }
}