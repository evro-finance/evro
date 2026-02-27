//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "Solady/utils/SSTORE2.sol";

contract FixedAssetReader {
    struct Asset {
        address pointer;
        uint128 start;
        uint128 end;
    }

    mapping(bytes4 => Asset) public assets;

    function readAsset(bytes4 _sig) public view returns (string memory) {
        Asset memory asset = assets[_sig];
        return string(SSTORE2.read(asset.pointer, uint256(asset.start), uint256(asset.end)));
    }

    constructor(bytes4[] memory _sigs, Asset[] memory _assets) {
        require(_sigs.length == _assets.length, "FixedAssetReader: Invalid input");
        for (uint256 i = 0; i < _sigs.length; i++) {
            assets[_sigs[i]] = _assets[i];
        }
    }
}
