// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/access/AccessControl.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";


import {Roles} from "../libraries/Roles.sol";
import {Errors} from "../libraries/Errors.sol";

import {ICarNFT} from "../interfaces/ICarNFT.sol";


abstract contract CarNFT is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard, ICarNFT{
    uint256 private _tokenId = 1;
    mapping(uint256 => address) private _tokenToRenter;


    event CarMinted(address indexed to, string vin, uint256 tokenId);
    event CarBurned(uint256 tokenId);
    event CarTransferred(uint256 tokenId, address to);

    constructor() ERC721("CarNFT", "CAR") {
        _grantRole(AccessControl.DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Roles.DEALER_MANAGER_ROLE, msg.sender);
    }


    function mintCar(address to, string calldata vin, string calldata uri) public onlyRole(Roles.DEALER_MANAGER_ROLE) nonReentrant {
        if (to == address(0)) revert Errors.InvalidTransfer();
        
        if (bytes(vin).length != 17) revert Errors.InvalidVinLength(); 

        uint256 tokenId = _tokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit CarMinted(to, vin, tokenId);
    }


    function transferCar(address to, uint256 tokenId) public override(ICarNFT) nonReentrant {
        if (!hasRole(Roles.DEALER_MANAGER_ROLE, msg.sender)) revert Errors.NotAuthorized();
        
        _tokenToRenter[tokenId] = to;
        _transfer(ownerOf(tokenId), to, tokenId);
        emit CarTransferred(tokenId, to);
    }


    function burn(uint256 tokenId) external nonReentrant { 
        if (!_isAuthorized(ownerOf(tokenId), msg.sender, tokenId) && !hasRole(Roles.DEALER_MANAGER_ROLE, msg.sender)) revert Errors.NotAuthorized();

        _burn(tokenId);

        emit CarBurned(tokenId);
    }


    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage, ICarNFT) returns (string memory){
        return super.tokenURI(tokenId);
    }


    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl, ERC721URIStorage, ICarNFT) returns (bool){
        return super.supportsInterface(interfaceId);
    }


    function getMetadataByTokenId(uint256 tokenId) public view returns (string memory){
        return tokenURI(tokenId);
    }
}
