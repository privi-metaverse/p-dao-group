const ERC20TokenExchange = artifacts.require("ERC20TokenExchange");
const IncreasingPriceERC721Auction = artifacts.require("IncreasingPriceERC721Auction");

const PRIVIDAO = artifacts.require("PRIVIDAO");
const ManageCommunityToken = artifacts.require("ManageCommunityToken");
const CommunityEjectMember = artifacts.require("CommunityEjectMember");

const {
    BN,           // Big Number support
    time,
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const { ZERO_ADDRESS } = constants;

contract("PRIVIDAO", (accounts) => {
    var erc20tokenexchange_contract;
    var increasingpriceerc721auction_contract;

    var prividao_contract;
    var managecommunitytoken_contract;
    var communityejectmember_contract;

    before(async () => {
        erc20tokenexchange_contract = await ERC20TokenExchange.new(
            { from: accounts[0] }
        ); 

        increasingpriceerc721auction_contract = await IncreasingPriceERC721Auction.new(
            { from: accounts[0] }
        );

        prividao_contract = await PRIVIDAO.new(
            erc20tokenexchange_contract.address,
            increasingpriceerc721auction_contract.address,
            { from: accounts[0] }
        );

        managecommunitytoken_contract = await ManageCommunityToken.new(
            prividao_contract.address,
            { from: accounts[0] }
        );

        await prividao_contract.setManageCommunityTokenContractAddress(managecommunitytoken_contract.address);

        communityejectmember_contract = await CommunityEjectMember.new(
            prividao_contract.address,
            managecommunitytoken_contract.address,
            { from: accounts[0] }
        );

        await prividao_contract.setEjectMemberContractAddress(communityejectmember_contract.address);

        await managecommunitytoken_contract.registerToken("USD Coin", "USDC", "0x2791bca1f2de4661ed88a30c99a7a9449aa84174");
        await managecommunitytoken_contract.registerToken("Uniswap", "UNI", "0xb33eaad8d922b1083446dc23f610c2567fb5180f");
    })

    describe("CreateCommunity", () => {
        it("not working if creator is not one of founders", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[4] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "creator should be one of founders");
        })

        it("not working if wrong entry type of the community", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "Wrong entry type of the community");
        })

        it("not working if entry conditions is not defined by staking option", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = [];
            const entryConditionValues = [];
            const entryConditionCount = 0;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "entry conditions should be defined by staking option");
        })

        it("not working if entry conditions is defined by not staking option", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "OpenToJoin";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "entry conditions should not be defined by not staking option");
        })

        it("not working if founders shares sum is not 10000", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 1000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "founders shares sum shoud be 10000");
        })

        it("not working if founders Voting Time is not longer than 1 day", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 3600;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "founders Voting Time should be longer than 1 day");
        })

        it("not working if treasury Voting Time is not longer than 1 day", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 3600;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "treasury Voting Time should be longer than 1 day");
        })

        it("not working if founders Consensus is not between 0 and 10000", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 11111;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "founders Consensus should be between 0 and 10000");
        })

        it("not working if treasury Consensus is not between 0 and 10000", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 11111;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "treasury Consensus should be between 0 and 10000");
        })

        it("not working if entry conditions token with symbol does not exist", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "ETH"];
            const entryConditionValues = [10000, 50];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "entry conditions token with symbol does not exist");
        })

        it("not working if entry condition token amount is not greater than 0", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 0];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            let thrownError;
            try {
                await prividao_contract.CreateCommunity({
                    founders: founders,
                    foundersShares: foundersShares,
                    foundersCount: foundersCount,
                    entryType: entryType,
                    entryConditionSymbols: entryConditionSymbols,
                    entryConditionValues: entryConditionValues,
                    entryConditionCount: entryConditionCount,
                    foundersVotingTime: foundersVotingTime,
                    foundersConsensus: foundersConsensus,
                    treasuryVotingTime: treasuryVotingTime,
                    treasuryConsensus: treasuryConsensus,
                    escrowAddress: escrowAddress,
                    stakingAddress: stakingAddress,
                    communityAddress: communityAddress,
                    date: date,
                    tokenId: tokenId,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "entry condition token amount should be greater than 0");
        })

        it("works well", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 5000];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            const prevCommunityCPCount =  await prividao_contract.getCommunityCPCounter();

            await prividao_contract.CreateCommunity({
                founders: founders,
                foundersShares: foundersShares,
                foundersCount: foundersCount,
                entryType: entryType,
                entryConditionSymbols: entryConditionSymbols,
                entryConditionValues: entryConditionValues,
                entryConditionCount: entryConditionCount,
                foundersVotingTime: foundersVotingTime,
                foundersConsensus: foundersConsensus,
                treasuryVotingTime: treasuryVotingTime,
                treasuryConsensus: treasuryConsensus,
                escrowAddress: escrowAddress,
                stakingAddress: stakingAddress,
                communityAddress: communityAddress,
                date: date,
                tokenId: tokenId,
            }, { from: accounts[0] });

            const communityCPCount =  await prividao_contract.getCommunityCPCounter();
            assert.equal(communityCPCount.sub(prevCommunityCPCount).toNumber(), 1);
        })
    })

    describe("VoteCreationProposal", () => {
        it("not working if community id is not valid", async () => {
            const communityCPId = await prividao_contract.getCommunityCPIdByIndex(0);
            const communityCP = await prividao_contract.getCreationProposal(communityCPId);
            const communityCPCounter = await prividao_contract.getCommunityCPCounter();

            let thrownError;

            try {
                await prividao_contract.VoteCreationProposal({
                    proposalId: communityCP.proposalId,
                    communityId: ZERO_ADDRESS,
                    decision: true
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "community id is not valid");
        })

        it("not working if community creation proposal id is not valid", async () => {
            const communityCPId = await prividao_contract.getCommunityCPIdByIndex(0);
            const communityCP = await prividao_contract.getCreationProposal(communityCPId);
            const communityCPCounter = await prividao_contract.getCommunityCPCounter();

            let thrownError;

            try {
                await prividao_contract.VoteCreationProposal({
                    proposalId: 0,
                    communityId: communityCP.proposal.communityAddress,
                    decision: true
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "community creation proposal id is not valid");
        })

        it("not working if voter is not an founder of the community", async () => {
            const communityCPId = await prividao_contract.getCommunityCPIdByIndex(0);
            const communityCP = await prividao_contract.getCreationProposal(communityCPId);
            const communityCPCounter = await prividao_contract.getCommunityCPCounter();

            let thrownError;

            try {
                await prividao_contract.VoteCreationProposal({
                    proposalId: communityCP.proposalId,
                    communityId: communityCP.proposal.communityAddress,
                    decision: true
                }, { from: accounts[4] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "voter should be founder");
        })

        it("not working if voter vote second time", async () => {
            const communityCPId = await prividao_contract.getCommunityCPIdByIndex(0);
            const communityCP = await prividao_contract.getCreationProposal(communityCPId.toString());

            await prividao_contract.VoteCreationProposal({
                proposalId: communityCP.proposalId,
                communityId: communityCP.proposal.communityAddress,
                decision: true
            }, { from: accounts[0] });

            let thrownError;

            try {
                await prividao_contract.VoteCreationProposal({
                    proposalId: communityCP.proposalId,
                    communityId: communityCP.proposal.communityAddress,
                    decision: true,
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "voter can not vote second time");
        })

        it("works well", async () => {
            const communityCPId = await prividao_contract.getCommunityCPIdByIndex(0);
            const communityCP = await prividao_contract.getCreationProposal(communityCPId.toString());
            const prevCommunityCount =  await prividao_contract.getCommunityCounter();

            await prividao_contract.VoteCreationProposal({
                proposalId: communityCP.proposalId,
                communityId: communityCP.proposal.communityAddress,
                decision: true
            }, { from: accounts[1] });

            await prividao_contract.VoteCreationProposal({
                proposalId: communityCP.proposalId,
                communityId: communityCP.proposal.communityAddress,
                decision: true,
            }, { from: accounts[2] });
            
            const communityCount =  await prividao_contract.getCommunityCounter();
            assert.equal(communityCount.sub(prevCommunityCount).toNumber(), 1);
        })
    })

    describe("cancelCreationProposal", () => {
        it("works well", async () => {
            const founders = [accounts[0], accounts[1], accounts[2]];
            const foundersShares = [5000, 2000, 3000];
            const foundersCount = 3;
            const entryType = "Staking";
            const entryConditionSymbols = ["USDC", "UNI"];
            const entryConditionValues = [10000, 5000];
            const entryConditionCount = 2;
            const foundersVotingTime = 11111111111;
            const foundersConsensus = 1;
            const treasuryVotingTime = 11111111111;
            const treasuryConsensus = 1;
            const escrowAddress = accounts[9];
            const stakingAddress = accounts[8];
            const communityAddress = accounts[7];
            const date = await time.latest();
            const tokenId = 0;

            await prividao_contract.CreateCommunity({
                founders: founders,
                foundersShares: foundersShares,
                foundersCount: foundersCount,
                entryType: entryType,
                entryConditionSymbols: entryConditionSymbols,
                entryConditionValues: entryConditionValues,
                entryConditionCount: entryConditionCount,
                foundersVotingTime: foundersVotingTime,
                foundersConsensus: foundersConsensus,
                treasuryVotingTime: treasuryVotingTime,
                treasuryConsensus: treasuryConsensus,
                escrowAddress: escrowAddress,
                stakingAddress: stakingAddress,
                communityAddress: communityAddress,
                date: date,
                tokenId: tokenId,
            }, { from: accounts[0] });

            const communityCPId = await prividao_contract.getCommunityCPIdByIndex(1);
            const communityCP = await prividao_contract.getCreationProposal(communityCPId.toString());

            await prividao_contract.cancelCreationProposal({
                proposalId: communityCP.proposalId,
                communityId: communityCP.proposal.communityAddress,
            }, { from: accounts[0] });

        })
    })
})