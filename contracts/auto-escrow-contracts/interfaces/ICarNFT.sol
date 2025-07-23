// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


interface ICarNFT{

    function mintCar(address to, string calldata vin, string calldata uri, address renter) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function getMetadataByTokenId(uint256 tokenId) external view returns (string memory);

    function transferCar(address to, uint256 tokenId) external;
}
