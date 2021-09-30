// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../model.sol";

interface ICommunityTransfer{
    function getTransferProposal(uint proposalId) external view returns(TransferProposal memory);
}