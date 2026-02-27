// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "forge-std/Script.sol";
//import "forge-std/StdAssertions.sol";
import "src/NFTMetadata/MetadataNFT.sol";
import "src/NFTMetadata/utils/Utils.sol";
import "src/NFTMetadata/utils/FixedAssets.sol";

contract MetadataDeployment is Script /* , StdAssertions */ {
    mapping(bytes4 => bytes) public files;

    address public fontsPointer;    // oswald + lexend (~15.2KB)
    address public logos1Pointer;   // EVRO, WXDAI, GNO, sDAI (~13.3KB)
    address public logos2Pointer;   // wWBTC, osGNO, wstETH (~10.9KB)

    FixedAssetReader public initializedFixedAssetReader;

    function deployMetadata(bytes32 _salt) public returns (MetadataNFT) {
        _loadFiles();
        _storeFile();
        _deployFixedAssetReader(_salt);

        MetadataNFT metadataNFT = new MetadataNFT{salt: _salt}(initializedFixedAssetReader);

        return metadataNFT;
    }

    function _loadFiles() internal {
        string memory root = string.concat(vm.projectRoot(), "/utils/assets/");

        files[bytes4(keccak256("oswald"))]  = bytes(vm.readFile(string.concat(root, "oswald.txt")));
        files[bytes4(keccak256("lexend"))]  = bytes(vm.readFile(string.concat(root, "lexend.txt")));
        files[bytes4(keccak256("osGNO"))]   = bytes(vm.readFile(string.concat(root, "osgno_logo.txt")));
        files[bytes4(keccak256("EVRO"))]    = bytes(vm.readFile(string.concat(root, "evro_logo.txt")));
        files[bytes4(keccak256("WXDAI"))]   = bytes(vm.readFile(string.concat(root, "xdai_logo.txt")));
        files[bytes4(keccak256("GNO"))]     = bytes(vm.readFile(string.concat(root, "gno_logo.txt")));
        files[bytes4(keccak256("sDAI"))]    = bytes(vm.readFile(string.concat(root, "sdai_logo.txt")));
        files[bytes4(keccak256("wWBTC"))]   = bytes(vm.readFile(string.concat(root, "wbtc_logo.txt")));
        files[bytes4(keccak256("wstETH"))]  = bytes(vm.readFile(string.concat(root, "wsteth_logo.txt")));
    }

    function _storeFile() internal {
        // Contract 1: fonts only (~15.2KB)
        fontsPointer = SSTORE2.write(bytes.concat(
            files[bytes4(keccak256("oswald"))],
            files[bytes4(keccak256("lexend"))]
        ));

        // Contract 2: EVRO, WXDAI, GNO, sDAI (~13.3KB)
        logos1Pointer = SSTORE2.write(bytes.concat(
            files[bytes4(keccak256("EVRO"))],
            files[bytes4(keccak256("WXDAI"))],
            files[bytes4(keccak256("GNO"))],
            files[bytes4(keccak256("sDAI"))]
        ));

        // Contract 3: wWBTC, osGNO, wstETH (~10.9KB)
        logos2Pointer = SSTORE2.write(bytes.concat(
            files[bytes4(keccak256("wWBTC"))],
            files[bytes4(keccak256("osGNO"))],
            files[bytes4(keccak256("wstETH"))]
        ));
    }

    function _deployFixedAssetReader(bytes32 _salt) internal {
        bytes4[] memory sigs = new bytes4[](9);
        sigs[0] = bytes4(keccak256("oswald"));
        sigs[1] = bytes4(keccak256("lexend"));
        sigs[2] = bytes4(keccak256("EVRO"));
        sigs[3] = bytes4(keccak256("WXDAI"));
        sigs[4] = bytes4(keccak256("GNO"));
        sigs[5] = bytes4(keccak256("sDAI"));
        sigs[6] = bytes4(keccak256("wWBTC"));
        sigs[7] = bytes4(keccak256("osGNO"));
        sigs[8] = bytes4(keccak256("wstETH"));

        initializedFixedAssetReader = new FixedAssetReader{salt: _salt}(sigs, _buildAssets());
    }

    function _buildAssets() private view returns (FixedAssetReader.Asset[] memory) {
        FixedAssetReader.Asset[] memory assets = new FixedAssetReader.Asset[](9);
        _buildFontAssets(assets);
        _buildLogoAssets(assets);
        return assets;
    }

    function _buildFontAssets(FixedAssetReader.Asset[] memory assets) private view {
        bytes4[2] memory keys;
        keys[0] = bytes4(keccak256("oswald"));
        keys[1] = bytes4(keccak256("lexend"));
        uint128 offset = 0;
        for (uint256 i = 0; i < 2; i++) {
            uint128 len = uint128(files[keys[i]].length);
            assets[i] = FixedAssetReader.Asset(fontsPointer, offset, offset + len);
            offset += len;
        }
    }

    function _buildLogoAssets(FixedAssetReader.Asset[] memory assets) private view {
        bytes4[4] memory keys1;
        keys1[0] = bytes4(keccak256("EVRO"));
        keys1[1] = bytes4(keccak256("WXDAI"));
        keys1[2] = bytes4(keccak256("GNO"));
        keys1[3] = bytes4(keccak256("sDAI"));
        uint128 offset = 0;
        for (uint256 i = 0; i < 4; i++) {
            uint128 len = uint128(files[keys1[i]].length);
            assets[i + 2] = FixedAssetReader.Asset(logos1Pointer, offset, offset + len);
            offset += len;
        }

        bytes4[3] memory keys2;
        keys2[0] = bytes4(keccak256("wWBTC"));
        keys2[1] = bytes4(keccak256("osGNO"));
        keys2[2] = bytes4(keccak256("wstETH"));
        offset = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint128 len = uint128(files[keys2[i]].length);
            assets[i + 6] = FixedAssetReader.Asset(logos2Pointer, offset, offset + len);
            offset += len;
        }
    }
}
