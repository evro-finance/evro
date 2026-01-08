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
        _mint(_owner, _troveId);
    }

    function burn(uint256 _troveId) external override {
        _requireCallerIsTroveManager();
        _burn(_troveId);
    }

    /// @notice Returns all trove IDs owned by an address
    /// @dev Uses ERC721Enumerable's built-in tracking
    function ownerToTroveIds(address owner) external view returns (uint256[] memory) {
        uint256 count = balanceOf(owner);
        uint256[] memory troveIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            troveIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return troveIds;
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
