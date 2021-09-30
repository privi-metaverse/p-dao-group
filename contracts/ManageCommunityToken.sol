// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./interfaces/IPRIVIDAO.sol";

import "./constant.sol";

contract ManageCommunityToken {
    mapping(uint => Token) _tokens;
    mapping(uint => CommunityToken) _communityTokens;
    mapping(uint => CommunityTokenProposal) _communityTPs;

    uint[] _communityTokenIds;
    uint[] _communityTPIds;

    uint _tokenCounter;
    uint _communityTokenCounter;
    uint _communityTPCounter;
    

    address _daoContractAddress;

    constructor(address daoContractAddress) {
        require(daoContractAddress != address(0), "dao contract address is not valid");
        _daoContractAddress = daoContractAddress;
    }

    function getTokenCounter() public view returns(uint) {
        return _tokenCounter;
    }

    function getCommunityTokenCounter() public view returns(uint) {
        return _communityTokenCounter;
    }

    function getCommunityTokenIdByIndex(uint index) public view returns(uint) {
        return _communityTokenIds[index];
    }

    function getCommunityTPCounter() public view returns(uint) {
        return _communityTPCounter;
    }

    function getCommunityTPIdByIndex(uint index) public view returns(uint) {
        return _communityTPIds[index];
    }

    function isTokenExist(string memory tokenSymbol) public view returns(bool) {
        for(uint i = 0; i < _tokenCounter; i++) {
            if(keccak256(abi.encodePacked(_tokens[i].symbol)) == keccak256(abi.encodePacked(tokenSymbol))) return true;
        }
        return false;
    }

    function getTokenContractAddress(string  memory tokenSymbol) public view returns(address, bool) {
        address contractAddress;
        for(uint i = 0; i < _tokenCounter; i++) {
            if(keccak256(abi.encodePacked(_tokens[i].symbol)) == keccak256(abi.encodePacked(tokenSymbol))) {
                contractAddress = _tokens[i].contractAddress;
                return (contractAddress, true);
            }
        }
        return (contractAddress, false);
    }

    function getCommunityToken(uint tokenId) public view returns(CommunityToken memory) {
        require(_communityTokens[tokenId].tokenId == tokenId, "tokenId is not valid");
        return _communityTokens[tokenId];
    }

    function updateCommunityToken(CommunityToken memory communityToken) public {
        bool flag = false;

        for(uint i = 0; i < _communityTokenCounter; i++) {
            if(_communityTokenIds[i] == communityToken.tokenId) {
                flag = true;
                break;
            }
        }
        if(!flag) {
            _communityTokenCounter++;
            _communityTokenIds.push(communityToken.tokenId);
        }

        _communityTokens[communityToken.tokenId] = communityToken;
    }

    function getCommunityTokenProposal(uint proposalId) public view returns(CommunityTokenProposal memory) {
        require(
            _communityTPs[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _communityTPs[proposalId];
    }

    function updateCommunityTokenProposal(CommunityTokenProposal memory communityTP) internal  {
        bool flag = false;

        for(uint i = 0; i < _communityTPCounter; i++) {
            if(_communityTPIds[i] == communityTP.proposalId) {
                flag = true;
                break;
            }
        }
        if(!flag) {
            _communityTPCounter++;
            _communityTPIds.push(communityTP.proposalId);
        }
        _communityTPs[communityTP.proposalId].proposalId = communityTP.proposalId;
        _communityTPs[communityTP.proposalId].communityId = communityTP.communityId;
        _communityTPs[communityTP.proposalId].proposalCreator = communityTP.proposalCreator;
        _communityTPs[communityTP.proposalId].proposal = communityTP.proposal;
        _communityTPs[communityTP.proposalId].date = communityTP.date;

        for(uint j = 0; j < 20; j++) {
            _communityTPs[communityTP.proposalId].approvals[j].IsVoted = communityTP.approvals[j].IsVoted;
            _communityTPs[communityTP.proposalId].approvals[j].Vote = communityTP.approvals[j].Vote;
        }
    }

    function registerToken(string memory tokenName, string memory tokenSymbol, address tokenContractAddress) public {
        require(keccak256(abi.encodePacked(tokenName)) != keccak256(abi.encodePacked("")), "token name is not valid");
        require(keccak256(abi.encodePacked(tokenSymbol)) != keccak256(abi.encodePacked("")), "token symbol is not valid");
        require(tokenContractAddress != address(0), "token contract address is not exist");

        Token memory token;
        token.name = tokenName;
        token.symbol = tokenSymbol;
        token.contractAddress = tokenContractAddress;

        _tokens[_tokenCounter] = token;
        _tokenCounter++;
    }

    function checkPropertiesOfToken(CommunityToken memory token) internal view {
        require(
            token.communityId != address(0), "communityId can't be zero"
        );
        require(
            keccak256(abi.encodePacked(token.tokenSymbol)) != keccak256(abi.encodePacked("")), 
            "tokenSymbol can't be empty"
        );
        require(
            keccak256(abi.encodePacked(token.tokenName)) != keccak256(abi.encodePacked("")),
            "tokenName can't be empty"
        );
        require(!isTokenExist(token.tokenSymbol), "token already exist, can't be created");
        require(token.tokenContractAddress != address(0), "token contract address can't be zero");
        require(
            (keccak256(abi.encodePacked(token.tokenType)) == keccak256(abi.encodePacked(CommunityTokenTypeLinear))) ||
            (keccak256(abi.encodePacked(token.tokenType)) == keccak256(abi.encodePacked(CommunityTokenTypeQuadratic))) ||
            (keccak256(abi.encodePacked(token.tokenType)) == keccak256(abi.encodePacked(CommunityTokenTypeExponential))) ||
            (keccak256(abi.encodePacked(token.tokenType)) == keccak256(abi.encodePacked(CommunityTokenTypeSigmoid))),
            "accepted token types are only: LINEAR, QUADRATIC, EXPONENTIAL and SIGMOID"
        );
        require(
            keccak256(abi.encodePacked(token.fundingToken)) != keccak256(abi.encodePacked("")),
            "fundingToken can't be empty"
        );
        require(token.initialSupply > 0, "initialSupply can't be 0");
        require(token.targetPrice > 0, "targetPrice can't be 0");
        require(token.targetSupply > 0, "targetSupply can't be 0");
        require(token.vestingTime >= (30*24*60*60), "vesting time should be longer than 30 days");
        require(token.immediateAllocationPct > 0, "immediateAllocationPct can't be 0");
        require(token.vestedAllocationPct > 0, "vestedAllocationPct can't be 0");
        require(token.taxationPct > 0, "taxationPct can't be 0");
    }

    function deleteCommunityTokenProposal(uint proposalId) internal {
        delete _communityTPs[proposalId];
    }

    function cancelCommunityTokenProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        CommunityTokenProposal memory communityTokenProposal;
        Community memory community;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);

        communityTokenProposal = getCommunityTokenProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - communityTokenProposal.date);

        require(
            (communityTokenProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.foundersVotingTime),
            "just proposal creator can cancel proposal"
        );

        deleteCommunityTokenProposal(cancelProposalRequest.proposalId);
    }

    function CreateCommunityToken(CommunityToken calldata token) external {
        checkPropertiesOfToken(token);
        CommunityTokenProposal memory communityTokenProposal;

        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(token.communityId);

        communityTokenProposal.communityId = community.communityAddress;

        for(uint i = 0; i < community.foundersCount; i++) {
            communityTokenProposal.approvals[i].IsVoted = false;
            communityTokenProposal.approvals[i].Vote = false;
        }

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "get id of founders failed with error");

        communityTokenProposal.date = block.timestamp;
        communityTokenProposal.proposalCreator = msg.sender;

        if((community.foundersCount == 1) && (community.foundersShares[founderIndex] > 0)) {
            CommunityToken memory communityToken = token;
            communityToken.tokenId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _communityTokenCounter + 1)));

            updateCommunityToken(communityToken);

            registerToken(communityToken.tokenName, communityToken.tokenSymbol, communityToken.tokenContractAddress);

            community.tokenId = communityToken.tokenId;
            IPRIVIDAO(_daoContractAddress).updateCommunity(community);
            return;
        }
        communityTokenProposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _communityTPCounter + 1)));
        communityTokenProposal.proposal = token;

        updateCommunityTokenProposal(communityTokenProposal);
    }

    function VoteCommunityTokenProposal(VoteProposal calldata tokenProposalInput) external {
        CommunityTokenProposal memory communityTokenProposal = getCommunityTokenProposal(tokenProposalInput.proposalId);
        
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(tokenProposalInput.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "voter has to be an founder of the community");

        require(
            !communityTokenProposal.approvals[founderIndex].IsVoted, 
            "voter can not vote second time"
        );
        require(
            (block.timestamp - communityTokenProposal.date) <= community.foundersVotingTime, 
            "voting time is over"
        );

        communityTokenProposal.approvals[founderIndex].IsVoted = true;
        communityTokenProposal.approvals[founderIndex].Vote = tokenProposalInput.decision;

        // Calculate if consensus already achieved
        uint consensusScoreRequirement = community.foundersConsensus;
        uint consensusScore;
        uint negativeConsensusScore;

        for(uint i = 0; i < community.foundersCount; i++) {
            if(communityTokenProposal.approvals[i].Vote) {
                consensusScore = consensusScore + community.foundersShares[i];
            }
            if(!communityTokenProposal.approvals[i].Vote && communityTokenProposal.approvals[i].IsVoted) {
                negativeConsensusScore = negativeConsensusScore + community.foundersShares[i];
            }
        }
        
        if(consensusScore >= consensusScoreRequirement) {
            uint tokenId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, communityTokenProposal.proposalId)));
            communityTokenProposal.proposal.tokenId = tokenId;
            updateCommunityToken(communityTokenProposal.proposal);

            registerToken(
                communityTokenProposal.proposal.tokenName, 
                communityTokenProposal.proposal.tokenSymbol, 
                communityTokenProposal.proposal.tokenContractAddress
            );

            community.tokenId = tokenId; 
            IPRIVIDAO(_daoContractAddress).updateCommunity(community);

            deleteCommunityTokenProposal(communityTokenProposal.proposalId);
            return;
        }

        if(negativeConsensusScore >= (10000 - consensusScoreRequirement)) { // *10^4 
            deleteCommunityTokenProposal(communityTokenProposal.proposalId);
            return;
        } 

        updateCommunityTokenProposal(communityTokenProposal);
    }
}