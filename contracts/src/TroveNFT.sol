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
    IBoldToken internal immutable boldToken;

    IMetadataNFT public immutable metadataNFT;

    //mapping of owners to their trove ids
    mapping(address => uint256[]) internal _ownerToTroveIds;
    //mapping from troveId to its index in the owner's array (for O(1) removal)
    mapping(uint256 => uint256) internal _troveIdToIndex;

    constructor(IAddressesRegistry _addressesRegistry, address _governor)
        ERC721(
            string.concat("Liquity V2 - ", _addressesRegistry.collToken().name()),
            string.concat("LV2_", _addressesRegistry.collToken().symbol())
        )
    {
        troveManager = _addressesRegistry.troveManager();
        collToken = _addressesRegistry.collToken();
        metadataNFT = _addressesRegistry.metadataNFT();
        boldToken = _addressesRegistry.boldToken();
    }

    function tokenURI(uint256 _tokenId) public view override(ERC721, IERC721Metadata) returns (string memory) {
        LatestTroveData memory latestTroveData = troveManager.getLatestTroveData(_tokenId);

        IMetadataNFT.TroveData memory troveData = IMetadataNFT.TroveData({
            _tokenId: _tokenId,
            _owner: ownerOf(_tokenId),
            _collToken: address(collToken),
            _boldToken: address(boldToken),
            _collAmount: latestTroveData.entireColl,
            _debtAmount: latestTroveData.entireDebt,
            _interestRate: latestTroveData.annualInterestRate,
            _status: troveManager.getTroveStatus(_tokenId)
        });

        return metadataNFT.uri(troveData);
    }

    function mint(address _owner, uint256 _troveId) external override {
        _requireCallerIsTroveManager();
        _mint(_owner, _troveId);
    }

    function burn(uint256 _troveId) external override {
        _requireCallerIsTroveManager();
        _burn(_troveId);
    }

    function ownerToTroveIds(address owner) external view override returns (uint256[] memory) {
        return _ownerToTroveIds[owner];
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        virtual
        override(ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        // Only handle single token transfers (batchSize is always 1 for this contract)
        uint256 troveId = firstTokenId;

        if (from == address(0)) {
            // Minting: add to new owner's list
            _ownerToTroveIds[to].push(troveId);
            _troveIdToIndex[troveId] = _ownerToTroveIds[to].length - 1;
        } else if (to == address(0)) {
            // Burning: remove from owner's list
            _removeTroveFromOwner(from, troveId);
            delete _troveIdToIndex[troveId];
        } else {
            // Transferring: remove from old owner, add to new owner
            _removeTroveFromOwner(from, troveId);
            _ownerToTroveIds[to].push(troveId);
            _troveIdToIndex[troveId] = _ownerToTroveIds[to].length - 1;
        }
    }

    function _removeTroveFromOwner(address owner, uint256 troveId) internal {
        uint256[] storage troveIds = _ownerToTroveIds[owner];
        uint256 length = troveIds.length;
        
        // Find the troveId in the array
        uint256 index = length; // Use length as "not found" marker
        for (uint256 i = 0; i < length; i++) {
            if (troveIds[i] == troveId) {
                index = i;
                break;
            }
        }
        
        // If not found, nothing to remove
        if (index >= length) return;
        
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
}
