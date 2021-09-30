// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IncreasingPriceERC721Auction
 * @dev Create, accept, reset and cancel an auction of ERC721 token
 */
contract IncreasingPriceERC721Auction is ERC721Holder, Ownable, ReentrancyGuard {
    mapping(string => mapping(string => Auction)) public auctions;

    struct Auction {
        address tokenAddress;
        uint256 tokenId;
        address owner;
        uint256 reservePrice;
        bytes32 ipfsHash;
        uint64 startTime;
        uint64 endTime;
        uint256 currentBid;
        uint64 bidIncrement;
        address payable currentBidder;
        IERC20 bidToken;
    }

    struct CreateAuctionRequest {
        address tokenAddress;
        uint256 tokenId;
        string mediaSymbol;
        string tokenSymbol;
        uint256 reservePrice;
        bytes32 ipfsHash;
        uint256 bidIncrement;
        uint256 startTime;
        uint256 endTime;
        address bidToken;
    }
    struct WithdrawAuctionRequest {
        string mediaSymbol;
        string tokenSymbol;
    }
    struct PlaceBidRequest {
        string mediaSymbol;
        string tokenSymbol;
        address _address;
        address fromAddress;
        uint256 amount;
    }
    struct CancelAuctionRequest {
        string mediaSymbol;
        string tokenSymbol;
    }
    struct ResetAuctionRequest {
        string mediaSymbol;
        string tokenSymbol;
        uint256 reservePrice;
        uint256 bidIncrement;
        uint256 endTime;
        bytes32 ipfsHash;
    }

    event AuctionCreated(
        string indexed _mediaSymbol,
        string indexed _tokenSymbol,
        address indexed _owner,
        uint256 _reservePrice,
        uint256 _bidIncrement,
        uint256 _startTime,
        uint256 _endTime
    );
    event Bid(
        string indexed _mediaSymbol,
        string indexed _tokenSymbol,
        address indexed _bidder,
        uint256 _amount
    );
    event AuctionAccepted(
        string indexed _mediaSymbol,
        string indexed _tokenSymbol,
        address indexed _bidder,
        uint256 _amount
    );
    event AuctionCanceled(
        string indexed _mediaSymbol,
        string indexed _tokenSymbol,
        address indexed _bidder,
        uint256 _amount
    );
    event AuctionRestarted(
        string indexed _mediaSymbol,
        string indexed _tokenSymbol,
        address indexed _oldBidder,
        uint256 reservePrice,
        uint256 newReservePrice,
        uint256 newBidIncrement,
        uint256 newEndTime
    );

    modifier onlyAuctionOwner(string memory _mediaSymbol, string memory _tokenSymbol) {
        require(auctions[_mediaSymbol][_tokenSymbol].owner == msg.sender, "Sender is not owner of auction");
        _;
    }

    modifier _requireStoredWith64Bits(uint256 _value) {
        require(_value <= 18446744073709551615, "Value needs to be stored in 64Bits");
        _;
    }

    /**
     * @dev createAuction creates auction on given `MediaSymbol`, under confitions:
     * @dev - owner needs to have some amount of given `MediaSymbol`
     * @dev - `TokenSymbol` exist
     * @dev - `StartTime` is from the future and before `EndTime`
     */
    function createAuction(CreateAuctionRequest memory input)
        external
        _requireStoredWith64Bits(input.startTime)
        _requireStoredWith64Bits(input.endTime)
        _requireStoredWith64Bits(input.bidIncrement)
    {
        IERC721 ierc721 = IERC721(input.tokenAddress);
        ierc721.safeTransferFrom(msg.sender, address(this), input.tokenId);

        require(auctions[input.mediaSymbol][input.tokenSymbol].endTime == 0, "Auction already exists");
        require(input.endTime > input.startTime, "Auction can not end before starts");
        require(input.startTime > block.timestamp, "Auction can not start in the past");

        auctions[input.mediaSymbol][input.tokenSymbol] = Auction(
            input.tokenAddress,
            input.tokenId,
            msg.sender,
            input.reservePrice,
            input.ipfsHash,
            uint64(input.startTime),
            uint64(input.endTime),
            input.reservePrice,
            uint64(input.bidIncrement),
            payable(address(0)),
            IERC20(input.bidToken)
        );
        Auction memory _auction = auctions[input.mediaSymbol][input.tokenSymbol];

        emit AuctionCreated(
            input.mediaSymbol,
            input.tokenSymbol,
            _auction.owner,
            uint256(_auction.reservePrice),
            uint256(_auction.bidIncrement),
            uint256(_auction.startTime),
            uint256(_auction.endTime)
        );
    }

    /**
     * @dev retrieves the Auction and a bool indicating `canBid`
     * @param mediaSymbol of ERC721 of the auction
     * @param tokenSymbol of ERC721 of the auction
     */
    function getAuctionsByPartialCompositeKey(string memory mediaSymbol, string memory tokenSymbol)
        external
        view
        returns (Auction memory _auction, bool canBid)
    {
        _auction = auctions[mediaSymbol][tokenSymbol];

        canBid = _isOnAuction(_auction.startTime, _auction.endTime);
    }

    /**
     * @dev placeBid adds bid to auction if:
     * @dev - auction is open,
     * @dev - amount of the bid is higher than ReservePrive or higher than previous bid incremented by BidIncrement,
     * @dev - funds weren't withdrown yet.
     * @dev funds of bid are transfered to auction address.
     */
    function placeBid(PlaceBidRequest memory input) external payable nonReentrant {
        Auction storage _auction = auctions[input.mediaSymbol][input.tokenSymbol];

        require(_isOnAuction(_auction.startTime, _auction.endTime), "Auction should be active");
        require(input.amount > _auction.currentBid, "Bid should be greater than current bid");
        require(
            input.amount > 0 && (input.amount - _auction.currentBid > _auction.bidIncrement),
            "Bid should be greater than bid increment"
        );

        if (msg.sender != address(0) && _auction.currentBidder != address(0)) {
            _auction.bidToken.transfer(_auction.currentBidder, _auction.currentBid);
        }
        _auction.currentBid = input.amount;
        _auction.currentBidder = payable(input.fromAddress);

        _auction.bidToken.transferFrom(input.fromAddress, address(this), input.amount);

        emit Bid(input.mediaSymbol, input.tokenSymbol, input.fromAddress, input.amount);
    }

    /**
     * @dev withdrawAuction an be called when wheren't withdrawn yet and bid was made.
     * @dev Media are transfered to the bidder and funds to the owner of the auction.
     */
    function withdrawAuction(WithdrawAuctionRequest memory input)
        external
        onlyAuctionOwner(input.mediaSymbol, input.tokenSymbol)
    {
        Auction memory _auction = auctions[input.mediaSymbol][input.tokenSymbol];
        require(
            _auction.currentBidder != address(0),
            "Unable to withdraw an empty auction, you must cancel it"
        );

        IERC721 ierc721 = IERC721(_auction.tokenAddress);
        ierc721.safeTransferFrom(address(this), _auction.currentBidder, _auction.tokenId);

        _auction.bidToken.transfer(_auction.owner, _auction.currentBid);

        _removeAuction(input.mediaSymbol, input.tokenSymbol);
        emit AuctionAccepted(
            input.mediaSymbol,
            input.tokenSymbol,
            _auction.currentBidder,
            _auction.currentBid
        );
    }

    /**
     * @dev resetAuction resets auction if:
     * @dev  - is called before `EndTime` plus one day
     * @dev If bid was made, funds are returned to bidder. It's parameters are set from given input.
     */
    function resetAuction(ResetAuctionRequest memory input)
        external
        onlyAuctionOwner(input.mediaSymbol, input.tokenSymbol)
        _requireStoredWith64Bits(input.bidIncrement)
        _requireStoredWith64Bits(input.endTime)
    {
        Auction storage _auction = auctions[input.mediaSymbol][input.tokenSymbol];
        _requireNotEndedDayAuction(_auction.endTime);
        require(input.reservePrice > _auction.currentBid, "The new price should be greater than currentBid");
        require(input.endTime > block.timestamp, "End date must be older than now");

        if (_auction.currentBidder != address(0)) {
            _auction.bidToken.transfer(_auction.currentBidder, _auction.currentBid);
        }
        emit AuctionRestarted(
            input.mediaSymbol,
            input.tokenSymbol,
            _auction.currentBidder,
            _auction.currentBid,
            input.reservePrice,
            input.bidIncrement,
            input.endTime
        );

        _auction.startTime = uint64(block.timestamp);
        _auction.endTime = uint64(input.endTime);
        _auction.reservePrice = uint64(input.reservePrice);
        _auction.ipfsHash = input.ipfsHash;
        _auction.bidIncrement = uint64(input.bidIncrement);
        _auction.currentBid = uint64(input.reservePrice);
        _auction.currentBidder = payable(address(0));
    }

    /**
     * @dev cancelAuction cancels auction if condition are met:
     * @dev - is called before `EndTime` plus one day
     * @dev If bid was made, funds are returned to bidder. Media are returned to owner.
     */
    function cancelAuction(CancelAuctionRequest memory input)
        external
        onlyAuctionOwner(input.mediaSymbol, input.tokenSymbol)
    {
        Auction memory _auction = auctions[input.mediaSymbol][input.tokenSymbol];
        _requireNotEndedDayAuction(_auction.endTime);

        if (_auction.currentBidder != address(0)) {
            _auction.bidToken.transfer(_auction.currentBidder, _auction.currentBid);
        }

        IERC721 ierc721 = IERC721(_auction.tokenAddress);
        ierc721.safeTransferFrom(address(this), _auction.owner, _auction.tokenId);
        _removeAuction(input.mediaSymbol, input.tokenSymbol);

        emit AuctionCanceled(
            input.mediaSymbol,
            input.tokenSymbol,
            _auction.currentBidder,
            _auction.currentBid
        );
    }

    function _removeAuction(string memory _mediaSymbol, string memory _tokenSymbol) internal {
        delete (auctions[_mediaSymbol][_tokenSymbol]);
    }

    function _isOnAuction(uint64 _startTime, uint64 _endTime) internal view returns (bool) {
        return (block.timestamp > _startTime) && (block.timestamp < _endTime);
    }

    function _requireNotEndedDayAuction(uint256 _endTime) internal view {
        require(block.timestamp < (_endTime + 1 days), "Auction has ended already");
    }
}
