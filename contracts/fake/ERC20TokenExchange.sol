// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Exchange Contract for ERC20 Token
 */
contract ERC20TokenExchange{
    /**
    * @dev Exchange struct for ERC20 Token
    */
    struct ERC20Exchange {
        string exchangeName;
        address creatorAddress;
        address exchangeTokenAddress;
        address offerTokenAddress;
        uint initialAmount;
        uint price;
    }

    /**
    * @dev Offer struct for ERC20 Token
    */
    struct ERC20Offer {
        uint exchangeId;
        uint offerId;
        string offerType;
        address creatorAddress;
        uint amount;
        uint price;
    }

    /**
    * @dev Request struct for creating ERC20TokenExchange
    */
    struct CreateERC20TokenExchangeRequest {
        string exchangeName;
        address exchangeTokenAddress;
        address offerTokenAddress;
        uint amount;
        uint price;
    }

    /**
    * @dev Request struct for Place ERC20Token Offer
    */
    struct PlaceERC20TokenOfferRequest {
        uint exchangeId;
        uint amount;
        uint price;
    }

    /**
    * @dev Request struct for cancel Exchange
    */
    struct CancelOfferRequest {
        uint exchangeId;
        uint offerId;
    }

    /**
    * @dev Request struct for deal Exchange
    */
    struct OfferRequest {
        uint exchangeId;
        uint offerId;
    }

    /**
    * @dev count variables for ERC20Token exchange and offer mapping
    */
    uint internal _erc20ExchangeCount;
    uint internal _erc20OfferCount;

    /**
    * @dev variables for storing ERC20TOken Exchange and Offer
    */
    mapping(uint => ERC20Exchange) internal _erc20Exchanges;
    mapping(uint => ERC20Offer) internal _erc20Offers;

    // ----- EVENTS ----- //
    event ERC20TokenExchangeCreated(uint exchangeId, uint initialOfferId);
    event ERC20TokenBuyingOfferPlaced(uint offerId);
    event ERC20TokenSellingOfferPlaced(uint offerId);
    event ERC20TokenBuyingOfferCanceled(uint offerId);
    event ERC20TokenSellingOfferCanceled(uint offerId);
    event ERC20TokenFromOfferBought(uint offerId);
    event ERC20TokenFromOfferSold(uint offerId);

    /**
    * @dev Constructor Function
    */
    constructor() {
        _erc20ExchangeCount = 0;
        _erc20OfferCount = 0;
    }
    
    // ----- VIEWS ----- //
    function getErc20ExchangeCount() external view returns(uint){
        return _erc20ExchangeCount;
    }

    function getErc20OfferCount() external view returns(uint){
        return _erc20OfferCount;
    }

    function getErc20ExchangeAll() external view returns(ERC20Exchange[] memory){
        ERC20Exchange[] memory exchanges = new ERC20Exchange[](_erc20ExchangeCount);
        for(uint i = 1; i <= _erc20ExchangeCount; i++)
            exchanges[i-1] = _erc20Exchanges[i];
        return exchanges;
    }

    function getErc20OfferAll() external view returns(ERC20Offer[] memory){
        ERC20Offer[] memory offers = new ERC20Offer[](_erc20OfferCount);
        for(uint i = 1; i <= _erc20OfferCount; i++)
            offers[i-1] = _erc20Offers[i];
        return offers;
    }

    function getErc20ExchangeById(uint _exchangeId) external view returns(ERC20Exchange memory){
        return _erc20Exchanges[_exchangeId];
    }

    function getErc20OfferById(uint _offerId) external view returns(ERC20Offer memory){
        return _erc20Offers[_offerId];
    }

    // ----- PUBLIC METHODS ----- //
    /**
    * @dev Owner of token can create Exchange of ERC20
    * @dev exchangeTokenAddress address of exchangeToken(ERC20) 
    * @dev offerTokenAddress address of exchangeToken(ERC20) 
    * @dev amount amount of Exchange
    * @dev price token price of Exchange
    */
    function CreateERC20TokenExchange(CreateERC20TokenExchangeRequest memory input, address caller) external {
        IERC20 token = IERC20(input.exchangeTokenAddress);
        require(token.balanceOf(caller) >= input.amount, "TokenExchange.CreateERC20TokenExchange: Your balance is not enough");
        require(input.price > 0, "TokenExchange.CreateERC20TokenExchange: price can't be lower or equal to zero");
        
        token.transferFrom(caller, address(this), input.amount);

        /**
        * @dev store exchange and initial offer
        */
        ERC20Exchange memory exchange;
        exchange.exchangeName = input.exchangeName;
        exchange.creatorAddress = caller;
        exchange.exchangeTokenAddress = input.exchangeTokenAddress;
        exchange.offerTokenAddress = input.offerTokenAddress;
        exchange.initialAmount = input.amount;
        exchange.price = input.price; 

        _erc20ExchangeCount++;
        _erc20Exchanges[_erc20ExchangeCount] = exchange;

        ERC20Offer memory offer;
        offer.exchangeId = _erc20ExchangeCount;
        offer.offerType = "SELL";
        offer.creatorAddress = caller;
        offer.amount = input.amount;
        offer.price = exchange.price;

        _erc20OfferCount++;
        offer.offerId = _erc20OfferCount;
        _erc20Offers[_erc20OfferCount] = offer;

        emit ERC20TokenExchangeCreated(_erc20ExchangeCount, _erc20OfferCount);
    }

    /**
    * @dev someone can create buying offer for ERC20 token exchange
    * @dev exchangeTokenId id of exchange 
    * @dev amount amount of Exchange
    * @dev price token price of Exchange
    */
    function PlaceERC20TokenBuyingOffer(PlaceERC20TokenOfferRequest memory input, address caller) external {
        IERC20 token = IERC20(_erc20Exchanges[input.exchangeId].offerTokenAddress);
        require(
            token.balanceOf(caller) >= (input.price * input.amount), 
            "TokenExchange.PlaceERC20TokenBuyingOffer: you don't have enough balance"
        );
        require(input.price > 0, "TokenExchange.PlaceERC20TokenBuyingOffer: price can't be lower or equal to zero");

        token.transferFrom(caller, address(this), input.price * input.amount);

        /**
        * @dev store buying offer
        */
        ERC20Offer memory offer;
        offer.exchangeId = input.exchangeId;
        offer.offerType = "BUY";
        offer.creatorAddress = caller;
        offer.amount = input.amount;
        offer.price = input.price;

        _erc20OfferCount++;
        offer.offerId = _erc20OfferCount;
        _erc20Offers[_erc20OfferCount] = offer;

        emit ERC20TokenBuyingOfferPlaced(_erc20OfferCount);
    }

    /**
    * @dev owner of token can create selling offer for ERC20 token exchange
    * @dev exchangeTokenId id of exchange 
    * @dev amount amount of Exchange
    * @dev price token price of Exchange
    */
    function PlaceERC20TokenSellingOffer(PlaceERC20TokenOfferRequest memory input, address caller) external {
        IERC20 token = IERC20(_erc20Exchanges[input.exchangeId].exchangeTokenAddress);
        require(
            token.balanceOf(caller) >= input.amount, 
            "TokenExchange.PlaceERC20TokenSellingOffer: you don't have enough balance"
        );
        require(input.price > 0, "TokenExchange.PlaceERC20TokenSellingOffer: price can't be lower or equal to zero");

        token.transferFrom(caller, address(this), input.amount);

        /**
        * @dev store selling offer
        */
        ERC20Offer memory offer;
        offer.exchangeId = input.exchangeId;
        offer.offerType = "SELL";
        offer.creatorAddress = caller;
        offer.amount = input.amount;
        offer.price = input.price;

        _erc20OfferCount++;
        offer.offerId = _erc20OfferCount;
        _erc20Offers[_erc20OfferCount] = offer;

        emit ERC20TokenSellingOfferPlaced(_erc20OfferCount);
    }

    /**
    * @dev creator of buying offer can cancel his ERC20Token BuyingOffer
    * @dev exchangeTokenId id of exchange 
    * @dev offerId id of offer
    */
    function CancelERC20TokenBuyingOffer(CancelOfferRequest memory input, address caller) external{
        ERC20Offer memory offer = _erc20Offers[input.offerId];
        IERC20 token = IERC20(_erc20Exchanges[input.exchangeId].offerTokenAddress);
        require(offer.creatorAddress == caller, "TokenExchange.CancelERC20TokenBuyingOffer: should be owner");
        require(offer.exchangeId == input.exchangeId, "TokenExchange.CancelERC20TokenBuyingOffer: should be the same exchangeId");
        require(
            keccak256(abi.encodePacked(offer.offerType)) == keccak256(abi.encodePacked("BUY")), 
            "TokenExchange.CancelERC20TokenBuyingOffer: should be the buying offer"
        );

        require(
            token.balanceOf(address(this)) >= (offer.price * offer.amount),
            "TokenExchange.CancelERC20TokenBuyingOffer: you don't have enough balance"
        );
        
        token.transfer(caller, offer.price * offer.amount);            
        delete _erc20Offers[input.offerId];

        emit ERC20TokenBuyingOfferCanceled(input.offerId);
    }

    /**
    * @dev creator of selling offer can cancel his ERC20 SellingOffer
    * @dev exchangeTokenId id of exchange 
    * @dev offerId id of offer
    */
    function CancelERC20TokenSellingOffer(CancelOfferRequest memory input, address caller) external{
        ERC20Offer memory offer = _erc20Offers[input.offerId];
        IERC20 token = IERC20(_erc20Exchanges[input.exchangeId].exchangeTokenAddress);
        require(offer.creatorAddress == caller, "TokenExchange.CancelERC20TokenSellingOffer: should be owner");
        require(offer.exchangeId == input.exchangeId, "TokenExchange.CancelERC20TokenSellingOffer: should be the same exchangeId");
        require(
            keccak256(abi.encodePacked(offer.offerType)) == keccak256(abi.encodePacked("SELL")), 
            "TokenExchange.CancelERC20TokenSellingOffer: should be the selling offer"
        );
        require(
            token.balanceOf(address(this)) >= offer.amount, 
            "TokenExchange.CancelERC20TokenSellingOffer: you don't have enough balance"
        );
        
        token.transfer(caller, offer.amount);
        delete _erc20Offers[input.offerId];

        emit ERC20TokenSellingOfferCanceled(input.offerId);
    }

    /**
    * @dev someone can buy token(ERC20) from selling offer
    * @dev exchangeTokenId id of exchange 
    * @dev offerId id of offer
    */
    function BuyERC20TokenFromOffer(OfferRequest memory input, address caller) external{
        ERC20Offer memory offer = _erc20Offers[input.offerId];
        IERC20 offerToken = IERC20(_erc20Exchanges[input.exchangeId].offerTokenAddress);
        IERC20 exchangeToken = IERC20(_erc20Exchanges[input.exchangeId].exchangeTokenAddress);

        require(offer.exchangeId == input.exchangeId, "TokenExchange.BuyERC20TokenFromOffer: should be the same exchangeId");
        require(
            keccak256(abi.encodePacked(offer.offerType)) == keccak256(abi.encodePacked("SELL")), 
            "TokenExchange.BuyERC20TokenFromOffer: should be the selling offer"
        );
        require(
            offerToken.balanceOf(caller) >= (offer.price * offer.amount),
            "TokenExchange.BuyERC20TokenFromOffer: you don't have enough balance"
        );

        require(
            exchangeToken.balanceOf(address(this)) >= offer.amount,
            "TokenExchange.BuyERC20TokenFromOffer: you don't have enough balance"
        );

        offerToken.transferFrom(caller, offer.creatorAddress, offer.price * offer.amount); 
        exchangeToken.transfer(caller, offer.amount);
        delete _erc20Offers[input.offerId];

        emit ERC20TokenFromOfferBought(input.offerId);
    }
    /**
    * @dev owner of token can sell token(ERC20) from buying offer
    * @dev exchangeTokenId id of exchange 
    * @dev offerId id of offer
    */
    function SellERC20TokenFromOffer(OfferRequest memory input, address caller) external{
        ERC20Offer memory offer = _erc20Offers[input.offerId];
        IERC20 offerToken = IERC20(_erc20Exchanges[input.exchangeId].offerTokenAddress);
        IERC20 exchangeToken = IERC20(_erc20Exchanges[input.exchangeId].exchangeTokenAddress);

        require(offer.exchangeId == input.exchangeId, "TokenExchange.SellERC20TokenFromOffer: should be the same exchangeId");
        require(
            keccak256(abi.encodePacked(offer.offerType)) == keccak256(abi.encodePacked("BUY")), 
            "TokenExchange.SellERC20TokenFromOffer: should be the buying offer"
        );
        require(
            offerToken.balanceOf(address(this)) >= (offer.price * offer.amount),
            "TokenExchange.SellERC20TokenFromOffer: you don't have enough balance"
        );

        require(
            exchangeToken.balanceOf(offer.creatorAddress) >= offer.amount,
            "TokenExchange.SellERC20TokenFromOffer: you don't have enough balance"
        );

        offerToken.transfer(offer.creatorAddress, offer.price * offer.amount); 
        exchangeToken.transferFrom(offer.creatorAddress, caller, offer.amount);
        delete _erc20Offers[input.offerId];

        emit ERC20TokenFromOfferSold(input.offerId);
    }
}