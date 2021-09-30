// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../model.sol";

interface ICommunityBuying {
    function getBuyingProposal(uint proposalId) external view returns(BuyingProposal memory);
}