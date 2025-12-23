// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./Interfaces/ITroveNFT.sol";
import "./Interfaces/IAddressesRegistry.sol";

import {IMetadataNFT} from "./NFTMetadata/MetadataNFT.sol";
import {ITroveManager} from "./Interfaces/ITroveManager.sol";


contract TroveNFT is ERC721Enumerable, ITroveNFT {
    ITroveManager public immutable troveManager;
    IERC20Metadata internal immutable collToken;
    IEvroToken internal immutable evroToken;

    IMetadataNFT public immutable metadataNFT;

    //mapping of owners to their trove ids
    mapping(address => uint256[]) internal _ownerToTroveIds;
    //mapping from troveId to its index in the owner's array (for O(1) removal)
    mapping(uint256 => uint256) internal _troveIdToIndex;
    address public externalNFTUriAddress = address(0);

    address public governor;

    constructor(IAddressesRegistry _addressesRegistry, address _governor)
        ERC721(
            string.concat("Liquity V2 - ", _addressesRegistry.collToken().name()),
            string.concat("LV2_", _addressesRegistry.collToken().symbol())
        )
    {
        
        troveManager = _addressesRegistry.troveManager();
        collToken = _addressesRegistry.collToken();
        metadataNFT = _addressesRegistry.metadataNFT();
        evroToken = _addressesRegistry.evroToken();
        governor = _governor;
    }

    function tokenURI(uint256 _tokenId) public view override(ERC721, IERC721Metadata) returns (string memory) {
                //governor can update the URI externally at any time 
        //without effecting the NFT storage or other parts of the protocol.
        if (externalNFTUriAddress != address(0)) {
            return IExternalNFTUri(externalNFTUriAddress).tokenURI(_tokenId);
        }

        LatestTroveData memory latestTroveData = troveManager.getLatestTroveData(_tokenId);

        IMetadataNFT.TroveData memory troveData = IMetadataNFT.TroveData({
            _tokenId: _tokenId,
            _owner: ownerOf(_tokenId),
            _collToken: address(collToken),
            _evroToken: address(evroToken),
            _collAmount: latestTroveData.entireColl,
            _debtAmount: latestTroveData.entireDebt,
            _interestRate: latestTroveData.annualInterestRate,
            _status: troveManager.getTroveStatus(_tokenId)
        });

        return metadataNFT.uri(troveData);
    }

    function mint(address _owner, uint256 _troveId) external override {
        _requireCallerIsTroveManager();
        _beforeTokenTransfer(address(0), _owner, _troveId);
        _mint(_owner, _troveId);
    }

    function burn(uint256 _troveId) external override {
        _requireCallerIsTroveManager();
        _beforeTokenTransfer(ownerOf(_troveId), address(0), _troveId);
        _burn(_troveId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
        _beforeTokenTransfer(from, to, tokenId);
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override(ERC721, IERC721) {
        _beforeTokenTransfer(from, to, tokenId);
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function ownerToTroveIds(address owner) external view returns (uint256[] memory) {
        return _ownerToTroveIds[owner];
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        virtual

    {
        // Only handle single token transfers
        if (from == address(0)) {
            // Minting: add to new owner's list
            _ownerToTroveIds[to].push(tokenId);
            _troveIdToIndex[tokenId] = _ownerToTroveIds[to].length - 1;
        } else if (to == address(0)) {
            // Burning: remove from owner's list
            _removeTroveFromOwner(from, tokenId);
            delete _troveIdToIndex[tokenId];
        } else {
            // Transferring: remove from old owner, add to new owner
            _removeTroveFromOwner(from, tokenId);
            _ownerToTroveIds[to].push(tokenId);
            _troveIdToIndex[tokenId] = _ownerToTroveIds[to].length - 1;
        }
    }

    function _removeTroveFromOwner(address owner, uint256 troveId) internal {
        uint256[] storage troveIds = _ownerToTroveIds[owner];
        uint256 length = troveIds.length;
        // Find the troveId in the array
        if (length == 0) return;
        
        uint256 index = _troveIdToIndex[troveId];
        // Validate the index points to the correct troveId
        if (index >= length || troveIds[index] != troveId) return;
        // If not found, nothing to remove
        uint256 lastIndex = length - 1;
        // Swap with last element and pop (O(1) removal)
        if (index != lastIndex) {
            uint256 lastTroveId = troveIds[lastIndex];
            troveIds[index] = lastTroveId;
            _troveIdToIndex[lastTroveId] = index;
        }
        troveIds.pop();
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == address(troveManager), "TroveNFT: Caller is not the TroveManager contract");
    }

    function changeGovernor(address _governor) external {
        require(msg.sender == governor, "TroveNFT: Caller is not the governor");
        governor = _governor;
    }

    function governorUpdateURI(address _externalNFTUriAddress) external {
        require(msg.sender == governor, "TroveNFT: Caller is not the governor.");
        externalNFTUriAddress = _externalNFTUriAddress;
    }
}
