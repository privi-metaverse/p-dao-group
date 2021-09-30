// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../model.sol";

interface ICommunityBid {
    function getBidProposal(uint proposalId, address communityId) external view returns(BidProposal memory);
}