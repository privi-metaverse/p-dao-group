// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/IManageCommunityToken.sol";
import "./interfaces/ICommunityEjectMember.sol";

import "./constant.sol";

contract CommunityTransfer {
    mapping(uint => TransferProposal) _transferProposals;

    uint[] _transferProposalIds;
    uint _transferProposalCount;

    address _daoContractAddress;
    address _manageCommunityTokenContractAddress;
    address _ejectMemberContractAddress;

    event consensusScoreGenerated(uint indexed);

    constructor(address daoContractAddress, address manageCommunityTokenContractAddress,
        address ejectMemberContractAddress) {
        _daoContractAddress = daoContractAddress;
        _manageCommunityTokenContractAddress = manageCommunityTokenContractAddress;
        _ejectMemberContractAddress = ejectMemberContractAddress;
    }

    function getTransferProposalCount() public view returns(uint) {
        return _transferProposalCount;
    }

    function getTransferProposalIds(uint index) public view returns(uint) {
        return _transferProposalIds[index];
    }

    function getTransferProposal(uint proposalId) public view returns(TransferProposal memory) {
        require(
            _transferProposals[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _transferProposals[proposalId];
    }

    function updateTransferProposal(TransferProposal memory tp) internal {
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(tp.communityId);

        result = false;
        for(uint i = 0; i < _transferProposalCount; i++) {
            if(_transferProposalIds[i] == tp.proposalId) {
                result = true;
                break;
            }
        }

        if(!result) {
            _transferProposalCount++;
            _transferProposalIds.push(tp.proposalId);
        }

        _transferProposals[tp.proposalId].proposalId = tp.proposalId;
        _transferProposals[tp.proposalId].communityId = tp.communityId;
        _transferProposals[tp.proposalId].proposalCreator = tp.proposalCreator;

        _transferProposals[tp.proposalId].proposal = tp.proposal;
        _transferProposals[tp.proposalId].date = tp.date;

        for(uint i = 0; i < community.foundersCount; i++) {
            _transferProposals[tp.proposalId].approvals[i].IsVoted = tp.approvals[i].IsVoted;
            _transferProposals[tp.proposalId].approvals[i].Vote = tp.approvals[i].Vote;
        }
    }

    function deleteTransferProposal(uint proposalId) internal {
        delete _transferProposals[proposalId];
    }

    function cancelTransferProposal(CancelProposalRequest calldata cancelProposalRequest) external{
        TransferProposal memory transferProposal;
        Community memory community;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);

        transferProposal = getTransferProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - transferProposal.date);

        require(
            (transferProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.treasuryVotingTime),
            "just proposal creator can cancel proposal"
        );

        IERC20(transferProposal.proposal.tokenContractAddress)
            .transferFrom(community.escrowAddress, community.communityAddress, transferProposal.proposal.amount);
        
        deleteTransferProposal(cancelProposalRequest.proposalId);
    }

    function CreateTransferProposal(TransferProposalRequest calldata transferProposalRequest) external {
        address tokenContractAddress;
        Community memory community;
        bool result;
        (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(transferProposalRequest.tokenSymbol);
        require(result, "get token contract address failed with error");

        community = IPRIVIDAO(_daoContractAddress).getCommunity(transferProposalRequest.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        bool treasurerFlag;
        Member[] memory treasurers;
        uint treasurerCount;
        (treasurers, treasurerCount) = ICommunityEjectMember(_ejectMemberContractAddress).getMembersByType(transferProposalRequest.communityId, TreasurerMemberType);
        require(treasurerCount > 0, "at least one treasurer required in community");


        for(uint i = 0; i < treasurerCount; i++) {
            if(treasurers[i].memberAddress == msg.sender) {
                treasurerFlag = true;
                break;
            }
        }

        require(
            (result) || (treasurerFlag), 
            "just founders or treasurers can create transfer proposal."
        );

        uint balance = IERC20(tokenContractAddress).balanceOf(community.communityAddress);
        require(balance >= transferProposalRequest.amount, "insufficient funds");

        if(treasurerCount == 1) {
            IERC20(tokenContractAddress).transferFrom(community.communityAddress, community.escrowAddress, transferProposalRequest.amount);
            IERC20(tokenContractAddress).transferFrom(community.escrowAddress, transferProposalRequest.to, transferProposalRequest.amount);
            return;
        }

        TransferProposal memory transferProposal;
        TransferRequest memory transferRequest;

        transferRequest.transferType = "Community_Transfer";
        transferRequest.tokenContractAddress = tokenContractAddress;
        transferRequest.from = community.escrowAddress;
        transferRequest.to = transferProposalRequest.to;
        transferRequest.amount = transferProposalRequest.amount;

        transferProposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _transferProposalCount + 1)));
        transferProposal.communityId = transferProposalRequest.communityId;
        transferProposal.proposalCreator = msg.sender;
        transferProposal.proposal = transferRequest;
        transferProposal.date = block.timestamp;

        for(uint i = 0; i < community.foundersCount; i++) {
            transferProposal.approvals[i].IsVoted = false;
            transferProposal.approvals[i].Vote = false;
        }

        IERC20(tokenContractAddress).transferFrom(community.communityAddress, community.escrowAddress, transferProposalRequest.amount);
        updateTransferProposal(transferProposal);
    }

    function  VoteTransferProposal(VoteProposal calldata voteProposal) external {
        Community memory community;
        TransferProposal memory transferProposal;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(voteProposal.communityId);

        transferProposal = getTransferProposal(voteProposal.proposalId);

        Member[] memory treasurers;
        uint treasurerCount;

        (treasurers, treasurerCount) = ICommunityEjectMember(_ejectMemberContractAddress).getMembersByType(voteProposal.communityId, TreasurerMemberType);
        require(treasurerCount > 0, "at least one treasurer required in community");

        uint treasurerIndex;
        result = false;
        for(uint i = 0; i < treasurerCount; i++) {
            if(treasurers[i].memberAddress == msg.sender) {
                treasurerIndex = i;
                result = true;
                break;
            }
        }

        require(result, "just treasurers can vote on transfer proposal.");

        require(!transferProposal.approvals[treasurerIndex].IsVoted, "voter can not vote second time");

        uint creationDateDiff = block.timestamp - transferProposal.date;
        require(creationDateDiff <= community.treasuryVotingTime, "voting time is over");

        transferProposal.approvals[treasurerIndex].IsVoted = true;
        transferProposal.approvals[treasurerIndex].Vote = voteProposal.decision;

        uint consensusScoreRequirement = community.treasuryConsensus;
        uint consensusScore;
        uint negativeConsensusScore;

        for(uint i = 0; i < treasurerCount; i++) {
            if(transferProposal.approvals[i].Vote) {
                consensusScore += (10000 / treasurerCount);
            }

            if((!transferProposal.approvals[i].Vote) && (transferProposal.approvals[i].IsVoted)) {
                negativeConsensusScore += (10000 / treasurerCount);
            }
        }

        emit consensusScoreGenerated(consensusScore);

        if(consensusScore >= consensusScoreRequirement) {
            TransferRequest memory proposal = transferProposal.proposal;
            IERC20(proposal.tokenContractAddress).transferFrom(proposal.from, proposal.to, proposal.amount);
            deleteTransferProposal(transferProposal.proposalId);
            return;
        }

        if(negativeConsensusScore > (10000 - consensusScoreRequirement)) { // *10^4
            deleteTransferProposal(transferProposal.proposalId);

            TransferRequest memory proposal = transferProposal.proposal;
            IERC20(proposal.tokenContractAddress).transferFrom(community.escrowAddress, community.communityAddress, proposal.amount);
            return;
        }

        updateTransferProposal(transferProposal);
    }  
}