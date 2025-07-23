// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/access/AccessControl.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {Roles} from "../libraries/Roles.sol";
import {Errors} from "../libraries/Errors.sol";
import {ICarNFT} from "../interfaces/ICarNFT.sol";

/// @title CarNFT with rent/payment support
contract CarNFT is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard, ICarNFT {
    using SafeERC20 for IERC20;

    uint256 private _nextTokenId = 1;
    uint256 public rentPricePerDay;
    IERC20 public paymentToken;

    mapping(uint256 => address) private _tokenToRenter;
    mapping(uint256 => uint64) private _rentExpires;
    mapping(address => uint256) private _pendingWithdrawals;

    event CarMinted(address indexed to, string vin, uint256 indexed tokenId);
    event CarRented(uint256 indexed tokenId, address indexed renter, uint64 expires);
    event CarTransferred(uint256 indexed tokenId, address indexed to);
    event CarBurned(uint256 indexed tokenId);
    event RentPriceUpdated(uint256 newPrice);
    event PaymentTokenUpdated(address indexed token);
    event Withdrawal(address indexed account, uint256 amount);

    constructor(address _paymentToken, uint256 _rentPricePerDay) ERC721("CarNFT", "CAR") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Roles.DEALER_MANAGER_ROLE, msg.sender);
        paymentToken = IERC20(_paymentToken);
        rentPricePerDay = _rentPricePerDay;
    }

    function setPaymentToken(IERC20 _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        paymentToken = _token;
        emit PaymentTokenUpdated(address(_token));
    }

    function setRentPrice(uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rentPricePerDay = _price;
        emit RentPriceUpdated(_price);
    }

    function mintCar(
        address to,
        string calldata vin,
        string calldata uri,
        address renter
    ) external override(ICarNFT) onlyRole(Roles.DEALER_MANAGER_ROLE) nonReentrant {
        if (to == address(0)) revert Errors.InvalidTransfer();
        if (bytes(vin).length != 17) revert Errors.InvalidVinLength();

        uint256 tokenId = _nextTokenId;
        unchecked { _nextTokenId = tokenId + 1; }

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        if (renter != address(0)) {
            _tokenToRenter[tokenId] = renter;
        }
        emit CarMinted(to, vin, tokenId);
    }

    function transferCar(address to, uint256 tokenId)
        external override(ICarNFT)
        onlyRole(Roles.DEALER_MANAGER_ROLE)
        nonReentrant
    {
        _tokenToRenter[tokenId] = to;
        _transfer(ownerOf(tokenId), to, tokenId);
        emit CarTransferred(tokenId, to);
    }

    function tokenURI(uint256 tokenId)
        public view
        override(ERC721, ERC721URIStorage, ICarNFT)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view
        override(ERC721, ERC721URIStorage, AccessControl, ICarNFT)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getMetadataByTokenId(uint256 tokenId)
        external view
        override(ICarNFT)
        returns (string memory)
    {
        return tokenURI(tokenId);
    }

    function rentCar(uint256 tokenId, uint64 durationDays)
        external nonReentrant
    {
        if (durationDays == 0) revert Errors.InvalidDuration();
        uint256 cost = rentPricePerDay * durationDays;
        paymentToken.safeTransferFrom(msg.sender, address(this), cost);

        address origOwner = ownerOf(tokenId);
        uint64 expires = uint64(block.timestamp + durationDays * 1 days);

        safeTransferFrom(origOwner, msg.sender, tokenId);
        _tokenToRenter[tokenId] = msg.sender;
        _rentExpires[tokenId] = expires;

        _pendingWithdrawals[origOwner] += cost;
        emit CarRented(tokenId, msg.sender, expires);
    }

    function withdrawFunds() external nonReentrant {
        uint256 amount = _pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds available");
        _pendingWithdrawals[msg.sender] = 0;
        paymentToken.safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    function reclaimCar(uint256 tokenId)
        external onlyRole(Roles.DEALER_MANAGER_ROLE) nonReentrant
    {
        uint64 expires = _rentExpires[tokenId];
        require(expires != 0 && block.timestamp > expires, "Rental not expired");
        safeTransferFrom(ownerOf(tokenId), msg.sender, tokenId);
        delete _tokenToRenter[tokenId];
        delete _rentExpires[tokenId];
    }

    function burn(uint256 tokenId)
        external nonReentrant
    {
        address owner = ownerOf(tokenId);
        require(_isAuthorized(owner, msg.sender, tokenId), "Not authorized");
        _burnWithCleanup(tokenId);
        emit CarBurned(tokenId);
    }

    function userOf(uint256 tokenId) external view returns (address) {
        return _rentExpires[tokenId] >= block.timestamp ? _tokenToRenter[tokenId] : address(0);
    }

    function rentExpiresAt(uint256 tokenId) external view returns (uint64) {
        return _rentExpires[tokenId];
    }

    function getPendingWithdrawal(address account) external view returns (uint256) {
        return _pendingWithdrawals[account];
    }

    function _isAuthorized(
        address owner,
        address spender,
        uint256 tokenId
    ) internal view virtual override returns (bool) {
        return hasRole(Roles.DEALER_MANAGER_ROLE, spender)
            || super._isAuthorized(owner, spender, tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override
        returns (address)
    {
        address from = super._update(to, tokenId, auth);
        
        // Clear rental state when token is transferred (but not when minting)
        if (from != address(0)) {
            delete _tokenToRenter[tokenId];
            delete _rentExpires[tokenId];
        }
        
        return from;
    }

    function _burnWithCleanup(uint256 tokenId)
        internal
    {
        // Clear rental state before burning
        delete _tokenToRenter[tokenId];
        delete _rentExpires[tokenId];
        
        // Call the parent _burn function
        super._burn(tokenId);
    }
}
