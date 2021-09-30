// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/IManageCommunityToken.sol";
import "./interfaces/ICommunityEjectMember.sol";

import "./constant.sol";

contract CommunityBid {
    mapping(uint => BidProposal) _bidProposals;

    uint[] _bidProposalIds;

    uint _bidProposalCount;

    address _daoContractAddress;
    address _manageCommunityTokenContractAddress;
    address _ejectMemberContractAddress;

    constructor(address daoContractAddress, address manageCommunityTokenContractAddress,
        address ejectMemberContractAddress) {
        _daoContractAddress = daoContractAddress;
        _manageCommunityTokenContractAddress = manageCommunityTokenContractAddress;
        _ejectMemberContractAddress = ejectMemberContractAddress;
    }

    function getBidProposalCount() public view returns(uint) {
        return _bidProposalCount;
    }

    function getBidProposalIds(uint index) public view returns(uint) {
        return _bidProposalIds[index];
    }

    function getBidProposal(uint proposalId) public view returns(BidProposal memory) {
        require(
            _bidProposals[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _bidProposals[proposalId];
    }

    function updateBidProposal(BidProposal memory bp) internal {
        Community memory community;
        bool flag = false;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(bp.communityId);

        for(uint i = 0; i < _bidProposalCount; i++) {
            if(_bidProposalIds[i] == bp.proposalId) {
                flag = true;
                break;
            }
        }

        if(!flag) {
            _bidProposalCount++;
            _bidProposalIds.push(bp.proposalId);
        }

        _bidProposals[bp.proposalId].proposalId = bp.proposalId;
        _bidProposals[bp.proposalId].communityId = bp.communityId;
        _bidProposals[bp.proposalId].proposalCreator = bp.proposalCreator;
        _bidProposals[bp.proposalId].date = bp.date;

        for(uint i = 0; i < community.foundersCount; i++) {
            _bidProposals[bp.proposalId].approvals[i].IsVoted = bp.approvals[i].IsVoted;
            _bidProposals[bp.proposalId].approvals[i].Vote = bp.approvals[i].Vote;
        }

        _bidProposals[bp.proposalId].proposal.mediaSymbol = bp.proposal.mediaSymbol;
        _bidProposals[bp.proposalId].proposal.tokenSymbol = bp.proposal.tokenSymbol;
        _bidProposals[bp.proposalId].proposal._address = bp.proposal._address;
        _bidProposals[bp.proposalId].proposal.fromAddress = bp.proposal.fromAddress;
        _bidProposals[bp.proposalId].proposal.amount = bp.proposal.amount;
    }

    function deleteBidProposal(uint proposalId) internal {
        delete _bidProposals[proposalId];
    }

    function cancelBidProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        BidProposal memory bidProposal;
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);

        bidProposal = getBidProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - bidProposal.date);

        require(
            (bidProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.treasuryVotingTime),
            "just proposal creator can cancel proposal"
        );

        address tokenContractAddress;

        (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(bidProposal.proposal.tokenSymbol);
        require(result, "token contract address is not valid");

        IERC20(tokenContractAddress).transferFrom(community.escrowAddress, community.communityAddress, bidProposal.proposal.amount);

        deleteBidProposal(cancelProposalRequest.proposalId);
    }

    function PlaceBidProposal(PlaceBidRequest calldata placeBidProposal) external {
        require(placeBidProposal.amount > 0, "amount can't be lower than zero");

        Community memory community;
        bool flag;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(placeBidProposal.communityId);

        uint founderIndex;
        (founderIndex, flag) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);

        {
            bool treasurerFlag;
            bool memberFlag;

            Member[] memory treasurers;
            uint treasurerCount;

            (treasurers, treasurerCount) = ICommunityEjectMember(_ejectMemberContractAddress).getMembersByType(community.communityAddress, TreasurerMemberType);
            for(uint i = 0; i < treasurerCount; i++) {
                if(treasurers[i].memberAddress == msg.sender) {
                    treasurerFlag = true;
                    break;
                }
            }
            
            Member[] memory members;
            uint memberCount;

            (members, memberCount)= ICommunityEjectMember(_ejectMemberContractAddress).getMembers(community.communityAddress);
            for(uint i = 0; i < memberCount; i++) {
                if(members[i].memberAddress == msg.sender) {
                    memberFlag == true;
                    break;
                }
            }

            require(
                (flag) || (treasurerFlag) || (memberFlag),
                "just community members can create bid proposal."
            );
        }

        // IIncreasingPriceERC721Auction.Auction memory _auction;
        // bool canBid = false;
        address aunctionContractAddress = IPRIVIDAO(_daoContractAddress).getAuctionContractAddress();
        
        // (_auction, canBid) = IIncreasingPriceERC721Auction(aunctionContractAddress)
        //     .getAuctionsByPartialCompositeKey('mediaSymbol', 'tokenSymbol');
        // require(canBid, "not auction period");

        address tokenContractAddress;

        (tokenContractAddress, flag) = IManageCommunityToken(_manageCommunityTokenContractAddress)
            .getTokenContractAddress(placeBidProposal.tokenSymbol);
        require(flag, "token contract address is not valid");

        uint balance = IERC20(tokenContractAddress).balanceOf(community.communityAddress);
        require(balance >= placeBidProposal.amount, "insufficient founds");

        IERC20(tokenContractAddress).transferFrom(community.communityAddress, community.escrowAddress, placeBidProposal.amount);

        IIncreasingPriceERC721Auction.PlaceBidRequest memory placeBidRequest;
        placeBidRequest.mediaSymbol = placeBidProposal.mediaSymbol;
        placeBidRequest.tokenSymbol = placeBidProposal.tokenSymbol;
        placeBidRequest._address = community.communityAddress;
        placeBidRequest.amount = placeBidProposal.amount;
        placeBidRequest.fromAddress  = community.escrowAddress;

        
        BidProposal memory bidProposal;
        bidProposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _bidProposalCount + 1)));
        bidProposal.communityId = placeBidProposal.communityId;
        bidProposal.proposalCreator = msg.sender;
        bidProposal.proposal = placeBidRequest;
        bidProposal.date = block.timestamp;

        for(uint i = 0; i < community.foundersCount; i++) {
            bidProposal.approvals[i].IsVoted = false;
            bidProposal.approvals[i].Vote = false;
        }

        if(community.foundersCount == 1) {
            IIncreasingPriceERC721Auction(aunctionContractAddress)
                .placeBid(bidProposal.proposal);
            return;
        }
        
        updateBidProposal(bidProposal);
    }

    function VotePlaceBidProposal(VoteProposal calldata voteProposal) external {
        BidProposal memory bidProposal;
        Community memory community;
        bool result;

        bidProposal = getBidProposal(voteProposal.proposalId);

        community = IPRIVIDAO(_daoContractAddress).getCommunity(bidProposal.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "should be founder");
        require(!bidProposal.approvals[founderIndex].IsVoted, "voter can not vote second time");

        uint creationDateDiff = (block.timestamp - bidProposal.date);
        require(creationDateDiff <= community.foundersVotingTime, "voting time is over");

        bidProposal.approvals[founderIndex].IsVoted = true;
        bidProposal.approvals[founderIndex].Vote = voteProposal.decision;

        uint consensusScoreRequirement = community.foundersConsensus;
        uint consensusScore;
        uint negativeConsensusScore;

        for(uint i = 0; i < community.foundersCount; i++) {
            if(bidProposal.approvals[i].Vote) {
                consensusScore += community.foundersShares[i];
            }

            if(!bidProposal.approvals[i].Vote && bidProposal.approvals[i].IsVoted) {
                negativeConsensusScore += community.foundersShares[i];
            }
        }

        if(consensusScore >= consensusScoreRequirement) {
            address aunctionContractAddress = IPRIVIDAO(_daoContractAddress).getAuctionContractAddress();
            IIncreasingPriceERC721Auction(aunctionContractAddress).placeBid(bidProposal.proposal);
            deleteBidProposal(bidProposal.proposalId);
            return;
        }

        if(negativeConsensusScore > (10000 - consensusScoreRequirement)) {
            deleteBidProposal(bidProposal.proposalId);

            address tokenContractAddress;

            (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
                .getTokenContractAddress(bidProposal.proposal.tokenSymbol);
            require(result, "token contract address is not valid");
            
            IERC20(tokenContractAddress).transferFrom(community.escrowAddress, community.communityAddress, bidProposal.proposal.amount);
            return;
        }

        updateBidProposal(bidProposal);
    }
}