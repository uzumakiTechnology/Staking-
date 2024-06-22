// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Counters.sol"; // keep track
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";

contract Marketplace is ERC721URIStorage {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;   // variables with _ before variables name represent for private
    Counters.Counter private _itemsSold; // keep track how many item have been sold

    uint256 listingPrice = 0.0025 ether; // default

    address payable owner;


    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool status; // sold or unsold
    }

    mapping(uint256 => MarketItem) private idMarketItem;


    event idMarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    modifier onlyOwner{
        require(msg.sender == owner,"Only owner of the contract can change the listing price");
        _;
    }

    constructor() ERC721("NFT Marketplace", "MYNFT"){
        owner = payable(msg.sender);
    }

    // who create an NFT will have to pay a certain amount to DEX
    // this function help the owner modify the listing price
    function updateListingPrice(uint256 _listingPrice)public payable onlyOwner{
        listingPrice = _listingPrice;

    }

    // allow user to check current listing price
    function getListingPrice() public view returns(uint256){
        return listingPrice;
    }

    // Create NFT token function
    // pass the token URI(url) as well
    function createToken(string memory tokenURI, uint256 price) public payable returns(uint256){
        // returns uint256 represent for ID of that token
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender,newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        createMarketItem(newTokenId, price);
        return newTokenId;
    }

    // user create market items for sales in our market
    function createMarketItem(uint256 tokenId, uint256 price) private{
        require(price > 0,"Price must not be zero");
        require(msg.value == listingPrice,"Price must be equal to listing price");

        // initialize
        idMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );

        // transfer to us
        _transfer(msg.sender, address(this), tokenId);
        emit idMarketItemCreated(tokenId, msg.sender, address(this), price, false);
    }

    // Re-sale token
    function reSellToken(uint256 tokenId, uint256 price) public payable{
        require(idMarketItem[tokenId].owner == msg.sender,"Only item owner can perform this action");

        require(msg.value == listingPrice,"Price must be equal to listing price");

        idMarketItem[tokenId].status = false;
        idMarketItem[tokenId].price = price;
        idMarketItem[tokenId].seller = payable(msg.sender);
        idMarketItem[tokenId].owner = payable(address(this));

        // if SO buy NFT, this variables will increase, but Resell is decrease
        _itemsSold.decrement();
        _transfer(msg.sender, address(this), tokenId);
    }

    // Create market sales
    function createMarketSale(uint256 tokenId) public payable{
        uint256 price = idMarketItem[tokenId].price;

        require(msg.value == price,"Please submit the correct asking price in order to complete the purchases");
        idMarketItem[tokenId].owner = payable(msg.sender);
        idMarketItem[tokenId].status = true;
        idMarketItem[tokenId].owner = payable(address(0)); // NFT not belong to this contract
        _itemsSold.increment();
 
        _transfer(address(this), msg.sender, tokenId);
        payable(owner).transfer(listingPrice); // commission (hoa hồng) Transfer listing price to the contract owner
        payable(idMarketItem[tokenId].seller).transfer(msg.value); // transfers Ether from the current contract to the seller's address,  ensures that the seller receives the payment for the NFT directly from the buyer.
    }

    // get unsold nft data
    function fetchMarketItem()public view returns(MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unSoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        // loop
        MarketItem[] memory items = new MarketItem[](unSoldItemCount); // dynamic array of MarketItem structs with a length equal to the number of unsold items. This array will store the unsold items retrieved from the marketplace.
        for(uint256 i =0; i< itemCount; i++){
            if(idMarketItem[i+1].owner == address(this)){ // belong to this contract
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }


    // 
    function fetchMyNFT() public view returns(MarketItem[] memory){
        uint256 totalCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;
        
        for(uint256 i=0; i < totalCount;i++){
            if(idMarketItem[i+1].owner == msg.sender){
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for(uint256 i = 0; i < totalCount; i++){
            if(idMarketItem[i+1].owner == msg.sender){
                uint256 currentId = i +1;
                MarketItem storage currentItem =  idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // single user item
    function fetchItemsListed() public view returns(MarketItem[] memory){
        uint256 totalCount = _tokenIds.current(); // total token in market
        uint256 itemCount = 0 ; // count number of items listed by seller
        uint256 currentIndex = 0; // keep track the index of the item being add to items arr

        for (uint256 i =0; i < totalCount; i++){
            if(idMarketItem[i+1].seller == msg.sender){
                itemCount +=1;
            }
            
        }
        /**
        In this contract, the tokenId values for NFTs start from 1 
        because the contract is designed to mimic token IDs as non-zero 
        positive integers.
        */
        MarketItem[] memory items = new MarketItem[](itemCount); // arr with length of itemCount
        for(uint256 i = 0; i < totalCount; i++){
            if(idMarketItem[i+1].seller == msg.sender){
                uint256 currentId = i +1;

                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem; // to arr
                currentIndex += 1;
            }
        }
        return items;
    }

}