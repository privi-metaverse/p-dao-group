// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/IERC20TokenExchange.sol";
import "./interfaces/ICommunityEjectMember.sol";

import "./constant.sol";

contract CommunityBuying {
    mapping(uint => BuyingProposal) _buyingProposals;

    uint[] _buyingProposalIds;
    uint _buyingProposalCount;

    address _daoContractAddress;
    address _ejectMemberContractAddress;

    constructor(address daoContractAddress, address ejectMemberContractAddress) {
        _daoContractAddress = daoContractAddress;
        _ejectMemberContractAddress = ejectMemberContractAddress;
    }

    function getBuyingProposalCount() public view returns(uint) {
        return _buyingProposalCount;
    }

    function getBuyingProposalIds(uint index) public view returns(uint) {
        return _buyingProposalIds[index];
    }

    function getBuyingProposal(uint proposalId) public view returns(BuyingProposal memory) {
        require(
            _buyingProposals[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _buyingProposals[proposalId];
    }

    function updateBuyingProposal(BuyingProposal memory bp) internal {
        Community memory community;
        bool flag = false;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(bp.communityId);

        for(uint i = 0; i < _buyingProposalCount; i++) {
            if(_buyingProposalIds[i] == bp.proposalId) {
                flag = true;
                break;
            }
        }

        if(!flag) {
            _buyingProposalCount++;
            _buyingProposalIds.push(bp.proposalId);
        }

        _buyingProposals[bp.proposalId].proposalId = bp.proposalId;
        _buyingProposals[bp.proposalId].communityId = bp.communityId;
        _buyingProposals[bp.proposalId].proposalCreator = bp.proposalCreator;
        _buyingProposals[bp.proposalId].date = bp.date;
        _buyingProposals[bp.proposalId].proposal.exchangeId = bp.proposal.exchangeId;
        _buyingProposals[bp.proposalId].proposal.offerId = bp.proposal.offerId;

        for(uint i = 0; i < community.foundersCount; i++) {
            _buyingProposals[bp.proposalId].approvals[i].IsVoted = bp.approvals[i].IsVoted;
            _buyingProposals[bp.proposalId].approvals[i].Vote = bp.approvals[i].Vote;
        }
    }

    function deleteBuyingProposal(uint proposalId) internal {
        delete _buyingProposals[proposalId];
    }

    function cancelBuyingProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        BuyingProposal memory buyingProposal;
        Community memory community;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);

        buyingProposal = getBuyingProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - buyingProposal.date);

        require(
            (buyingProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.foundersVotingTime),
            "just proposal creator can cancel proposal"
        );

        IERC20TokenExchange.ERC20Offer memory offer;
        address exchangeContractAddress = IPRIVIDAO(_daoContractAddress).getExchangeContractAddress();
        offer = IERC20TokenExchange(exchangeContractAddress).getErc20OfferById(buyingProposal.proposal.offerId);

        IERC20TokenExchange.ERC20Exchange memory exchange;
        exchange = IERC20TokenExchange(exchangeContractAddress).getErc20ExchangeById(offer.exchangeId);

        IERC20(exchange.offerTokenAddress)
            .transferFrom(community.escrowAddress, community.communityAddress, offer.amount);

        deleteBuyingProposal(cancelProposalRequest.proposalId);
    }

    function MakeBuyingProposal(BuyingProposalRequest calldata buyingProposalRequest) external {
        require(buyingProposalRequest.price > 0, "price cannot be zero");
        require(buyingProposalRequest.amount > 0, "amount cannot be zero");

        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(buyingProposalRequest.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
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
                (result) || (treasurerFlag) || (memberFlag),
                "just community members can create buying proposal."
            );
        }

        address exchangeContractAddress = IPRIVIDAO(_daoContractAddress).getExchangeContractAddress();

        require(exchangeContractAddress != address(0), "should be set exchange contract address");

        IERC20TokenExchange.ERC20Exchange memory exchange;
        IERC20TokenExchange.ERC20Offer memory offer;

        exchange = IERC20TokenExchange(exchangeContractAddress).getErc20ExchangeById(buyingProposalRequest.exchangeId);
        offer = IERC20TokenExchange(exchangeContractAddress).getErc20OfferById(buyingProposalRequest.offerId);

        require(
            keccak256(abi.encodePacked(offer.offerType)) == keccak256(abi.encodePacked("SELL")), 
            "trying to buy from a non selling order"
        );
        require(
            exchange.offerTokenAddress == buyingProposalRequest.offerTokenAddress, 
            "incorrect offer token"
        );

        uint balance = IERC20(buyingProposalRequest.offerTokenAddress).balanceOf(community.communityAddress);
        require(balance >=  buyingProposalRequest.amount, "insufficient founds");
        
        uint buyingProposalRequestAmount = buyingProposalRequest.amount;
        IERC20(exchange.offerTokenAddress).transferFrom(community.communityAddress, community.escrowAddress, buyingProposalRequestAmount);

        IERC20TokenExchange.OfferRequest memory offerRequest;
        offerRequest.exchangeId = buyingProposalRequest.exchangeId;
        offerRequest.offerId = buyingProposalRequest.offerId;

        BuyingProposal memory buyingProposal;
        buyingProposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _buyingProposalCount + 1)));
        buyingProposal.communityId = buyingProposalRequest.communityId;
        buyingProposal.proposalCreator = msg.sender;
        buyingProposal.proposal = offerRequest;
        buyingProposal.date = block.timestamp;

        for(uint i = 0; i < community.foundersCount; i++) {
            buyingProposal.approvals[i].IsVoted = false;
            buyingProposal.approvals[i].Vote = false;
        }

        if(community.foundersCount == 1) {
            IERC20TokenExchange(exchangeContractAddress)
                .BuyERC20TokenFromOffer(buyingProposal.proposal, buyingProposal.proposalCreator);
            return;
        }

        updateBuyingProposal(buyingProposal);
    }

    function VoteBuyingProposal(VoteProposal calldata voteProposal) external {
        BuyingProposal memory buyingProposal;
        Community memory community;
        bool result;

        buyingProposal = getBuyingProposal(voteProposal.proposalId);

        community =  IPRIVIDAO(_daoContractAddress).getCommunity(buyingProposal.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "just founders can vote on buying order proposal.");
        require(!buyingProposal.approvals[founderIndex].IsVoted, "voter can not vote second time");

        IERC20TokenExchange.ERC20Exchange memory exchange;
        IERC20TokenExchange.ERC20Offer memory offer;

        address exchangeContractAddress = IPRIVIDAO(_daoContractAddress).getExchangeContractAddress();

        exchange = IERC20TokenExchange(exchangeContractAddress).getErc20ExchangeById(buyingProposal.proposal.exchangeId);
        offer = IERC20TokenExchange(exchangeContractAddress).getErc20OfferById(buyingProposal.proposal.offerId);

        uint balance = IERC20(exchange.offerTokenAddress).balanceOf(community.escrowAddress);
        require(balance >= offer.amount, "insufficient founds");

        uint creationDateDiff = (block.timestamp - buyingProposal.date);
        require(creationDateDiff <= community.foundersVotingTime, "voting time is over");

        buyingProposal.approvals[founderIndex].IsVoted = true;
        buyingProposal.approvals[founderIndex].Vote = voteProposal.decision;

        uint consensusScoreRequirement = community.foundersConsensus;
        uint consensusScore;
        uint negativeConsensusScore;

        for(uint i = 0; i < community.foundersCount; i++) {
            if(buyingProposal.approvals[i].Vote) {
                consensusScore += community.foundersShares[i];
            }

            if(!buyingProposal.approvals[i].Vote && buyingProposal.approvals[i].IsVoted) {
                negativeConsensusScore += community.foundersShares[i];
            }
        }

        if(consensusScore >= consensusScoreRequirement) {
            IERC20TokenExchange(exchangeContractAddress)
                .BuyERC20TokenFromOffer(buyingProposal.proposal, buyingProposal.proposalCreator);
            deleteBuyingProposal(buyingProposal.proposalId);
            return;
        }

        if(negativeConsensusScore > (10000 - consensusScoreRequirement)) { // *10^4
            deleteBuyingProposal(buyingProposal.proposalId);
            require(
                keccak256(abi.encodePacked(offer.offerType)) == keccak256(abi.encodePacked("SELL")), 
                "trying to buy from a non selling order"
            );

            IERC20(exchange.offerTokenAddress).transferFrom(community.escrowAddress, community.communityAddress, offer.amount);
            return;
        }

        updateBuyingProposal(buyingProposal);
    }
}