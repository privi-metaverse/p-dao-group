// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPRIVIDAO.sol";
import "./interfaces/IManageCommunityToken.sol";
import "./interfaces/ICommunityEjectMember.sol";

import "./constant.sol";

contract CommunityJoining {
    mapping(uint => JoiningRequest) _joiningRequests;

    uint[] _joiningRequestIds;
    uint _joiningRequestCount;

    address _daoContractAddress;
    address _manageCommunityTokenContractAddress;
    address _ejectMemberContractAddress;

    constructor(address daoContractAddress, address manageCommunityTokenContractAddress, address ejectMemberContractAddress) {
        _daoContractAddress = daoContractAddress;
        _manageCommunityTokenContractAddress = manageCommunityTokenContractAddress;
        _ejectMemberContractAddress = ejectMemberContractAddress;
    }

    function getJoiningRequestCount() public view returns(uint) {
        return _joiningRequestCount;
    }

    function getJoiningRequestIds(uint index) public view returns(uint) {
        return _joiningRequestIds[index];
    }

    function getJoiningRequest(uint proposalId) public view returns(JoiningRequest memory) {
        require(
            _joiningRequests[proposalId].proposalId == proposalId, 
            "proposalId is not valid"
        );

        return _joiningRequests[proposalId];
    }

    function updateJoiningRequest(JoiningRequest memory jr) internal {
        bool flag = false;
        for(uint i = 0; i < _joiningRequestCount; i++) {
            if(_joiningRequestIds[i] == jr.proposalId) {
                flag = true;
                break;
            }
        }

        if(!flag) {
            _joiningRequestCount++;
            _joiningRequestIds.push(jr.proposalId);
        }

        _joiningRequests[jr.proposalId].proposalId = jr.proposalId;
        _joiningRequests[jr.proposalId].communityId = jr.communityId;
        _joiningRequests[jr.proposalId].joiningRequestAddress = jr.joiningRequestAddress;
    }

    function deleteJoiningRequest(uint proposalId) internal {
        delete _joiningRequests[proposalId];
    }

    function CreateJoiningRequest(JoiningRequest calldata joiningRequest) external {
        require(joiningRequest.joiningRequestAddress != address(0), "address doesn't exist");

        Community memory community;
        bool result;

        community = IPRIVIDAO(_daoContractAddress).getCommunity(joiningRequest.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, joiningRequest.joiningRequestAddress);
        require(!result, "address is already member of community as founder.");

        Member[] memory members;
        uint memberCount;
        (members, memberCount) = ICommunityEjectMember(_ejectMemberContractAddress).getMembers(joiningRequest.communityId);

        bool isMember = false;
        for(uint i = 0; i < memberCount; i++) {
            if(members[i].memberAddress == joiningRequest.joiningRequestAddress) {
                isMember = true;
                break;
            }
        }
        require(!isMember, "address is already member of community.");

        if(keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeOpenToJoin))) {
            Member memory member;
            member.communityId = community.communityAddress;
            member.memberAddress = joiningRequest.joiningRequestAddress;
            member.memberType = MemberType;
            ICommunityEjectMember(_ejectMemberContractAddress).updateMember(member);
        } else if(keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeApproval))) {
            JoiningRequest memory jr = joiningRequest;
            jr.proposalId = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _joiningRequestCount + 1)));
            updateJoiningRequest(jr);
        } else if(keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeStaking))) {
            for(uint i = 0; i < community.entryConditionCount; i++) {
                address tokenContractAddress;

                (tokenContractAddress, result) = IManageCommunityToken(_manageCommunityTokenContractAddress)
                    .getTokenContractAddress(community.entryConditionSymbols[i]);
                require(result, "token contract address is not valid");

                uint balance = IERC20(tokenContractAddress).balanceOf(joiningRequest.joiningRequestAddress);
                require(balance >= community.entryConditionValues[i], "insufficient founds");

                IERC20(tokenContractAddress)
                    .transferFrom(joiningRequest.joiningRequestAddress, community.stakingAddress, community.entryConditionValues[i]);
            }

            Member memory member;
            member.communityId = community.communityAddress;
            member.memberAddress = joiningRequest.joiningRequestAddress;
            member.memberType = MemberType;

            ICommunityEjectMember(_ejectMemberContractAddress).updateMember(member);
        } else{}
    }

    function ResolveJoiningRequest(VoteProposal calldata voteProposal) external {
        JoiningRequest memory joiningRequest;
        Community memory community;
        bool result;

        joiningRequest = getJoiningRequest(voteProposal.proposalId);

        community = IPRIVIDAO(_daoContractAddress).getCommunity(joiningRequest.communityId);

        uint founderIndex;
        (founderIndex, result) = IPRIVIDAO(_daoContractAddress).getIdOfFounders(community, msg.sender);
        require(result, "just founders of community can vote on joining request.");

        require(
            keccak256(abi.encodePacked(community.entryType)) == keccak256(abi.encodePacked(CommunityEntryTypeApproval)), 
            "cannot resolve joining request on community with EntryType"
        );

        if(voteProposal.decision) {
            Member memory member;
            member.communityId =  community.communityAddress;
            member.memberAddress = joiningRequest.joiningRequestAddress;
            member.memberType = MemberType;

            ICommunityEjectMember(_ejectMemberContractAddress).updateMember(member);
        }

        deleteJoiningRequest(voteProposal.proposalId);
    }
}