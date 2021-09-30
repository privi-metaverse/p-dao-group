const ERC20TokenExchange = artifacts.require("ERC20TokenExchange");
const IncreasingPriceERC721Auction = artifacts.require("IncreasingPriceERC721Auction");
const PRIVIERC20TestToken = artifacts.require("PRIVIERC20TestToken");

const PRIVIDAO = artifacts.require("PRIVIDAO");
const ManageCommunityToken = artifacts.require("ManageCommunityToken");
const CommunityEjectMember = artifacts.require("CommunityEjectMember");
const CommunityAirdrop = artifacts.require("CommunityAirdrop");

const {
    BN,           // Big Number support
    time,
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const { ZERO_ADDRESS } = constants;

contract("CommunityAirdrop", (accounts) => {
    var erc20tokenexchange_contract;
    var increasingpriceerc721auction_contract;
    var privierc20testtoken_contract;

    var prividao_contract;
    var managecommunitytoken_contract;
    var communityejectmember_contract;
    var communityairdrop_contract;

    before(async () => {
        erc20tokenexchange_contract = await ERC20TokenExchange.new(
            { from: accounts[0] }
        ); 

        increasingpriceerc721auction_contract = await IncreasingPriceERC721Auction.new(
            { from: accounts[0] }
        );

        privierc20testtoken_contract = await PRIVIERC20TestToken.new(
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

        communityairdrop_contract = await CommunityAirdrop.new(
            prividao_contract.address,
            managecommunitytoken_contract.address,
            { from: accounts[0] }
        );

        communityejectmember_contract = await CommunityEjectMember.new(
            prividao_contract.address,
            managecommunitytoken_contract.address,
            { from: accounts[0] }
        );

        await prividao_contract.setEjectMemberContractAddress(communityejectmember_contract.address);

        await managecommunitytoken_contract.registerToken("USD Coin", "USDC", "0x2791bca1f2de4661ed88a30c99a7a9449aa84174");
        await managecommunitytoken_contract.registerToken("Uniswap", "UNI", "0xb33eaad8d922b1083446dc23f610c2567fb5180f");

        const founders = [accounts[0], accounts[1], accounts[2]];
        const foundersShares = [5000, 3000, 2000];
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

        //Create Community

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

        await privierc20testtoken_contract.mint(communityAddress, 10000000);
        await privierc20testtoken_contract.mint(escrowAddress, 10000000);

        // Create CommunityToken
        const communityId = await prividao_contract.getCommunityIdByIndex(0);
        const tokenName = "PRIVIERC20TestToken";
        const tokenSymbol = "PRIVIERC20Test";
        const tokenContractAddress = privierc20testtoken_contract.address;
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

        const communityTPId = await managecommunitytoken_contract.getCommunityTPIdByIndex(0);
        const communityTP = await managecommunitytoken_contract.getCommunityTokenProposal(communityTPId.toString());

        await managecommunitytoken_contract.VoteCommunityTokenProposal({
            proposalId: communityTP.proposalId,
            communityId: communityTP.proposal.communityId,
            decision: true
        }, { from: accounts[0] });

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
    })

    describe("AirdropCommunityToken", () => {
        it("not working if communityId is not defined", async () => {
            const communityId = ZERO_ADDRESS;
            const recipientCount = 3;
            const recipients = [accounts[3], accounts[4], accounts[5]];
            const amounts = [10000, 10000, 10000];
            
            try {
                await communityairdrop_contract.AirdropCommunityToken({
                    communityId: communityId,
                    recipientCount: recipientCount,
                    recipients: recipients,
                    amounts: amounts
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "communityId has to be defined");
        })

        it("not working if recipients are empty", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);;
            const recipientCount = 0;
            const recipients = [accounts[3], accounts[4], accounts[5]];
            const amounts = [10000, 10000, 10000];
            
            try {
                await communityairdrop_contract.AirdropCommunityToken({
                    communityId: communityId,
                    recipientCount: recipientCount,
                    recipients: recipients,
                    amounts: amounts
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "recipients cant be empty");
        })

        it("not working if amount of amount of airdrop per address is zero", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);;
            const recipientCount = 3;
            const recipients = [accounts[3], accounts[4], accounts[5]];
            const amounts = [10000, 0, 10000];
            
            try {
                await communityairdrop_contract.AirdropCommunityToken({
                    communityId: communityId,
                    recipientCount: recipientCount,
                    recipients: recipients,
                    amounts: amounts
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "amount of airdrop per address has to be positive number");
        })

        it("not working if not enough tokens to propose this airdrop", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);;
            const recipientCount = 3;
            const recipients = [accounts[3], accounts[4], accounts[5]];
            const amounts = [10000, 1000000000000, 10000];
            
            try {
                await communityairdrop_contract.AirdropCommunityToken({
                    communityId: communityId,
                    recipientCount: recipientCount,
                    recipients: recipients,
                    amounts: amounts
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "not enough tokens to propose this airdrop");
        })

        it("not working if airdrop creator is not founder", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);;
            const recipientCount = 3;
            const recipients = [accounts[3], accounts[4], accounts[5]];
            const amounts = [10000, 10000, 10000];
            
            try {
                await communityairdrop_contract.AirdropCommunityToken({
                    communityId: communityId,
                    recipientCount: recipientCount,
                    recipients: recipients,
                    amounts: amounts
                }, { from: accounts[5] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "airdrop creator should be founder");
        })

        it("not working if transfer amount exceeds allowance", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const recipientCount = 3;
            const recipients = [accounts[3], accounts[4], accounts[5]];
            const amounts = [10000, 10000, 10000];
            
            try {
                await communityairdrop_contract.AirdropCommunityToken({
                    communityId: communityId,
                    recipientCount: recipientCount,
                    recipients: recipients,
                    amounts: amounts
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "transfer amount exceeds allowance");
        })

        it("works well", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const recipientCount = 3;
            const recipients = [accounts[3], accounts[4], accounts[5]];
            const amounts = [10000, 10000, 10000];

            await privierc20testtoken_contract.approve(communityairdrop_contract.address, 100000, { from: accounts[7] });
            await privierc20testtoken_contract.approve(communityairdrop_contract.address, 100000, { from: accounts[9] });

            await communityairdrop_contract.AirdropCommunityToken({
                communityId: communityId,
                recipientCount: recipientCount,
                recipients: recipients,
                amounts: amounts
            }, { from: accounts[0] });
        })
    })

    describe("VoteAirdropProposal", () => {
        it("not working if proposalId is empty", async () => {
            const airdropProposalId = await communityairdrop_contract.getAirdropProposalIds(0);
            const airdropProposal = await communityairdrop_contract.getAirdropProposal(airdropProposalId.toString());
            try {
                await communityairdrop_contract.VoteAirdropProposal({
                    proposalId: 0,
                    communityId: airdropProposal.communityId,
                    decision: true
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "proposalId cannot be empty");
        })

        it("not working if communityId is empty", async () => {
            const airdropProposalId = await communityairdrop_contract.getAirdropProposalIds(0);
            const airdropProposal = await communityairdrop_contract.getAirdropProposal(airdropProposalId.toString());
            try {
                await communityairdrop_contract.VoteAirdropProposal({
                    proposalId: airdropProposal.proposalId,
                    communityId: ZERO_ADDRESS,
                    decision: true
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "communityId cannot be empty");
        })

        it("not working if not founder", async () => {
            const airdropProposalId = await communityairdrop_contract.getAirdropProposalIds(0);
            const airdropProposal = await communityairdrop_contract.getAirdropProposal(airdropProposalId.toString());
            try {
                await communityairdrop_contract.VoteAirdropProposal({
                    proposalId: airdropProposal.proposalId,
                    communityId: airdropProposal.communityId,
                    decision: true
                }, { from: accounts[4] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "only founders can vote");
        })

        it("not working if vote second time", async () => {
            const airdropProposalId = await communityairdrop_contract.getAirdropProposalIds(0);
            const airdropProposal = await communityairdrop_contract.getAirdropProposal(airdropProposalId.toString());
            await communityairdrop_contract.VoteAirdropProposal({
                proposalId: airdropProposal.proposalId,
                communityId: airdropProposal.communityId,
                decision: true
            }, { from: accounts[0] });

            try {
                await communityairdrop_contract.VoteAirdropProposal({
                    proposalId: airdropProposal.proposalId,
                    communityId: airdropProposal.communityId,
                    decision: true
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "voter can not vote second time");
        })

        it("works well", async () => {
            const airdropProposalId = await communityairdrop_contract.getAirdropProposalIds(0);
            const airdropProposal = await communityairdrop_contract.getAirdropProposal(airdropProposalId.toString());
            
            await communityairdrop_contract.VoteAirdropProposal({
                proposalId: airdropProposal.proposalId,
                communityId: airdropProposal.communityId,
                decision: true
            }, { from: accounts[1] });

            await communityairdrop_contract.VoteAirdropProposal({
                proposalId: airdropProposal.proposalId,
                communityId: airdropProposal.communityId,
                decision: true
            }, { from: accounts[2] });
        })
    })

    describe("cancelAirdropProposal", () => {
        it("works well", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const recipientCount = 3;
            const recipients = [accounts[3], accounts[4], accounts[5]];
            const amounts = [10000, 10000, 10000];

            await privierc20testtoken_contract.approve(communityairdrop_contract.address, 100000, { from: accounts[7] });
            await privierc20testtoken_contract.approve(communityairdrop_contract.address, 100000, { from: accounts[9] });

            await communityairdrop_contract.AirdropCommunityToken({
                communityId: communityId,
                recipientCount: recipientCount,
                recipients: recipients,
                amounts: amounts
            }, { from: accounts[0] });

            const airdropProposalId = await communityairdrop_contract.getAirdropProposalIds(1);
            const airdropProposal = await communityairdrop_contract.getAirdropProposal(airdropProposalId.toString());

            const prevBalance = await privierc20testtoken_contract.balanceOf(accounts[7]);

            await communityairdrop_contract.cancelAirdropProposal({
                proposalId: airdropProposal.proposalId,
                communityId: airdropProposal.communityId,
            }, { from: accounts[0] });

            const balance = await privierc20testtoken_contract.balanceOf(accounts[7]);
            assert.equal(balance.sub(prevBalance).toNumber(), 30000);
        })
    })
})