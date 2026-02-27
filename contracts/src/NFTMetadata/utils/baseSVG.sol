//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {svg} from "./SVG.sol";
import {utils, LibString, numUtils} from "./Utils.sol";
import "./FixedAssets.sol";

library baseSVG {
    string constant OSWALD = 'style="font-family: Oswald" ';
    string constant LEXEND = 'style="font-family: Lexend" ';
    string constant DARK_BLUE = "#2C1F2B";
    string constant STOIC_WHITE = "#DEE4FB";
    string constant LABEL_GREY = "#9E9E9E";
    string constant BROWN = "#EFA960";


    function _svgProps() internal pure returns (string memory) {
        return string.concat(
            svg.prop("width", "320"),
            svg.prop("height", "504"),
            svg.prop("viewBox", "0 0 320 504"),
            svg.prop("style", "background:none")
        );
    }

    function _baseElements(FixedAssetReader _assetReader) internal view returns (string memory) {
        return string.concat(
            svg.rect(
                string.concat(
                    svg.prop("x", "10"),
                    svg.prop("y", "10"),
                    svg.prop("fill", DARK_BLUE),
                    svg.prop("rx", "10"),
                    svg.prop("width", "300"),
                    svg.prop("height", "484")
                )
            ),
            _styles(_assetReader),
            _leverageLogo(),
            _evroLogo(_assetReader),
            _staticTextEls()
        );
    }

    function _styles(FixedAssetReader _assetReader) private view returns (string memory) {
        string memory body = string.concat(
            '@font-face { font-family: "Oswald"; src: url("data:font/woff2;utf-8;base64,',
            _assetReader.readAsset(bytes4(keccak256("oswald"))),
            '"); } @font-face { font-family: "Lexend"; src: url("data:font/woff2;utf-8;base64,',
            _assetReader.readAsset(bytes4(keccak256("lexend"))),
            '"); }'
        );
        return svg.el("style", utils.NULL, body);
    }

    function _leverageLogo() internal pure returns (string memory) {
        return string.concat(
            svg.path(
                "M20.2 31.2C19.1 32.4 17.6 33 16 33L16 21C17.6 21 19.1 21.6 20.2 22.7C21.4 23.9 22 25.4 22 27C22 28.6 21.4 30.1 20.2 31.2Z",
                svg.prop("fill", STOIC_WHITE)
            ),
            svg.path(
                "M22 27C22 25.4 22.6 23.9 23.8 22.7C25 21.6 26.4 21 28 21V33C26.4 33 25 32.4 24 31.2C22.6 30.1 22 28.6 22 27Z",
                svg.prop("fill", STOIC_WHITE)
            )
        );
    }

    function _evroLogo(FixedAssetReader _assetReader) internal view returns (string memory) {
        return svg.el(
            "image",
            string.concat(
                svg.prop("x", "278"),
                svg.prop("y", "373.5"),
                svg.prop("width", "20"),
                svg.prop("height", "20"),
                svg.prop(
                    "href",
                    string.concat("data:image/svg+xml;base64,", _assetReader.readAsset(bytes4(keccak256("EVRO"))))
                )
            )
        );
    }

    function _staticTextEls() internal pure returns (string memory) {
        return string.concat(
            svg.text(
                string.concat(
                    LEXEND,
                    svg.prop("x", "24"),
                    svg.prop("y", "358"),
                    svg.prop("font-size", "14"),
                    svg.prop("fill", LABEL_GREY)
                ),
                "COLLATERAL"
            ),
            svg.text(
                string.concat(
                    LEXEND,
                    svg.prop("x", "24"),
                    svg.prop("y", "389"),
                    svg.prop("font-size", "14"),
                    svg.prop("fill", LABEL_GREY)
                ),
                "DEBT"
            ),
            svg.text(
                string.concat(
                    LEXEND,
                    svg.prop("x", "24"),
                    svg.prop("y", "420"),
                    svg.prop("font-size", "14"),
                    svg.prop("fill", LABEL_GREY)
                ),
                "INTEREST RATE"
            ),
            svg.text(
                string.concat(
                    OSWALD,
                    svg.prop("x", "279"),
                    svg.prop("y", "422"),
                    svg.prop("font-size", "20"),
                    svg.prop("fill", "white")
                ),
                "%"
            ),
            svg.text(
                string.concat(
                    LEXEND,
                    svg.prop("x", "24"),
                    svg.prop("y", "462"),
                    svg.prop("font-size", "14"),
                    svg.prop("fill", LABEL_GREY)
                ),
                "OWNER"
            )
        );
    }

    function _formattedDynamicEl(string memory _value, uint256 _x, uint256 _y) internal pure returns (string memory) {
        return svg.text(
            string.concat(
                OSWALD,
                svg.prop("text-anchor", "end"),
                svg.prop("x", LibString.toString(_x)),
                svg.prop("y", LibString.toString(_y)),
                svg.prop("font-size", "20"),
                svg.prop("fill", "white")
            ),
            _value
        );
    }

    function _formattedIdEl(string memory _id) internal pure returns (string memory) {
        return svg.text(
            string.concat(
                OSWALD,
                svg.prop("text-anchor", "end"),
                svg.prop("x", "296"),
                svg.prop("y", "33"),
                svg.prop("font-size", "14"),
                svg.prop("fill", "white")
            ),
            _id
        );
    }

    function _formattedAddressEl(address _address) internal pure returns (string memory) {
        return svg.text(
            string.concat(
                OSWALD,
                svg.prop("text-anchor", "end"),
                svg.prop("x", "296"),
                svg.prop("y", "462"),
                svg.prop("font-size", "14"),
                svg.prop("fill", BROWN)
            ),
            string.concat(
                LibString.slice(LibString.toHexStringChecksummed(_address), 0, 6),
                "...",
                LibString.slice(LibString.toHexStringChecksummed(_address), 38, 42)
            )
        );
    }

    function _collLogo(string memory _collName, FixedAssetReader _assetReader) internal view returns (string memory) {
        return svg.el(
            "image",
            string.concat(
                svg.prop("x", "278"),
                svg.prop("y", "342.5"),
                svg.prop("width", "20"),
                svg.prop("height", "20"),
                svg.prop(
                    "href",
                    string.concat(
                        "data:image/svg+xml;base64,", _assetReader.readAsset(bytes4(keccak256(bytes(_collName))))
                    )
                )
            )
        );
    }

    function _statusEl(string memory _status) internal pure returns (string memory) {
        return svg.text(
            string.concat(
                OSWALD, svg.prop("x", "44"), svg.prop("y", "33"), svg.prop("font-size", "14"), svg.prop("fill", "white")
            ),
            _status
        );
    }

    function _dynamicTextEls(uint256 _debt, uint256 _coll, uint256 _annualInterestRate)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            _formattedDynamicEl(numUtils.toLocaleString(_coll, 18, 4), 276, 360),
            _formattedDynamicEl(numUtils.toLocaleString(_debt, 18, 2), 276, 391),
            _formattedDynamicEl(numUtils.toLocaleString(_annualInterestRate, 16, 2), 276, 422)
        );
    }
}
