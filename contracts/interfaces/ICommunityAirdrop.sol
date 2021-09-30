// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../model.sol";

interface ICommunityAirdrop {
    function getAirdropProposal(uint proposalId) external view returns(AirdropProposal memory);
    function getAirdropSum(Airdrop memory airdrop) external pure returns(address[] memory, uint);
    function updateCommunityTokenWithNewAirdropSum(uint tokenId, AirdropProposal memory airdropProposal, bool isAddition) external 
        returns(CommunityToken memory);
}