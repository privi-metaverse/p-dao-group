const ERC20TokenExchange = artifacts.require("ERC20TokenExchange");
const IncreasingPriceERC721Auction = artifacts.require("IncreasingPriceERC721Auction");
const PRIVIERC20TestToken = artifacts.require("PRIVIERC20TestToken");
const ERC721Mock = artifacts.require('ERC721Mock');

const PRIVIDAO = artifacts.require("PRIVIDAO");
const ManageCommunityToken = artifacts.require("ManageCommunityToken");
const CommunityEjectMember = artifacts.require("CommunityEjectMember");
const CommunityBid = artifacts.require("CommunityBid");

const {
    BN,           // Big Number support
    time,
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const { ZERO_ADDRESS } = constants;
const minute = 60;

function ethValue(amount) {
    return web3.utils.toWei(amount.toString(), 'ether');
}

const mine = (timestamp) => {
    return new Promise((resolve, reject) => {
      web3.currentProvider.send(
        {
          jsonrpc: '2.0',
          method: 'evm_mine',
          id: Date.now(),
          params: [timestamp],
        },
        (err, res) => {
          if (err) return reject(err);
          resolve(res);
        }
      );
    });
};

contract("CommunityBid", (accounts) => {
    var erc20tokenexchange_contract;
    var increasingpriceerc721auction_contract;
    var privierc20testtoken_contract;
    var privierc721mock_contract;

    var prividao_contract;
    var managecommunitytoken_contract;
    var communityejectmember_contract;
    var communitybid_contract;

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

        privierc721mock_contract = await ERC721Mock.new('test', 'TEST', { from: accounts[0] });

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

        communitybid_contract = await CommunityBid.new(
            prividao_contract.address,
            managecommunitytoken_contract.address,
            communityejectmember_contract.address,
            { from: accounts[0] }
        );

        await prividao_contract.setEjectMemberContractAddress(communityejectmember_contract.address);

        await managecommunitytoken_contract.registerToken("USD Coin", "USDC", privierc20testtoken_contract.address);
        await managecommunitytoken_contract.registerToken("Uniswap", "UNI", privierc20testtoken_contract.address);
        await managecommunitytoken_contract.registerToken("tokenSymbol", "tokenSymbol", privierc20testtoken_contract.address);

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

        await privierc20testtoken_contract.mint(communityAddress, ethValue(10000000));
        await privierc20testtoken_contract.mint(escrowAddress, ethValue(10000000));
        await privierc20testtoken_contract.mint(stakingAddress, ethValue(10000000));

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

        await privierc721mock_contract.mint(accounts[0], 0);

        let now = Math.round(Date.now() / 1000);
        await mine(now + 10);

        const startTime = now + minute;
        const endTime = startTime + 10 * minute;
        const reservePrice = 10;
        const bidIncrement = 1;
        const hash = '0x6c00000000000000000000000000000000000000000000000000000000000000';

        await privierc721mock_contract.approve(increasingpriceerc721auction_contract.address, 0, { from: accounts[0] });

        await increasingpriceerc721auction_contract.createAuction({
            tokenAddress: privierc721mock_contract.address,
            tokenId: 0,
            mediaSymbol: "mediaSymbol",
            tokenSymbol: "tokenSymbol",
            reservePrice: ethValue(reservePrice),
            ipfsHash: hash,
            bidIncrement: ethValue(bidIncrement),
            startTime: startTime,
            endTime: endTime,
            bidToken: privierc20testtoken_contract.address,
        }, { from: accounts[0] });
        assert.strictEqual(parseInt(await privierc721mock_contract.balanceOf(accounts[0])), 0);
        await mine(startTime + 1);
    })

    describe("PlaceBidProposal", () => {
        it("not working if amount is lower than zero", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const mediaSymbol = "mediaSymbol";
            const tokenSymbol = "tokenSymbol";
            const amount = 0;

            await privierc20testtoken_contract.approve(communitybid_contract.address, ethValue(amount), {from: accounts[7]});
            await privierc20testtoken_contract.approve(increasingpriceerc721auction_contract.address, ethValue(amount), {from: accounts[9]});
            try {
                await communitybid_contract.PlaceBidProposal({
                    communityId: communityId,
                    mediaSymbol: mediaSymbol,
                    tokenSymbol: tokenSymbol,
                    amount: ethValue(amount)
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "amount can't be lower than zero");
        })

        it("not working if tokenSymbol is invalid", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const mediaSymbol = "mediaSymbol";
            const tokenSymbol = "tokenSymbol1";
            const amount = 12;

            await privierc20testtoken_contract.approve(communitybid_contract.address, ethValue(amount), {from: accounts[7]});
            await privierc20testtoken_contract.approve(increasingpriceerc721auction_contract.address, ethValue(amount), {from: accounts[9]});
            try {
                await communitybid_contract.PlaceBidProposal({
                    communityId: communityId,
                    mediaSymbol: mediaSymbol,
                    tokenSymbol: tokenSymbol,
                    amount: ethValue(amount)
                }, { from: accounts[0] })
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "token contract address is not valid");
        })

        it("works well", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const mediaSymbol = "mediaSymbol";
            const tokenSymbol = "tokenSymbol";
            const amount = 12;

            await privierc20testtoken_contract.approve(communitybid_contract.address, ethValue(amount), {from: accounts[7]});
            await privierc20testtoken_contract.approve(increasingpriceerc721auction_contract.address, ethValue(amount), {from: accounts[9]});

            
            const prevCount = await communitybid_contract.getBidProposalCount();

            await communitybid_contract.PlaceBidProposal({
                communityId: communityId,
                mediaSymbol: mediaSymbol,
                tokenSymbol: tokenSymbol,
                amount: ethValue(amount)
            }, { from: accounts[0] })

            const count = await communitybid_contract.getBidProposalCount();
            assert.strictEqual(count.sub(prevCount).toNumber(), 1);
        })
    })

    describe("VotePlaceBidProposal", () => {
        it("not working if not founder", async () => {
            const bidProposalId = await communitybid_contract.getBidProposalIds(0);
            const bidProposal = await communitybid_contract.getBidProposal(bidProposalId.toString());

            const amount = 12;
            await privierc20testtoken_contract.approve(communitybid_contract.address, ethValue(amount), {from: accounts[9]});

            try {            
                await communitybid_contract.VotePlaceBidProposal({
                    proposalId: bidProposal.proposalId,
                    communityId: bidProposal.communityId,
                    decision: true
                }, { from: accounts[4] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "should be founder")
        })

        it("not working if vote second time", async () => {
            const bidProposalId = await communitybid_contract.getBidProposalIds(0);
            const bidProposal = await communitybid_contract.getBidProposal(bidProposalId.toString());

            const amount = 12;
            await privierc20testtoken_contract.approve(communitybid_contract.address, ethValue(amount), {from: accounts[9]});

            await communitybid_contract.VotePlaceBidProposal({
                proposalId: bidProposal.proposalId,
                communityId: bidProposal.communityId,
                decision: true
            }, { from: accounts[0] });

            try {            
                await communitybid_contract.VotePlaceBidProposal({
                    proposalId: bidProposal.proposalId,
                    communityId: bidProposal.communityId,
                    decision: true
                }, { from: accounts[0] });
            } catch(error) {
                thrownError = error;
            }
            assert.include(thrownError.message, "voter can not vote second time")
        })

        it("works well", async () => {
            const bidProposalId = await communitybid_contract.getBidProposalIds(0);
            const bidProposal = await communitybid_contract.getBidProposal(bidProposalId.toString());

            const amount = 12;
            await privierc20testtoken_contract.approve(communitybid_contract.address, ethValue(amount), {from: accounts[9]});

            const prevBalance = await privierc20testtoken_contract.balanceOf(accounts[9]);
            
            await communitybid_contract.VotePlaceBidProposal({
                proposalId: bidProposal.proposalId,
                communityId: bidProposal.communityId,
                decision: true
            }, { from: accounts[1] });

            await communitybid_contract.VotePlaceBidProposal({
                proposalId: bidProposal.proposalId,
                communityId: bidProposal.communityId,
                decision: true
            }, { from: accounts[2] });

            const balance = await privierc20testtoken_contract.balanceOf(accounts[9]);
            assert.strictEqual(prevBalance.sub(balance).toString(), ethValue(amount));
        })
    })

    describe("cancelBidProposal", () => {
        it("works well", async () => {
            const communityId = await prividao_contract.getCommunityIdByIndex(0);
            const mediaSymbol = "mediaSymbol";
            const tokenSymbol = "tokenSymbol";
            const amount = 12;

            await privierc20testtoken_contract.approve(communitybid_contract.address, ethValue(amount), {from: accounts[7]});
            await privierc20testtoken_contract.approve(increasingpriceerc721auction_contract.address, ethValue(amount), {from: accounts[9]});

            await communitybid_contract.PlaceBidProposal({
                communityId: communityId,
                mediaSymbol: mediaSymbol,
                tokenSymbol: tokenSymbol,
                amount: ethValue(amount)
            }, { from: accounts[0] })
            
            const bidProposalId = await communitybid_contract.getBidProposalIds(1);
            const bidProposal = await communitybid_contract.getBidProposal(bidProposalId.toString());

            const prevBalance = await privierc20testtoken_contract.balanceOf(accounts[7]);

            await communitybid_contract.cancelBidProposal({
                proposalId: bidProposal.proposalId,
                communityId: bidProposal.communityId,
            }, { from: accounts[0] });

            const balance = await privierc20testtoken_contract.balanceOf(accounts[7]);
            assert.equal(balance.sub(prevBalance).toString(), ethValue(amount));
        })
    })
})