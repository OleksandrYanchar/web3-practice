// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


interface ICarNFT{

    function mintCar(address to, string calldata vin, string calldata uri, address renter) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function getMetadataByTokenId(uint256 tokenId) external view returns (string memory);

    function transferCar(address to, uint256 tokenId) external;

    function rentCar(uint256 tokenId, uint64 durationDays) external;

    function withdrawFunds() external;

    function reclaimCar(uint256 tokenId) external;

    function burn(uint256 tokenId) external;
    
}
