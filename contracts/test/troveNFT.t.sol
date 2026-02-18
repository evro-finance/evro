pragma solidity 0.8.24;

import "./TestContracts/DevTestSetup.sol";

import "src/NFTMetadata/MetadataNFT.sol";
import "src/TroveNFT.sol";

import "src/CoGNO.sol";

import "lib/Solady/src/utils/Base64.sol";

contract troveNFTTest is DevTestSetup {
    uint256 NUM_COLLATERALS = 3;
    uint256 NUM_VARIANTS = 4;
    TestDeployer.LiquityContractsDev[] public contractsArray;
    TroveNFT troveNFTWXDAI;
    TroveNFT troveNFTGNO;
    TroveNFT troveNFTSDAI;
    uint256[] troveIds;
    uint256[] gnoTroveIds;
    uint256[] sdaiTroveIds;

    function openMulticollateralTroveNoHints100pctWithIndex(
        uint256 _collIndex,
        address _account,
        uint256 _index,
        uint256 _coll,
        uint256 _evroAmount,
        uint256 _annualInterestRate
    ) public returns (uint256 troveId) {
        TroveChange memory troveChange;
        troveChange.debtIncrease = _evroAmount;
        troveChange.newWeightedRecordedDebt = troveChange.debtIncrease * _annualInterestRate;
        uint256 avgInterestRate =
            contractsArray[_collIndex].activePool.getNewApproxAvgInterestRateFromTroveChange(troveChange);
        uint256 upfrontFee = calcUpfrontFee(troveChange.debtIncrease, avgInterestRate);

        vm.startPrank(_account);

        troveId = contractsArray[_collIndex].borrowerOperations.openTrove(
            _account,
            _index,
            _coll,
            _evroAmount,
            0, // _upperHint
            0, // _lowerHint
            _annualInterestRate,
            upfrontFee,
            address(0),
            address(0),
            address(0)
        );

        vm.stopPrank();
    }

    function setUp() public override {
        // Start tests at a non-zero timestamp
        vm.warp(block.timestamp + 600);

        accounts = new Accounts();
        createAccounts();

        (A, B, C, D, E, F, G) = (
            accountsList[0],
            accountsList[1],
            accountsList[2],
            accountsList[3],
            accountsList[4],
            accountsList[5],
            accountsList[6]
        );

        TestDeployer.TroveManagerParams[] memory troveManagerParamsArray =
            new TestDeployer.TroveManagerParams[](NUM_COLLATERALS);
        troveManagerParamsArray[0] = TestDeployer.TroveManagerParams(150e16, 110e16, 10e16, 110e16, 5e16, 10e16);
        troveManagerParamsArray[1] = TestDeployer.TroveManagerParams(160e16, 120e16, 10e16, 120e16, 5e16, 10e16);
        troveManagerParamsArray[2] = TestDeployer.TroveManagerParams(160e16, 120e16, 10e16, 120e16, 5e16, 10e16);

        TestDeployer deployer = new TestDeployer();
        TestDeployer.LiquityContractsDev[] memory _contractsArray;
        (_contractsArray, collateralRegistry, evroToken,,, WETH,) =
            deployer.deployAndConnectContractsMultiColl(troveManagerParamsArray);
        // Unimplemented feature (...):Copying of type struct LiquityContracts memory[] memory to storage not yet supported.
        for (uint256 c = 0; c < NUM_COLLATERALS; c++) {
            contractsArray.push(_contractsArray[c]);
        }
        // Set price feeds
        contractsArray[0].priceFeed.setPrice(2000e18);
        contractsArray[1].priceFeed.setPrice(200e18);
        contractsArray[2].priceFeed.setPrice(20000e18);
        // Just in case
        for (uint256 c = 3; c < NUM_COLLATERALS; c++) {
            contractsArray[c].priceFeed.setPrice(2000e18 + c * 1e18);
        }

        // Give some Collateral to test accounts, and approve it to BorrowerOperations
        uint256 initialCollateralAmount = 10_000e18;

        for (uint256 c = 0; c < NUM_COLLATERALS; c++) {
            for (uint256 i = 0; i < 6; i++) {
                // A to F
                giveAndApproveCollateral(
                    contractsArray[c].collToken,
                    accountsList[i],
                    initialCollateralAmount,
                    address(contractsArray[c].borrowerOperations)
                );
                // Approve WETH for gas compensation in all branches
                vm.startPrank(accountsList[i]);
                WETH.approve(address(contractsArray[c].borrowerOperations), type(uint256).max);
                vm.stopPrank();
            }
        }

        troveIds = new uint256[](NUM_VARIANTS);
        gnoTroveIds = new uint256[](NUM_VARIANTS);
        sdaiTroveIds = new uint256[](NUM_VARIANTS);

        // 0 = WXDAI
        troveIds[0] = openMulticollateralTroveNoHints100pctWithIndex(0, A, 0, 10e18, 10000e18, 5e16);
        troveIds[1] = openMulticollateralTroveNoHints100pctWithIndex(0, A, 1, 10e18, 10000e18, 5e16);
        troveIds[2] = openMulticollateralTroveNoHints100pctWithIndex(0, A, 2, 10e18, 10000e18, 5e16);
        troveIds[3] = openMulticollateralTroveNoHints100pctWithIndex(0, A, 10, 10e18, 10000e18, 5e16);

        // 1 = GNO
        gnoTroveIds[0] = openMulticollateralTroveNoHints100pctWithIndex(1, A, 0, 100e18, 10000e18, 5e16);
        gnoTroveIds[1] = openMulticollateralTroveNoHints100pctWithIndex(1, A, 1, 100e18, 10000e18, 5e16);
        gnoTroveIds[2] = openMulticollateralTroveNoHints100pctWithIndex(1, A, 2, 100e18, 10000e18, 5e16);
        gnoTroveIds[3] = openMulticollateralTroveNoHints100pctWithIndex(1, A, 10, 100e18, 10000e18, 5e16);

        // 2 = sDAI
        sdaiTroveIds[0] = openMulticollateralTroveNoHints100pctWithIndex(2, A, 0, 100e18, 10000e18, 5e16);
        sdaiTroveIds[1] = openMulticollateralTroveNoHints100pctWithIndex(2, A, 1, 100e18, 10000e18, 5e16);
        sdaiTroveIds[2] = openMulticollateralTroveNoHints100pctWithIndex(2, A, 2, 100e18, 10000e18, 5e16);
        sdaiTroveIds[3] = openMulticollateralTroveNoHints100pctWithIndex(2, A, 10, 100e18, 10000e18, 5e16);

        troveNFTWXDAI = TroveNFT(address(contractsArray[0].troveManager.troveNFT()));
        troveNFTGNO = TroveNFT(address(contractsArray[1].troveManager.troveNFT()));
        troveNFTSDAI = TroveNFT(address(contractsArray[2].troveManager.troveNFT()));
    }

    function testTroveNFTMetadata() public view {
        assertEq(troveNFTWXDAI.name(), "EVRO- Wrapped XDAI", "Invalid Trove Name");
        assertEq(troveNFTWXDAI.symbol(), "EVRO_WXDAI", "Invalid Trove Symbol");

        assertEq(troveNFTGNO.name(), "EVRO- GNO", "Invalid Trove Name");
        assertEq(troveNFTGNO.symbol(), "EVRO_GNO", "Invalid Trove Symbol");

        assertEq(troveNFTSDAI.name(), "EVRO- Savings DAI", "Invalid Trove Name");
        assertEq(troveNFTSDAI.symbol(), "EVRO_sDAI", "Invalid Trove Symbol");
    }

    string topMulti =
        '<!DOCTYPE html><html lang="en"><head><Title>Test Uri</Title><style>.container{display:flex;flex-direction:row;margin-bottom:20px}.container img{width:300px;height:484px;margin-right:20px}.container pre{flex:1}</style></head><body><script>';

    function _writeUriFile(string[] memory _uris) public {
        string memory pathClean = string.concat("utils/assets/test_output/uris.html");

        try vm.removeFile(pathClean) {} catch {}

        vm.writeLine(pathClean, topMulti);

        string memory uriCombined;

        uriCombined = "const encodedStrings=[";
        for (uint256 i = 0; i < _uris.length; i++) {
            uriCombined = string.concat(uriCombined, '"', _uris[i], '",');
        }
        uriCombined = string.concat(uriCombined, "];");

        vm.writeLine(
            pathClean,
            string.concat(
                'function processEncodedString(encodedString) { const container = document.createElement("div"); container.className = "container"; container.innerHTML = ` <img><pre></pre>`; const output = container.querySelector("pre"); const image = container.querySelector("img"); try { const base64Data = encodedString.split(",")[1]; const jsonData = JSON.parse(atob(base64Data)); output.innerText = JSON.stringify(jsonData.attributes, null, 2); image.src = jsonData.image || ""; } catch (error) { output.innerText = `Error decoding or parsing JSON: ${error.message}`; } document.body.appendChild(container); } ',
                uriCombined,
                "encodedStrings.forEach((encodedString) => { processEncodedString(encodedString); });"
            )
        );

        vm.writeLine(pathClean, string.concat("</script></body></html>"));
    }

    function testTroveURI() public {
        string[] memory uris = new string[](NUM_VARIANTS * NUM_COLLATERALS);

        // Let’s redeem so we have some zombies in the result
        deal(address(evroToken), A, 30000e18);
        redeem(A, 30000e18);

        for (uint256 i = 0; i < NUM_VARIANTS; i++) {
            uris[i] = troveNFTWXDAI.tokenURI(troveIds[i]);
            uris[i + NUM_VARIANTS] = troveNFTGNO.tokenURI(gnoTroveIds[i]);
            uris[i + (NUM_VARIANTS * 2)] = troveNFTSDAI.tokenURI(sdaiTroveIds[i]);
        }

        _writeUriFile(uris);
    }

    function testTroveIdToOwnerAndCoGNOBalance() public {
        address owner = troveNFTWXDAI.ownerOf(troveIds[0]);
        assertEq(owner, A, "Trove 0 owner should be A");

        address owner2 = troveNFTWXDAI.ownerOf(troveIds[1]);
        assertEq(owner2, A, "Trove 1 owner should be A");

        address owner3 = troveNFTWXDAI.ownerOf(troveIds[2]);
        assertEq(owner3, A, "Trove 2 owner should be A");

        address owner4 = troveNFTWXDAI.ownerOf(troveIds[3]);
        assertEq(owner4, A, "Trove 3 owner should be A");

        //transfer a trove to a new address, then test again.
        vm.startPrank(A);
        troveNFTWXDAI.transferFrom(A, B, troveIds[0]);
        vm.stopPrank();

        owner = troveNFTWXDAI.ownerOf(troveIds[0]);
        assertEq(owner, B, "Trove 0 owner should be B");

        // Verify ownerToTroveIds arrays are correct
        uint256[] memory aTroves = troveNFTWXDAI.ownerToTroveIds(A);
        uint256[] memory bTroves = troveNFTWXDAI.ownerToTroveIds(B);
        assertEq(aTroves.length, 3, "A should have 3 troves");
        assertEq(bTroves.length, 1, "B should have 1 trove");
        assertEq(bTroves[0], troveIds[0], "B should own troveIds[0]");

        //deploy CoGNO contract and test the balance of the new address.
        CollateralGNO coGNO = new CollateralGNO(address(contractsArray[0].troveManager));
        assertEq(coGNO.balanceOf(B), 10e18, "CoGNO balance of B should be 10e18");
        assertEq(coGNO.balanceOf(A), 30e18, "CoGNO balance of A should be 30e18 (troveIds[1] + troveIds[2] + troveIds[3])");
        
        // Test that CoGNO is non-transferable
        vm.startPrank(B);
        uint256 balance = coGNO.balanceOf(B);
        vm.expectRevert("Token is non-transferable");
        coGNO.transfer(A, balance);
        vm.stopPrank();

        // Transfer NFT back to A
        vm.startPrank(B);
        troveNFTWXDAI.transferFrom(B, A, troveIds[0]);
        vm.stopPrank();

        // Verify balances updated after NFT transfer
        assertEq(coGNO.balanceOf(B), 0, "CoGNO balance of B should be 0 after NFT transfer");
        assertEq(coGNO.balanceOf(A), 40e18, "CoGNO balance of A should be 40e18 (all 4 troves)");
        // A closes a trove, then test the balance of the new address.
        vm.startPrank(A);
        contractsArray[0].borrowerOperations.closeTrove(troveIds[0]);
        vm.stopPrank();
        assertEq(coGNO.balanceOf(A), 30e18, "CoGNO balance of A should be 30e18 (all 3 troves)");
    }

    function testTroveURIAttributes() public view {
        address collateral = address(contractsArray[1].collToken);

        string memory uri = troveNFTGNO.tokenURI(troveIds[0]);
        string memory uriSplit = LibString.slice(uri, 29, bytes(uri).length);
        string memory decodedUri = string(Base64.decode(uriSplit));

        // Check for expected attributes
        assertTrue(LibString.contains(decodedUri, '"name": "Evro PROTOCOL |'), "NFT Name attribute missing");

        assertTrue(
            LibString.contains(
                decodedUri, '"description": "Evro is a collateralized debt platform. Users can lock up'
            ),
            "NFT description attribute missing"
        );

        assertTrue(
            LibString.contains(decodedUri, '"trait_type": "Collateral Token"'), "Collateral Token attribute missing"
        );
        assertTrue(
            LibString.contains(decodedUri, '"trait_type": "Collateral Amount"'), "Collateral Amount attribute missing"
        );
        assertTrue(LibString.contains(decodedUri, '"trait_type": "Debt Token"'), "Debt Token attribute missing");
        assertTrue(LibString.contains(decodedUri, '"trait_type": "Debt Amount"'), "Debt Amount attribute missing");
        assertTrue(LibString.contains(decodedUri, '"trait_type": "Interest Rate"'), "Interest Rate attribute missing");
        assertTrue(LibString.contains(decodedUri, '"trait_type": "Status"'), "Status attribute missing");

        // Check for expected values
        assertTrue(
            LibString.contains(decodedUri, string.concat('"value": "', Strings.toHexString(collateral))),
            "Incorrect Collateral Token value"
        );
        assertTrue(
            LibString.contains(decodedUri, '"value": "100000000000000000000"'), "Incorrect Collateral Amount value"
        );
        assertTrue(
            LibString.contains(decodedUri, string.concat('"value": "', Strings.toHexString(address(evroToken)))),
            "Incorrect Debt Token value"
        );
        assertTrue(LibString.contains(decodedUri, '"value": "10009589041095890410958"'), "Incorrect Debt Amount value");
        assertTrue(LibString.contains(decodedUri, '"value": "50000000000000000"'), "Incorrect Interest Rate value");
        assertTrue(LibString.contains(decodedUri, '"value": "Active"'), "Incorrect Status value");
    }

    function test_toLocale() public pure {
        string memory result = numUtils.toLocale("123456789");
        //console.log(result);
        assertEq(result, "123,456,789");
    }

    function test_toLocaleString() public pure {
        string memory result = numUtils.toLocaleString(123456789, 0, 2);
        assertEq(result, "123,456,789.00");

        result = numUtils.toLocaleString(123456789, 1, 2);
        assertEq(result, "12,345,678.90");

        result = numUtils.toLocaleString(123456789, 1, 3);
        assertEq(result, "12,345,678.900");

        result = numUtils.toLocaleString(123456789, 1, 0);
        assertEq(result, "12,345,678");

        result = numUtils.toLocaleString(123456789, 2, 0);
        assertEq(result, "1,234,567");

        result = numUtils.toLocaleString(123456789, 3, 0);
        assertEq(result, "123,456");

        result = numUtils.toLocaleString(123456789, 4, 0);
        assertEq(result, "12,345");

        result = numUtils.toLocaleString(123456789, 5, 0);
        assertEq(result, "1,234");

        result = numUtils.toLocaleString(123456789, 6, 0);
        assertEq(result, "123");

        result = numUtils.toLocaleString(123456789, 7, 0);
        assertEq(result, "12");

        result = numUtils.toLocaleString(123456789, 8, 0);
        assertEq(result, "1");

        result = numUtils.toLocaleString(123456789, 9, 0);
        assertEq(result, "0");

        result = numUtils.toLocaleString(123456789, 10, 0);
        assertEq(result, "0");

        result = numUtils.toLocaleString(123456789, 10, 1);
        assertEq(result, "0.1");

        result = numUtils.toLocaleString(123456789, 10, 2);
        assertEq(result, "0.12");

        result = numUtils.toLocaleString(123456789, 10, 3);
        assertEq(result, "0.123");

        result = numUtils.toLocaleString(123456789, 10, 4);
        assertEq(result, "0.1234");

        result = numUtils.toLocaleString(123456789, 12, 3);
        assertEq(result, "0.001", "12, 3");

        result = numUtils.toLocaleString(123456789, 3, 3);
        assertEq(result, "123,456.789", "3");

        result = numUtils.toLocaleString(123456789, 10, 10);
        assertEq(result, "0.1234567890", "10");

        result = numUtils.toLocaleString(123456789, 10, 11);
        assertEq(result, "0.12345678900", "10,11");

        result = numUtils.toLocaleString(123456789, 11, 11);
        assertEq(result, "0.01234567890", "11, 11");

        result = numUtils.toLocaleString(123456789, 11, 12);
        assertEq(result, "0.012345678900", "11, 12");

        result = numUtils.toLocaleString(123456789, 11, 13);
        assertEq(result, "0.0123456789000", "11, 13");

        result = numUtils.toLocaleString(123456789, 10, 18);
        assertEq(result, "0.123456789000000000", "11, 18");

        result = numUtils.toLocaleString(123456789, 1, 9);
        assertEq(result, "12,345,678.900000000");

        result = numUtils.toLocaleString(1234567890, 2, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(12345678900, 3, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(123456789000, 4, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(1234567890000, 5, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(12345678900000, 6, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(123456789000000, 7, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(1234567890000000, 8, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(12345678900000000, 9, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(123456789000000000, 10, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(123456789000000001, 10, 1);
        assertEq(result, "12,345,678.9");

        result = numUtils.toLocaleString(123456789000000001, 10, 2);
        assertEq(result, "12,345,678.90");

        result = numUtils.toLocaleString(123456789000000001, 10, 3);
        assertEq(result, "12,345,678.900");

        result = numUtils.toLocaleString(123456789000000001, 10, 4);
        assertEq(result, "12,345,678.9000");

        result = numUtils.toLocaleString(123456789000000001, 10, 5);
        assertEq(result, "12,345,678.90000");

        result = numUtils.toLocaleString(123456789000000001, 10, 6);
        assertEq(result, "12,345,678.900000");

        result = numUtils.toLocaleString(123456789000000001, 10, 7);
        assertEq(result, "12,345,678.9000000");

        result = numUtils.toLocaleString(123456789000000001, 10, 8);
        assertEq(result, "12,345,678.90000000");

        result = numUtils.toLocaleString(123456789000000001, 10, 9);
        assertEq(result, "12,345,678.900000000");

        result = numUtils.toLocaleString(123456789000000001, 10, 10);
        assertEq(result, "12,345,678.9000000001");

        result = numUtils.toLocaleString(123456789000000001, 10, 11);
        assertEq(result, "12,345,678.90000000010");

        result = numUtils.toLocaleString(10, 0, 0);
        assertEq(result, "10");

        result = numUtils.toLocaleString(10, 1, 0);
        assertEq(result, "1");

        result = numUtils.toLocaleString(10, 2, 1);
        assertEq(result, "0.1");

        result = numUtils.toLocaleString(1, 0, 0);
        assertEq(result, "1");

        result = numUtils.toLocaleString(1, 1, 1);
        assertEq(result, "0.1");

        result = numUtils.toLocaleString(1, 2, 2);
        assertEq(result, "0.01");

        result = numUtils.toLocaleString(1, 3, 3);
        assertEq(result, "0.001", "here");

        result = numUtils.toLocaleString(1, 4, 4);
        assertEq(result, "0.0001");

        result = numUtils.toLocaleString(1, 5, 5);
        assertEq(result, "0.00001");

        result = numUtils.toLocaleString(1, 6, 6);
        assertEq(result, "0.000001");

        result = numUtils.toLocaleString(1, 7, 7);
        assertEq(result, "0.0000001");

        result = numUtils.toLocaleString(1, 8, 8);
        assertEq(result, "0.00000001");

        result = numUtils.toLocaleString(1, 9, 9);
        assertEq(result, "0.000000001");

        result = numUtils.toLocaleString(1, 10, 10);
        assertEq(result, "0.0000000001");
    }

    function testSafeTransferFrom() public {
        // Test safeTransferFrom works same as transferFrom
        vm.prank(A);
        troveNFTWXDAI.safeTransferFrom(A, B, troveIds[1]);
        
        assertEq(troveNFTWXDAI.ownerOf(troveIds[1]), B, "Trove owner should be B after safeTransferFrom");
        
        uint256[] memory aTroves = troveNFTWXDAI.ownerToTroveIds(A);
        uint256[] memory bTroves = troveNFTWXDAI.ownerToTroveIds(B);
        assertEq(aTroves.length, 3, "A should have 3 troves after transfer");
        assertEq(bTroves.length, 1, "B should have 1 trove after transfer");
        assertEq(bTroves[0], troveIds[1], "B should own troveIds[1]");
    }

    function testRemoveMiddleTrove() public {
        // Close middle trove to test swap-and-pop removal
        uint256 middleTroveId = troveIds[1];
        
        // Verify A has 4 troves initially
        uint256[] memory aTrovesBefore = troveNFTWXDAI.ownerToTroveIds(A);
        assertEq(aTrovesBefore.length, 4, "A should have 4 troves initially");
        
        vm.startPrank(A);
        contractsArray[0].borrowerOperations.closeTrove(middleTroveId);
        vm.stopPrank();
        
        uint256[] memory aTroves = troveNFTWXDAI.ownerToTroveIds(A);
        assertEq(aTroves.length, 3, "A should have 3 troves after closing one");
        
        // Verify the middle trove was removed
        for (uint256 i = 0; i < aTroves.length; i++) {
            assertTrue(aTroves[i] != middleTroveId, "Middle trove should be removed");
        }
    }

    function testTransferMiddleTrove() public {
        // Transfer middle trove to test swap-and-pop removal during transfer
        uint256 middleTroveId = troveIds[1];
        
        vm.prank(A);
        troveNFTWXDAI.transferFrom(A, B, middleTroveId);
        
        uint256[] memory aTroves = troveNFTWXDAI.ownerToTroveIds(A);
        uint256[] memory bTroves = troveNFTWXDAI.ownerToTroveIds(B);
        
        assertEq(aTroves.length, 3, "A should have 3 troves after transfer");
        assertEq(bTroves.length, 1, "B should have 1 trove");
        
        // Verify the middle trove was removed from A
        for (uint256 i = 0; i < aTroves.length; i++) {
            assertTrue(aTroves[i] != middleTroveId, "Middle trove should be removed from A");
        }
        assertEq(bTroves[0], middleTroveId, "B should own the middle trove");
    }

    function testMultipleTransfersRoundTrip() public {
        // Test A -> B -> C -> A round trip
        uint256 troveId = troveIds[0];
        CollateralGNO coGNO = new CollateralGNO(address(contractsArray[0].troveManager));
        // A -> B
        vm.prank(A);
        troveNFTWXDAI.transferFrom(A, B, troveId);
        assertEq(troveNFTWXDAI.ownerOf(troveId), B, "Owner should be B");
        // check coGNO balance of A and B
        assertEq(coGNO.balanceOf(A), 30e18, "CoGNO balance of A should be 30e18 (3 troves)");
        assertEq(coGNO.balanceOf(B), 10e18, "CoGNO balance of B should be 10e18 (troveIds[0])");
        // B -> C
        vm.prank(B);
        troveNFTWXDAI.transferFrom(B, C, troveId);
        assertEq(troveNFTWXDAI.ownerOf(troveId), C, "Owner should be C");
        // check coGNO balance of B and C
        assertEq(coGNO.balanceOf(B), 0, "CoGNO balance of B should be 0 (troveIds[0] transferred to C)");
        assertEq(coGNO.balanceOf(C), 10e18, "CoGNO balance of C should be 10e18 (troveIds[0])");
        // C -> A
        vm.prank(C);
        troveNFTWXDAI.transferFrom(C, A, troveId);
        assertEq(troveNFTWXDAI.ownerOf(troveId), A, "Owner should be A again");
        // check coGNO balance of C and A
        assertEq(coGNO.balanceOf(C), 0, "CoGNO balance of C should be 0 (troveIds[0] transferred to A)");
        assertEq(coGNO.balanceOf(A), 40e18, "CoGNO balance of A should be 40e18 (4 troves)");
        // Verify final state
        uint256[] memory aTroves = troveNFTWXDAI.ownerToTroveIds(A);
        uint256[] memory bTroves = troveNFTWXDAI.ownerToTroveIds(B);
        uint256[] memory cTroves = troveNFTWXDAI.ownerToTroveIds(C);
        
        assertEq(aTroves.length, 4, "A should have 4 troves");
        assertEq(bTroves.length, 0, "B should have 0 troves");
        assertEq(cTroves.length, 0, "C should have 0 troves");
    }

    function testGovernorFunctions() public {
        address newGovernor = address(0x123);
        address currentGovernor = troveNFTWXDAI.governor();
        
        // Non-governor cannot change governor
        vm.prank(A);
        vm.expectRevert("TroveNFT: Caller is not the governor");
        troveNFTWXDAI.changeGovernor(newGovernor);
        
        // Non-governor cannot update URI
        vm.prank(A);
        vm.expectRevert("TroveNFT: Caller is not the governor.");
        troveNFTWXDAI.governorUpdateURI(address(0x456));
        
        // Governor can change governor
        vm.prank(currentGovernor);
        troveNFTWXDAI.changeGovernor(newGovernor);
        assertEq(troveNFTWXDAI.governor(), newGovernor, "Governor should be updated");
        
        // Old governor can no longer act
        vm.prank(currentGovernor);
        vm.expectRevert("TroveNFT: Caller is not the governor");
        troveNFTWXDAI.changeGovernor(currentGovernor);
        
        // New governor can update URI
        vm.prank(newGovernor);
        troveNFTWXDAI.governorUpdateURI(address(0x789));
        assertEq(troveNFTWXDAI.externalNFTUriAddress(), address(0x789), "External URI should be updated");
    }

    function testERC721Enumerable() public view {
        // Test totalSupply
        uint256 totalSupply = troveNFTWXDAI.totalSupply();
        assertEq(totalSupply, 4, "Total supply should be 4");
        
        // Test tokenOfOwnerByIndex
        uint256 firstToken = troveNFTWXDAI.tokenOfOwnerByIndex(A, 0);
        assertEq(troveNFTWXDAI.ownerOf(firstToken), A, "First token should be owned by A");
        
        // Test tokenByIndex
        uint256 globalFirstToken = troveNFTWXDAI.tokenByIndex(0);
        assertTrue(troveNFTWXDAI.ownerOf(globalFirstToken) != address(0), "Token at index 0 should exist");
        
        // Verify all tokens are enumerable
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 tokenId = troveNFTWXDAI.tokenByIndex(i);
            assertTrue(troveNFTWXDAI.ownerOf(tokenId) != address(0), "All tokens should have owners");
        }
    }

    function testTransferNonExistentToken() public {
        uint256 nonExistentId = 999999;
        
        vm.prank(A);
        vm.expectRevert();
        troveNFTWXDAI.transferFrom(A, B, nonExistentId);
    }

    function testUnauthorizedTransfer() public {
        // B tries to transfer A's token without approval
        vm.prank(B);
        vm.expectRevert();
        troveNFTWXDAI.transferFrom(A, B, troveIds[0]);
    }

    function testApprovalAndTransfer() public {
        // A approves B to transfer troveIds[0]
        vm.prank(A);
        troveNFTWXDAI.approve(B, troveIds[0]);
        
        // B can now transfer
        vm.prank(B);
        troveNFTWXDAI.transferFrom(A, C, troveIds[0]);
        
        assertEq(troveNFTWXDAI.ownerOf(troveIds[0]), C, "C should own the trove after approved transfer");
    }

    function testSetApprovalForAll() public {
        // A approves B as operator for all tokens
        vm.prank(A);
        troveNFTWXDAI.setApprovalForAll(B, true);
        
        // B can transfer any of A's tokens
        vm.prank(B);
        troveNFTWXDAI.transferFrom(A, C, troveIds[0]);
        assertEq(troveNFTWXDAI.ownerOf(troveIds[0]), C, "C should own troveIds[0]");
        
        vm.prank(B);
        troveNFTWXDAI.transferFrom(A, C, troveIds[1]);
        assertEq(troveNFTWXDAI.ownerOf(troveIds[1]), C, "C should own troveIds[1]");
        
        // Verify ownerToTroveIds updated correctly
        uint256[] memory aTroves = troveNFTWXDAI.ownerToTroveIds(A);
        uint256[] memory cTroves = troveNFTWXDAI.ownerToTroveIds(C);
        assertEq(aTroves.length, 2, "A should have 2 troves");
        assertEq(cTroves.length, 2, "C should have 2 troves");
    }
}
