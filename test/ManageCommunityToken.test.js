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

contract("ManageCommunityToken", (accounts) => {
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

        const founders = [accounts[0], accounts[1], accounts[2]];
        const foundersShares = [5000, 2000, 3000];
        const foundersCount = 3;
        const entryType = "Staking";
        const entryConditionSymbols = ["USDC", "UNI"];
        const entryConditionValues = [10000, 5000];
        const entryConditionCount = 2;
        const foundersVotingTime = 11111111111;
        const foundersConsensus = 9000;
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

        const communityCPId = await prividao_contract.getCommunityCPIdByIndex(0);
        const communityCP = await prividao_contract.getCreationProposal(communityCPId.toString());

        await prividao_contract.VoteCreationProposal({
            proposalId: communityCP.proposalId,
            communityId: communityCP.proposal.communityAddress,
            decision: true
        }, { from: accounts[0] });

        await prividao_contract.VoteCreationProposal({
            proposalId: communityCP.proposalId,
            communityId: communityCP.proposal.communityAddress,
            decision: true
        }, { from: accounts[1] });

        await prividao_contract.VoteCreationProposal({
            proposalId: communityCP.proposalId,
            communityId: communityCP.proposal.communityAddress,
            decision: true
        }, { from: accounts[2] });
    })

    describe("CreateCommunityToken", () => {
        it("not working if communityId is zero", async () => {
            const tokenId= 0;
            const communityId = ZERO_ADDRESS;
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "communityId can't be zero");
        })

        it("not working if tokenSymbol is empty", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "tokenSymbol can't be empty");
        })

        it("not working if tokenName is empty", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "tokenName can't be empty");
        })

        it("not working if accepted token types are not one of LINEAR, QUADRATIC, EXPONENTIAL and SIGMOID", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "aaa";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "accepted token types are only: LINEAR, QUADRATIC, EXPONENTIAL and SIGMOID");
        })

        it("not working if fundingToken is empty", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "fundingToken can't be empty");
        })

        it("not working if initialSupply is 0", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 0;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "initialSupply can't be 0");
        })

        it("not working if targetPrice is 0", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 0;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "targetPrice can't be 0");
        })

        it("not working if targetSupply is 0", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 0;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "targetSupply can't be 0");
        })

        it("not working if vesting time is not longer than 30 days", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 29*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "vesting time should be longer than 30 days");
        })

        it("not working if immediateAllocationPct is 0", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 0;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "immediateAllocationPct can't be 0");
        })

        it("not working if vestedAllocationPct is 0", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 0;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "vestedAllocationPct can't be 0");
        })

        it("not working if taxationPct is 0", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 0;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "taxationPct can't be 0");
        })

        it("not working if get id of founders failed with error", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;
            let thrownError;

            try {
                await managecommunitytoken_contract.CreateCommunityToken({
                    tokenId: tokenId,
                    communityId: communityId,
                    tokenName: tokenName,
                    tokenSymbol: tokenSymbol,
                    tokenContractAddress: tokenContractAddress,
                    fundingToken: fundingToken,
                    ammAddress: ammAddress,
                    tokenType: tokenType,
                    initialSupply: initialSupply,
                    targetPrice: targetPrice,
                    targetSupply: targetSupply,
                    vestingTime: vestingTime,
                    immediateAllocationPct: immediateAllocationPct,
                    vestedAllocationPct: vestedAllocationPct,
                    taxationPct: taxationPct,
                    date: date,
                    airdropAmount: airdropAmount,
                    allocationAmount: allocationAmount
                }, { from: accounts[4] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "get id of founders failed with error");
        })

        it("works well", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVI";
            const tokenSymbol = "PRIVI";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;

            await managecommunitytoken_contract.CreateCommunityToken({
                tokenId: tokenId,
                communityId: communityId,
                tokenName: tokenName,
                tokenSymbol: tokenSymbol,
                tokenContractAddress: tokenContractAddress,
                fundingToken: fundingToken,
                ammAddress: ammAddress,
                tokenType: tokenType,
                initialSupply: initialSupply,
                targetPrice: targetPrice,
                targetSupply: targetSupply,
                vestingTime: vestingTime,
                immediateAllocationPct: immediateAllocationPct,
                vestedAllocationPct: vestedAllocationPct,
                taxationPct: taxationPct,
                date: date,
                airdropAmount: airdropAmount,
                allocationAmount: allocationAmount
            }, { from: accounts[0] })
        })
    })

    describe("VoteCommunityTokenProposal", () => {
        it("not working if voter is not an founder of the community", async () => {
            const communityTPId = await managecommunitytoken_contract.getCommunityTPIdByIndex(0);
            const communityTP = await managecommunitytoken_contract.getCommunityTokenProposal(communityTPId.toString());

            let thrownError;

            try {
                await managecommunitytoken_contract.VoteCommunityTokenProposal({
                    proposalId: communityTP.proposalId,
                    communityId: communityTP.proposal.communityId,
                    decision: true
                }, { from: accounts[4] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "voter has to be an founder of the community");
        })

        it("not working if voter vote second time", async () => {
            const communityTPId = await managecommunitytoken_contract.getCommunityTPIdByIndex(0);
            const communityTP = await managecommunitytoken_contract.getCommunityTokenProposal(communityTPId.toString());

            await managecommunitytoken_contract.VoteCommunityTokenProposal({
                proposalId: communityTP.proposalId,
                communityId: communityTP.proposal.communityId,
                decision: true
            }, { from: accounts[0] });

            let thrownError;

            try {
                await managecommunitytoken_contract.VoteCommunityTokenProposal({
                    proposalId: communityTP.proposalId,
                    communityId: communityTP.proposal.communityId,
                    decision: true
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "voter can not vote second time");
        })

        it("works well", async () => {
            const communityTPId = await managecommunitytoken_contract.getCommunityTPIdByIndex(0);
            const communityTP = await managecommunitytoken_contract.getCommunityTokenProposal(communityTPId.toString());
            const prevCommunityTokenCount =  await managecommunitytoken_contract.getCommunityTokenCounter();

            await managecommunitytoken_contract.VoteCommunityTokenProposal({
                proposalId: communityTP.proposalId,
                communityId: communityTP.proposal.communityId,
                decision: true
            }, { from: accounts[1] });

            await managecommunitytoken_contract.VoteCommunityTokenProposal({
                proposalId: communityTP.proposalId,
                communityId: communityTP.proposal.communityId,
                decision: true
            }, { from: accounts[2] });

            const communityTokenCount =  await managecommunitytoken_contract.getCommunityTokenCounter();
            assert.equal(communityTokenCount.sub(prevCommunityTokenCount).toNumber(), 1);
        })
    })

    describe("cancelCommunityTokenProposal", () => {
        it("works well", async () => {
            const tokenId= 0;
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const tokenName = "PRIVITEST";
            const tokenSymbol = "PRIVITEST";
            const tokenContractAddress = "0xD09d8D172dBB6b9209b1a9F8f7A67a6F1F99244a";
            const fundingToken = "USDC";
            const ammAddress = accounts[6];
            const tokenType = "LINEAR";
            const initialSupply = 100000000;
            const targetPrice = 3;
            const targetSupply = 300000000;
            const vestingTime = 30*24*60*60;
            const immediateAllocationPct = 10;
            const vestedAllocationPct = 10;
            const taxationPct = 10;
            const date = await time.latest();
            const airdropAmount = 1000000;
            const allocationAmount = 70000000;

            await managecommunitytoken_contract.CreateCommunityToken({
                tokenId: tokenId,
                communityId: communityId,
                tokenName: tokenName,
                tokenSymbol: tokenSymbol,
                tokenContractAddress: tokenContractAddress,
                fundingToken: fundingToken,
                ammAddress: ammAddress,
                tokenType: tokenType,
                initialSupply: initialSupply,
                targetPrice: targetPrice,
                targetSupply: targetSupply,
                vestingTime: vestingTime,
                immediateAllocationPct: immediateAllocationPct,
                vestedAllocationPct: vestedAllocationPct,
                taxationPct: taxationPct,
                date: date,
                airdropAmount: airdropAmount,
                allocationAmount: allocationAmount
            }, { from: accounts[0] })

            const communityTPId = await managecommunitytoken_contract.getCommunityTPIdByIndex(1);
            const communityTP = await managecommunitytoken_contract.getCommunityTokenProposal(communityTPId.toString());

            await managecommunitytoken_contract.cancelCommunityTokenProposal({
                proposalId: communityTP.proposalId,
                communityId: communityTP.communityId,
            }, { from: accounts[0] });
        })
    })
})