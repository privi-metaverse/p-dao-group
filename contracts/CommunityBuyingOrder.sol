// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/IERC20TokenExchange.sol";
import "./interfaces/ICommunityEjectMember.sol";

import "./constant.sol";

contract CommunityBuyingOrder {
    mapping(uint => BuyingOrderProposal) _buyingOrderProposals;

    uint[] _buyingOrderProposalIds;
    uint _buyingOrderProposalCount;

    address _daoContractAddress;
    address _ejectMemberContractAddress;

    constructor(address daoContractAddress, address ejectMemberContractAddress) {
        _daoContractAddress = daoContractAddress;
        _ejectMemberContractAddress = ejectMemberContractAddress;
    }

    function getBuyingOrderProposalCount() public view returns(uint) {
        return _buyingOrderProposalCount;
    }

    function getBuyingOrderProposalIds(uint index) public view returns(uint) {
        return _buyingOrderProposalIds[index];
    }

    function getBuyingOrderProposal(uint proposalId) public view returns(BuyingOrderProposal memory) {
        require(
            _buyingOrderProposals[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _buyingOrderProposals[proposalId];
    }

    function updateBuyingOrderProposal(BuyingOrderProposal memory bp) internal {
        Community memory community;
        bool flag = false;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(bp.communityId);

        for(uint i = 0; i < _buyingOrderProposalCount; i++) {
            if(_buyingOrderProposalIds[i] == bp.proposalId) {
                flag = true;
                break;
            }
        }

        if(!flag) {
            _buyingOrderProposalCount++;
            _buyingOrderProposalIds.push(bp.proposalId);
        }

        _buyingOrderProposals[bp.proposalId].proposalId = bp.proposalId;
        _buyingOrderProposals[bp.proposalId].communityId = bp.communityId;
        _buyingOrderProposals[bp.proposalId].proposalCreator = bp.proposalCreator;
        _buyingOrderProposals[bp.proposalId].date = bp.date;
        _buyingOrderProposals[bp.proposalId].proposal.exchangeId = bp.proposal.exchangeId;
        _buyingOrderProposals[bp.proposalId].proposal.amount = bp.proposal.amount;
        _buyingOrderProposals[bp.proposalId].proposal.price = bp.proposal.price;

        for(uint i = 0; i < community.foundersCount; i++) {
            _buyingOrderProposals[bp.proposalId].approvals[i].IsVoted = bp.approvals[i].IsVoted;
            _buyingOrderProposals[bp.proposalId].approvals[i].Vote = bp.approvals[i].Vote;
        }
    }

    function deleteBuyingOrderProposal(uint proposalId) internal {
        delete _buyingOrderProposals[proposalId];
    }

    function cancelBuyingOrderProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        BuyingOrderProposal memory buyingOrderProposal;
        Community memory community;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);
        buyingOrderProposal = getBuyingOrderProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - buyingOrderProposal.date);

        require(
            (buyingOrderProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.foundersVotingTime),
            "just proposal creator can cancel proposal"
        );

        IERC20TokenExchange.ERC20Exchange memory exchange;
        address exchangeContractAddress = IPRIVIDAO(_daoContractAddress).getExchangeContractAddress();
        exchange = IERC20TokenExchange(exchangeContractAddress).getErc20ExchangeById(buyingOrderProposal.proposal.exchangeId);

        IERC20(exchange.offerTokenAddress)
            .transferFrom(community.escrowAddress, community.communityAddress, buyingOrderProposal.proposal.amount);

        deleteBuyingOrderProposal(cancelProposalRequest.proposalId);
    }

    function PlaceBuyingOrderProposal(BuyingProposalRequest calldata buyingProposalRequest) external {
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
                "just community members can create buyorder proposal."
            );
        }
        address exchangeContractAddress = IPRIVIDAO(_daoContractAddress).getExchangeContractAddress();

        require(exchangeContractAddress != address(0), "should be set exchange contract address");

        IERC20TokenExchange.ERC20Exchange memory exchange;

        exchange = IERC20TokenExchange(exchangeContractAddress).getErc20ExchangeById(buyingProposalRequest.exchangeId);
        require(
            exchange.offerTokenAddress == buyingProposalRequest.offerTokenAddress, 
            "incorrect offer token"
        );

        uint balance = IERC20(buyingProposalRequest.offerTokenAddress).balanceOf(community.communityAddress);
        require(balance >=  buyingProposalRequest.amount * buyingProposalRequest.price, "insufficient founds");

        uint buyingProposalRequestAmount = buyingProposalRequest.amount * buyingProposalRequest.price;
        IERC20(buyingProposalRequest.offerTokenAddress)
            .transferFrom(community.communityAddress, community.escrowAddress, buyingProposalRequestAmount);

        IERC20TokenExchange.PlaceERC20TokenOfferRequest memory placeOfferRequest;
        placeOfferRequest.exchangeId = buyingProposalRequest.exchangeId;
        placeOfferRequest.amount = buyingProposalRequest.amount;
        placeOfferRequest.price = buyingProposalRequest.price;

        BuyingOrderProposal memory buyingOrderProposal;
        buyingOrderProposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _buyingOrderProposalCount + 1)));
        buyingOrderProposal.communityId = buyingProposalRequest.communityId;
        buyingOrderProposal.proposalCreator = msg.sender;
        buyingOrderProposal.proposal = placeOfferRequest;
        buyingOrderProposal.date = block.timestamp;

        for(uint i = 0; i < community.foundersCount; i++) {
            buyingOrderProposal.approvals[i].IsVoted = false;
            buyingOrderProposal.approvals[i].Vote = false;
        }

        if((community.foundersCount == 1) && (result)) {
            IERC20TokenExchange(exchangeContractAddress)
                .PlaceERC20TokenBuyingOffer(buyingOrderProposal.proposal, buyingOrderProposal.proposalCreator);
            return;
        }

        updateBuyingOrderProposal(buyingOrderProposal);
    }

    function VoteBuyingOrderProposal(VoteProposal calldata voteProposal) external {
        BuyingOrderProposal memory buyingOrderProposal;
        Community memory community;
        bool result;

        buyingOrderProposal = getBuyingOrderProposal(voteProposal.proposalId);

        community =  IPRIVIDAO(_daoContractAddress).getCommunity(buyingOrderProposal.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "just founders can vote on buying order proposal.");
        require(!buyingOrderProposal.approvals[founderIndex].IsVoted, "voter can not vote second time");

        IERC20TokenExchange.ERC20Exchange memory exchange;
        address exchangeContractAddress = IPRIVIDAO(_daoContractAddress).getExchangeContractAddress();
        exchange = IERC20TokenExchange(exchangeContractAddress).getErc20ExchangeById(buyingOrderProposal.proposal.exchangeId);

        uint balance = IERC20(exchange.offerTokenAddress).balanceOf(community.escrowAddress);
        require(balance >= buyingOrderProposal.proposal.amount * buyingOrderProposal.proposal.price, "insufficient founds");

        uint creationDateDiff = (block.timestamp - buyingOrderProposal.date);
        require(creationDateDiff <= community.foundersVotingTime, "voting time is over");

        buyingOrderProposal.approvals[founderIndex].IsVoted = true;
        buyingOrderProposal.approvals[founderIndex].Vote = voteProposal.decision;

        uint consensusScoreRequirement = community.foundersConsensus;
        uint consensusScore;
        uint negativeConsensusScore;

        for(uint i = 0; i < community.foundersCount; i++) {
            if(buyingOrderProposal.approvals[i].Vote) {
                consensusScore += community.foundersShares[i];
            }

            if(!buyingOrderProposal.approvals[i].Vote && buyingOrderProposal.approvals[i].IsVoted) {
                negativeConsensusScore += community.foundersShares[i];
            }
        }

        if(consensusScore >= consensusScoreRequirement) {
            IERC20TokenExchange(exchangeContractAddress)
                .PlaceERC20TokenBuyingOffer(buyingOrderProposal.proposal, buyingOrderProposal.proposalCreator);
            deleteBuyingOrderProposal(buyingOrderProposal.proposalId);
            return;
        }

        if(negativeConsensusScore > (10000 - consensusScoreRequirement)) { // *10^4
            deleteBuyingOrderProposal(buyingOrderProposal.proposalId);
            uint buyingOrderProposalAmount = buyingOrderProposal.proposal.amount;
            IERC20(exchange.offerTokenAddress).transferFrom(community.escrowAddress, community.communityAddress, buyingOrderProposalAmount);
            return;
        }

        updateBuyingOrderProposal(buyingOrderProposal);
    }
}