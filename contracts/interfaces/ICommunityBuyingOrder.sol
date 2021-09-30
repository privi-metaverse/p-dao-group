// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../model.sol";

interface ICommunityBuyingOrder {
    function getBuyingOrderProposal(uint proposalId) external view returns(BuyingOrderProposal memory);
}