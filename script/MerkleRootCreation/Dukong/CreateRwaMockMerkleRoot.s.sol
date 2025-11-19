// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script off/MerkleRootCreation/Dukong/CreateRwaMockMerkleRoot.s.sol:CreateRwaMockMerkleRootScript --rpc-url $MANTRA_DUKONG_RPC_URL
 * @dev Update addresses after deployment from MantraRwaDeployment.json
 */
contract CreateRwaMockMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // TODO: Update these addresses after deployment from MantraRwaDeployment.json
    address public boringVault = address(0); // Update from deployment JSON
    address public managerAddress = address(0); // Update from deployment JSON
    address public accountantAddress = address(0); // Update from deployment JSON
    address public rawDataDecoderAndSanitizer = address(0); // RwaMockDecoderAndSanitizer address from deployment JSON
    address public rwaMockVault = address(0); // RwaMock contract address (if deployed separately)

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateRwaMockStrategistMerkleRoot();
    }

    function generateRwaMockStrategistMerkleRoot() public {
        // Use "dukong" as chain name (string literal since it's not in ChainValues constants)
        string memory chainName = "dukong";
        setSourceChainName(chainName);
        setAddress(false, chainName, "boringVault", boringVault);
        setAddress(false, chainName, "managerAddress", managerAddress);
        setAddress(false, chainName, "accountantAddress", accountantAddress);
        setAddress(false, chainName, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // Create leafs array - ERC4626 adds 5 leafs, plus 2 for addProfit and addLoss = 7 total
        // Note: leafIndex starts at type(uint256).max (default), helper functions increment before assignment
        ManageLeaf[] memory leafs = new ManageLeaf[](7);

        // ========================== ERC4626 Standard Functions ==========================
        // This adds: approve, deposit, withdraw, mint, redeem
        _addERC4626Leafs(leafs, ERC4626(rwaMockVault));

        // ========================== RwaMock Custom Functions ==========================
        // Add leaf for addProfit(uint256)
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rwaMockVault,
            false,
            "addProfit(uint256)",
            new address[](0),
            "Add profit to RwaMock vault",
            rawDataDecoderAndSanitizer
        );

        // Add leaf for addLoss(uint256)
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rwaMockVault,
            false,
            "addLoss(uint256)",
            new address[](0),
            "Add loss to RwaMock vault",
            rawDataDecoderAndSanitizer
        );

        // Verify that the decoder implements all function selectors
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Dukong/RwaMockStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}

