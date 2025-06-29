// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract SlotMachine is Ownable, ReentrancyGuard, IERC1155Receiver {
    // NFT Contracts
    IERC1155 public constant CHERRY_CHARM_NFT = IERC1155(0x96F37136ed9653eb1d2D23cb86C18B8Af870e468);
    IERC1155 public constant POPPIES_NFT = IERC1155(0x96F37136ed9653eb1d2D23cb86C18B8Af870e468); // Update with actual Poppies contract
    
    // NFT Token IDs
    uint256 public constant CHERRY_CHARM_TOKEN_ID = 0;
    uint256 public constant POPPIES_TOKEN_ID = 1; // Update with actual Poppies token ID
    
    // NFT Balances
    uint256 public cherryCharmNftBalance;
    uint256 public poppiesNftBalance;
    
    // NFT Stats
    uint256 public cherryCharmNftsAwarded = 0;
    uint256 public poppiesNftsAwarded = 0;
    
    // Spin costs
    uint256 public constant SPIN_COST = 0.1 ether;
    uint256 public constant DISCOUNTED_SPIN_COST = 0.01 ether;
    
    // NEW PROBABILITIES (out of 10000 for precision)
    uint256 public constant CHERRY_CHARM_NFT_PROBABILITY = 500; // 5% chance
    uint256 public constant POPPIES_NFT_PROBABILITY = 1000; // 10% chance
    uint256 public constant MAINNET_WL_PROBABILITY = 500; // 5% chance for mainnet WL
    
    // User states
    mapping(address => uint256) public freeSpins;
    mapping(address => uint256) public discountedSpins;
    mapping(address => bool) public hasDiscount;
    mapping(address => bool) public hasMainnetWhitelist;
    
    // Reward pool
    uint256 public rewardPool;
    
    // Stats
    uint256 public mainnetWhitelistsAwarded = 0;
    
    event SpinResult(
        address indexed user,
        string combination,
        uint256 monReward,
        uint256 extraSpins,
        bool discountApplied,
        bool newDiscountGranted,
        bool cherryCharmNftWon,
        bool poppiesNftWon,
        bool mainnetWhitelistWon
    );
    
    event RewardPoolUpdated(uint256 newBalance);
    event CherryCharmNFTAwarded(address indexed winner, uint256 tokenId, uint256 amount);
    event PoppiesNFTAwarded(address indexed winner, uint256 tokenId, uint256 amount);
    event NFTsDeposited(address indexed nftContract, uint256 tokenId, uint256 amount);
    event MainnetWhitelistAwarded(address indexed winner);
    
    constructor() {
        rewardPool = 0;
        cherryCharmNftBalance = 0;
        poppiesNftBalance = 0;
    }
    
    // Function to deposit CherryCharm NFTs
    function depositCherryCharmNFTs(uint256 amount) external onlyOwner {
        CHERRY_CHARM_NFT.safeTransferFrom(msg.sender, address(this), CHERRY_CHARM_TOKEN_ID, amount, "");
        cherryCharmNftBalance += amount;
        emit NFTsDeposited(address(CHERRY_CHARM_NFT), CHERRY_CHARM_TOKEN_ID, amount);
    }
    
    // Function to deposit Poppies NFTs
    function depositPoppiesNFTs(uint256 amount) external onlyOwner {
        POPPIES_NFT.safeTransferFrom(msg.sender, address(this), POPPIES_TOKEN_ID, amount, "");
        poppiesNftBalance += amount;
        emit NFTsDeposited(address(POPPIES_NFT), POPPIES_TOKEN_ID, amount);
    }
    
    // Check available NFT counts
    function getAvailableNFTCounts() external view returns (uint256 cherryCharm, uint256 poppies) {
        return (cherryCharmNftBalance, poppiesNftBalance);
    }
    
    // Check if user has mainnet whitelist
    function checkMainnetWhitelist(address user) external view returns (bool) {
        return hasMainnetWhitelist[user];
    }
    
    function spin() external payable nonReentrant {
        uint256 cost = getSpinCost(msg.sender);
        require(msg.value >= cost, "Insufficient payment");
        
        // Update user state
        bool discountApplied = false;
        if (freeSpins[msg.sender] > 0) {
            freeSpins[msg.sender]--;
        } else if (hasDiscount[msg.sender] && discountedSpins[msg.sender] > 0) {
            discountedSpins[msg.sender]--;
            discountApplied = true;
            if (discountedSpins[msg.sender] == 0) {
                hasDiscount[msg.sender] = false;
            }
        }
        
        // Add to reward pool
        rewardPool += msg.value;
        emit RewardPoolUpdated(rewardPool);
        
        // Generate random results
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            rewardPool
        )));
        
        // Generate fruit combination
        string[3] memory fruits = generateFruits(seed);
        string memory combination = string(abi.encodePacked(
            fruits[0], "|", fruits[1], "|", fruits[2]
        ));
        
        // Calculate MON rewards and spins
        (uint256 monReward, uint256 extraSpins, bool newDiscountGranted) = calculateRewards(fruits, seed);
        
        // Check for CherryCharm NFT win (5% chance)
        bool cherryCharmNftWon = false;
        if (cherryCharmNftBalance > 0) {
            uint256 cherryCharmRoll = (seed / 1000) % 10000;
            if (cherryCharmRoll < CHERRY_CHARM_NFT_PROBABILITY) {
                CHERRY_CHARM_NFT.safeTransferFrom(address(this), msg.sender, CHERRY_CHARM_TOKEN_ID, 1, "");
                cherryCharmNftBalance--;
                cherryCharmNftWon = true;
                cherryCharmNftsAwarded++;
                emit CherryCharmNFTAwarded(msg.sender, CHERRY_CHARM_TOKEN_ID, 1);
            }
        }
        
        // Check for Poppies NFT win (10% chance)
        bool poppiesNftWon = false;
        if (poppiesNftBalance > 0) {
            uint256 poppiesRoll = (seed / 2000) % 10000;
            if (poppiesRoll < POPPIES_NFT_PROBABILITY) {
                POPPIES_NFT.safeTransferFrom(address(this), msg.sender, POPPIES_TOKEN_ID, 1, "");
                poppiesNftBalance--;
                poppiesNftWon = true;
                poppiesNftsAwarded++;
                emit PoppiesNFTAwarded(msg.sender, POPPIES_TOKEN_ID, 1);
            }
        }
        
        // Check for Mainnet Whitelist win (5% chance)
        bool mainnetWLWon = false;
        if (!hasMainnetWhitelist[msg.sender]) {
            uint256 wlRoll = (seed / 3000) % 10000;
            if (wlRoll < MAINNET_WL_PROBABILITY) {
                hasMainnetWhitelist[msg.sender] = true;
                mainnetWLWon = true;
                mainnetWhitelistsAwarded++;
                emit MainnetWhitelistAwarded(msg.sender);
            }
        }
        
        // Apply MON rewards
        if (monReward > 0 && rewardPool >= monReward) {
            rewardPool -= monReward;
            payable(msg.sender).transfer(monReward);
            emit RewardPoolUpdated(rewardPool);
        }
        
        // Apply spin rewards
        if (extraSpins > 0) {
            freeSpins[msg.sender] += extraSpins;
        }
        
        if (newDiscountGranted) {
            hasDiscount[msg.sender] = true;
            discountedSpins[msg.sender] += 10; // 10 discounted spins
        }
        
        emit SpinResult(
            msg.sender,
            combination,
            monReward,
            extraSpins,
            discountApplied,
            newDiscountGranted,
            cherryCharmNftWon,
            poppiesNftWon,
            mainnetWLWon
        );
    }
    
    function generateFruits(uint256 seed) internal pure returns (string[3] memory) {
        string[4] memory fruitTypes = ["cherry", "apple", "banana", "lemon"];
        string[3] memory result;
        
        for (uint i = 0; i < 3; i++) {
            uint256 fruitIndex = (seed / (10 ** i)) % 4;
            result[i] = fruitTypes[fruitIndex];
        }
        
        return result;
    }
    
    function calculateRewards(string[3] memory fruits, uint256 seed) 
        internal 
        pure 
        returns (uint256 monReward, uint256 extraSpins, bool newDiscountGranted) 
    {
        // Check for matches
        bool match01 = keccak256(bytes(fruits[0])) == keccak256(bytes(fruits[1]));
        bool match12 = keccak256(bytes(fruits[1])) == keccak256(bytes(fruits[2]));
        bool match02 = keccak256(bytes(fruits[0])) == keccak256(bytes(fruits[2]));
        
        // NEW REDUCED REWARDS (10% lower than before)
        // Three of a kind
        if (match01 && match12) {
            if (keccak256(bytes(fruits[0])) == keccak256(bytes("cherry"))) {
                monReward = 0.045 ether; // Was 0.05, now 0.045 (10% reduction)
                extraSpins = 2;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("apple"))) {
                monReward = 0.018 ether; // Was 0.02, now 0.018 (10% reduction)
                extraSpins = 3;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("banana"))) {
                monReward = 0.0135 ether; // Was 0.015, now 0.0135 (10% reduction)
                extraSpins = 1;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("lemon"))) {
                monReward = 0.0027 ether; // Was 0.003, now 0.0027 (10% reduction)
            }
        }
        // Two of a kind (consecutive from left)
        else if (match01) {
            if (keccak256(bytes(fruits[0])) == keccak256(bytes("cherry"))) {
                monReward = 0.036 ether; // Was 0.04, now 0.036 (10% reduction)
                extraSpins = 1;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("apple"))) {
                monReward = 0.009 ether; // Was 0.01, now 0.009 (10% reduction)
                extraSpins = 1;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("banana"))) {
                monReward = 0.0045 ether; // Was 0.005, now 0.0045 (10% reduction)
            }
        }
        
        // Random discount chance (8% - slightly higher to compensate)
        uint256 discountRoll = (seed / 100) % 100;
        if (discountRoll < 8) {
            newDiscountGranted = true;
        }
    }
    
    function getSpinCost(address user) public view returns (uint256) {
        if (freeSpins[user] > 0) {
            return 0;
        } else if (hasDiscount[user] && discountedSpins[user] > 0) {
            return DISCOUNTED_SPIN_COST;
        } else {
            return SPIN_COST;
        }
    }
    
    function getRewardPool() external view returns (uint256) {
        return rewardPool;
    }
    
    function fundContract() external payable {
        rewardPool += msg.value;
        emit RewardPoolUpdated(rewardPool);
    }
    
    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= rewardPool, "Insufficient funds");
        rewardPool -= amount;
        payable(owner()).transfer(amount);
        emit RewardPoolUpdated(rewardPool);
    }
    
    // Owner function to manually grant mainnet whitelist
    function grantMainnetWhitelist(address user) external onlyOwner {
        hasMainnetWhitelist[user] = true;
        mainnetWhitelistsAwarded++;
        emit MainnetWhitelistAwarded(user);
    }
    
    // Get comprehensive stats
    function getStats() external view returns (
        uint256 totalCherryCharmNFTsAwarded,
        uint256 totalPoppiesNFTsAwarded,
        uint256 totalMainnetWLAwarded,
        uint256 availableCherryCharmNFTs,
        uint256 availablePoppiesNFTs
    ) {
        return (
            cherryCharmNftsAwarded, 
            poppiesNftsAwarded, 
            mainnetWhitelistsAwarded, 
            cherryCharmNftBalance, 
            poppiesNftBalance
        );
    }
    
    // Required for receiving ERC-1155 NFTs
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    
    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
    
    // Emergency functions to withdraw NFTs if needed
    function emergencyWithdrawCherryCharmNFT(uint256 amount) external onlyOwner {
        CHERRY_CHARM_NFT.safeTransferFrom(address(this), owner(), CHERRY_CHARM_TOKEN_ID, amount, "");
        cherryCharmNftBalance -= amount;
    }
    
    function emergencyWithdrawPoppiesNFT(uint256 amount) external onlyOwner {
        POPPIES_NFT.safeTransferFrom(address(this), owner(), POPPIES_TOKEN_ID, amount, "");
        poppiesNftBalance -= amount;
    }
}