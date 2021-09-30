// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../model.sol";

interface ICommunityAllocation {
    function getAllocationProposal(uint proposalId) external view returns(AllocationProposal memory);
    function getAllocationSum(AllocationProposal memory allocationProposal) external pure returns(address[] memory, uint);
    function updateCommunityTokenWithNewAllocationSum(uint tokenId, AllocationProposal memory allocationProposal, bool isAdded) external
     returns(CommunityToken memory);
}