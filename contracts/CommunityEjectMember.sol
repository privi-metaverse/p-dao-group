// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/IManageCommunityToken.sol";

import "./constant.sol";

contract CommunityEjectMember {
    mapping(uint => EjectMemberProposal) _ejectMemberProposals;
    mapping(uint => Member) _members;

    uint[] _ejectMemberProposalIds;

    uint _ejectMemberProposalCount;
    uint _memberCounter;

    address _daoContractAddress;
    address _manageCommunityTokenContractAddress;

    constructor(address daoContractAddress, address manageCommunityTokenContractAddress) {
        _daoContractAddress = daoContractAddress;
        _manageCommunityTokenContractAddress = manageCommunityTokenContractAddress;
    }

    function getEjectMemberProposalCount() public view returns(uint) {
        return _ejectMemberProposalCount;
    }

    function getEjectmemberProposalIds(uint index) public view returns(uint) {
        return _ejectMemberProposalIds[index];
    }

    function getEjectMemberProposal(uint proposalId) public view returns(EjectMemberProposal memory) {
        require(
            _ejectMemberProposals[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _ejectMemberProposals[proposalId];
    }

    function getMembersByType(address communityId, string memory memberType) public view returns(Member[] memory, uint) {
        Member[] memory members = new Member[](_memberCounter);
        uint counter;
        for(uint i = 0; i < _memberCounter; i++) {
            Member memory member = _members[i];
            if((member.communityId == communityId) && 
                (keccak256(abi.encodePacked(member.memberType)) == keccak256(abi.encodePacked(memberType)))) {
                members[counter] = _members[i];
                counter++;
            }
        }
        return (members, counter);
    }

    function getMembers(address communityId) public view returns(Member[] memory, uint) {
        Member[] memory members = new Member[](_memberCounter);
        uint counter;
        for(uint i = 0; i < _memberCounter; i++) {
            Member memory member = _members[i];
            if(member.communityId == communityId) {
                members[counter] = _members[i];
                counter++;
            }
        }
        return (members, counter);
    }

    function updateMember(Member memory member) public {
        uint memberIndex;
        for(uint i = 0; i < _memberCounter; i++) {
            if(_members[i].memberAddress == member.memberAddress) {
                memberIndex = i;
                break;
            }
        }
        
        if(memberIndex == 0) {
            memberIndex = _memberCounter;
            _memberCounter++;
        }

        _members[memberIndex].communityId = member.communityId;
        _members[memberIndex].memberAddress = member.memberAddress;
        _members[memberIndex].memberType = member.memberType;
        _members[memberIndex].share = member.share;
    }

    function updateEjectMemberProposal(EjectMemberProposal memory em) internal {
        Community memory community;
        bool flag = false;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(em.communityId);

        for(uint i = 0; i < _ejectMemberProposalCount; i++) {
            if(_ejectMemberProposalIds[i] == em.proposalId) {
                flag = true;
                break;
            }
        }

        if(!flag) {
            _ejectMemberProposalCount++;
            _ejectMemberProposalIds.push(em.proposalId);
        }

        
        _ejectMemberProposals[em.proposalId].proposalId = em.proposalId;
        _ejectMemberProposals[em.proposalId].communityId = em.communityId;
        _ejectMemberProposals[em.proposalId].proposalCreator = em.proposalCreator;
        _ejectMemberProposals[em.proposalId].memberAddress = em.memberAddress;
        _ejectMemberProposals[em.proposalId].date = em.date;
        
        for(uint i = 0; i < community.foundersCount; i++) {
            _ejectMemberProposals[em.proposalId].approvals[i].IsVoted = em.approvals[i].IsVoted;
            _ejectMemberProposals[em.proposalId].approvals[i].Vote = em.approvals[i].Vote;
        }
    }

    function deleteMember(address memberAddress, address communityId, string memory memberType) public {
        for(uint i = 0; i < _memberCounter; i++) {
            if((_members[i].memberAddress == memberAddress) && (_members[i].communityId == communityId)
                && (keccak256(abi.encodePacked(_members[i].memberType)) == keccak256(abi.encodePacked(memberType)))) {
                delete _members[i];
                return;
            }
        }
    }

    function removeMember(address memberAddress, Community memory community) public {
        if(keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeStaking))) {
            for(uint i = 0; i < community.entryConditionCount; i++) {
                address tokenContractAddress;
                bool result;

                (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
                    .getTokenContractAddress(community.entryConditionSymbols[i]);
                require(result, "token contract address is not valid");
                
                IERC20(tokenContractAddress).transferFrom(community.stakingAddress, memberAddress, community.entryConditionValues[i]);
            }
        }
        deleteMember(memberAddress, community.communityAddress, MemberType);
    }

    function deleteEjectMemberProposal(uint proposalId) internal {
        delete _ejectMemberProposals[proposalId];
    }

    function cancleEjectMemberProposal(CancelProposalRequest calldata cancelProposalRequest) external {
        EjectMemberProposal memory ejectMemberProposal;
        Community memory community;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelProposalRequest.communityId);

        ejectMemberProposal = getEjectMemberProposal(cancelProposalRequest.proposalId);

        uint creationDateDiff = (block.timestamp - ejectMemberProposal.date);

        require(
            (ejectMemberProposal.proposalCreator == msg.sender) || 
                (creationDateDiff >= community.foundersVotingTime),
            "just proposal creator can cancel proposal"
        );

        deleteEjectMemberProposal(cancelProposalRequest.proposalId);
    }

    function CreateEjectMemberProposal(EjectMemberRequest calldata ejectMemberRequest) external {
        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(ejectMemberRequest.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "should be founder");

        Member[] memory members;
        uint memberCount;

        (members, memberCount) = getMembers(ejectMemberRequest.communityId);
        require(memberCount > 0, "get members failed with error");

        uint memberIndex;
        bool flag = false;
        for(uint i = 0; i < memberCount; i++) {
            if(members[i].memberAddress == ejectMemberRequest.ejectMemberAddress) {
                memberIndex = i;
                flag = true;
                break;
            }
        }
        require(flag, "address is not a member of community");

        EjectMemberProposal memory proposal;
        proposal.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _ejectMemberProposalCount + 1)));
        proposal.communityId = ejectMemberRequest.communityId;
        proposal.proposalCreator = msg.sender;
        proposal.memberAddress = ejectMemberRequest.ejectMemberAddress;
        proposal.date = block.timestamp;

        for(uint i = 0; i < community.foundersCount; i++) {
            proposal.approvals[i].IsVoted = false;
            proposal.approvals[i].Vote = false;
        }

        if(community.foundersCount > 1) {
            updateEjectMemberProposal(proposal);
            return;
        }

        removeMember(proposal.memberAddress, community);
    }

    function VoteEjectMemberProposal(VoteProposal calldata voteProposal) external {
        EjectMemberProposal memory ejectMemberProposal;
        Community memory community;
        bool result;

        ejectMemberProposal = getEjectMemberProposal(voteProposal.proposalId);

        community = IPRIVIDAO(_daoContractAddress).getCommunity(voteProposal.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "a voter has to be a founder of the community");
        require(!ejectMemberProposal.approvals[founderIndex].IsVoted, "a voter can not vote second time");

        require(
            (block.timestamp - ejectMemberProposal.date) <= community.foundersVotingTime, 
            "voting time is over"
        );

        ejectMemberProposal.approvals[founderIndex].IsVoted = true;
        ejectMemberProposal.approvals[founderIndex].Vote = voteProposal.decision;

        uint consensusScoreRequirement = community.foundersConsensus;
        uint consensusScore;
        uint negativeConsensusScore;

        for(uint i = 0; i < community.foundersCount; i++) {
            if(ejectMemberProposal.approvals[i].Vote) {
                consensusScore += community.foundersShares[i]; 
            }

            if(!ejectMemberProposal.approvals[i].Vote && ejectMemberProposal.approvals[i].IsVoted ) {
                negativeConsensusScore += community.foundersShares[i]; 
            }
        }

        if(consensusScore >= consensusScoreRequirement) {
            removeMemberProposal(ejectMemberProposal, community);
            return;
        }

        if(negativeConsensusScore >= (10000 - consensusScoreRequirement)) { // *10^4
            deleteEjectMemberProposal(ejectMemberProposal.proposalId);
            return;
        }

        updateEjectMemberProposal(ejectMemberProposal);
    }

    function removeMemberProposal(EjectMemberProposal memory ejectMemberProposal, Community memory community) internal {
        removeMember(ejectMemberProposal.memberAddress, community);
        deleteEjectMemberProposal(ejectMemberProposal.proposalId);
    }

    function CancelMembership(CancelMembershipRequest calldata cancelMembershipRequest) external {
        Community memory community;
        Member[] memory members;
        uint memberCount;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(cancelMembershipRequest.communityId);

        (members, memberCount) = getMembers(cancelMembershipRequest.communityId);
        require(memberCount > 0 , "get members failed with error");

        uint memberIndex;
        bool flag = false;
        for(uint i = 0; i < memberCount; i++) {
            if(members[i].memberAddress == cancelMembershipRequest.memberAddress) {
                memberIndex = i;
                flag = true;
                break;
            }
        }
        require(flag, "address is not a member of community");

        removeMember(cancelMembershipRequest.memberAddress, community);
    }
}