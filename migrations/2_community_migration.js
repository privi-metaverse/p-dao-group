const PRIVIDAO = artifacts.require("PRIVIDAO");
const CommunityAirdrop = artifacts.require("CommunityAirdrop");
const CommunityAllocation = artifacts.require("CommunityAllocation");
const CommunityBid = artifacts.require("CommunityBid");
const CommunityBuying = artifacts.require("CommunityBuying");
const CommunityBuyingOrder = artifacts.require("CommunityBuyingOrder");
const CommunityEjectMember = artifacts.require("CommunityEjectMember");
const CommunityTransfer = artifacts.require("CommunityTransfer");
const CommunityTreasurer = artifacts.require("CommunityTreasurer");
const CommunityJoining = artifacts.require("CommunityJoining");
const ManageCommunityToken = artifacts.require("ManageCommunityToken");

const secret = require("../secret.json");

module.exports = async function (deployer) {
    await deployer.deploy(PRIVIDAO, secret.exchangeContractAddress, secret.auctionContractAddress);

    const PRIVIDAOContract = await PRIVIDAO.deployed();

    await deployer.deploy(ManageCommunityToken, PRIVIDAOContract.address);
    const ManageCommunityTokenContract = await ManageCommunityToken.deployed();
    await PRIVIDAOContract.setManageCommunityTokenContractAddress(ManageCommunityTokenContract.address);

    await deployer.deploy(CommunityAirdrop, PRIVIDAOContract.address, ManageCommunityTokenContract.address);
    await deployer.deploy(CommunityAllocation, PRIVIDAOContract.address, ManageCommunityTokenContract.address);
    await deployer.deploy(CommunityEjectMember, PRIVIDAOContract.address, ManageCommunityTokenContract.address);
    const CommunityEjectMemberContract = await CommunityEjectMember.deployed();
    await PRIVIDAOContract.setEjectMemberContractAddress(CommunityEjectMemberContract.address);

    await deployer.deploy(CommunityBid, PRIVIDAOContract.address, ManageCommunityTokenContract.address,
        CommunityEjectMemberContract.address);
    await deployer.deploy(CommunityBuying, PRIVIDAOContract.address, CommunityEjectMemberContract.address);
    await deployer.deploy(CommunityBuyingOrder, PRIVIDAOContract.address, CommunityEjectMemberContract.address);
    await deployer.deploy(CommunityTransfer, PRIVIDAOContract.address, ManageCommunityTokenContract.address,
        CommunityEjectMemberContract.address);
    await deployer.deploy(CommunityTreasurer, PRIVIDAOContract.address, CommunityEjectMemberContract.address);
    await deployer.deploy(CommunityJoining, PRIVIDAOContract.address, ManageCommunityTokenContract.address, CommunityEjectMemberContract.address);
}