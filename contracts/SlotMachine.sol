// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract SlotMachine is Ownable, ReentrancyGuard, IERC1155Receiver {
    // Your pre-deployed NFT contract (ERC-1155)
    IERC1155 public constant NFT_CONTRACT = IERC1155(0x96F37136ed9653eb1d2D23cb86C18B8Af870e468);
    
    // NFT details - TOKEN ID = 0 (confirmed from explorer)
    uint256 public constant NFT_TOKEN_ID = 0;
    uint256 public nftBalance; // How many NFTs this contract holds
    uint256 public nftsAwarded = 0;
    
    // Spin costs
    uint256 public constant SPIN_COST = 0.1 ether;
    uint256 public constant DISCOUNTED_SPIN_COST = 0.01 ether;
    
    // Probabilities (out of 10000 for precision)
    uint256 public constant RARE_NFT_PROBABILITY = 1; // 0.01% chance for NFT
    uint256 public constant MAINNET_WL_PROBABILITY = 500; // 5% chance for mainnet WL
    
    // User states
    mapping(address => uint256) public freeSpins;
    mapping(address => uint256) public discountedSpins;
    mapping(address => bool) public hasDiscount;
    mapping(address => bool) public hasMainnetWhitelist; // NEW: Mainnet WL tracking
    
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
        bool nftMinted,
        bool mainnetWhitelistWon // NEW: Mainnet WL event
    );
    
    event RewardPoolUpdated(uint256 newBalance);
    event NFTAwarded(address indexed winner, uint256 tokenId, uint256 amount);
    event NFTsDeposited(uint256 tokenId, uint256 amount);
    event MainnetWhitelistAwarded(address indexed winner); // NEW: Mainnet WL event
    
    constructor() {
        rewardPool = 0;
        nftBalance = 0;
    }
    
    // Function for you to deposit NFTs into the contract
    function depositNFTs(uint256 amount) external onlyOwner {
        // Transfer NFTs from your wallet to this contract
        NFT_CONTRACT.safeTransferFrom(msg.sender, address(this), NFT_TOKEN_ID, amount, "");
        nftBalance += amount;
        emit NFTsDeposited(NFT_TOKEN_ID, amount);
    }
    
    // Check how many NFTs are available
    function getAvailableNFTCount() external view returns (uint256) {
        return nftBalance;
    }
    
    // NEW: Check if user has mainnet whitelist
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
        
        // Calculate rewards
        (uint256 monReward, uint256 extraSpins, bool newDiscountGranted) = calculateRewards(fruits, seed);
        
        // Check for NFT win (0.01% chance)
        bool nftWon = false;
        if (nftBalance > 0) {
            uint256 nftRoll = (seed / 1000) % 10000;
            if (nftRoll < RARE_NFT_PROBABILITY) {
                // Transfer 1 NFT to winner
                NFT_CONTRACT.safeTransferFrom(address(this), msg.sender, NFT_TOKEN_ID, 1, "");
                nftBalance--;
                nftWon = true;
                nftsAwarded++;
                
                emit NFTAwarded(msg.sender, NFT_TOKEN_ID, 1);
            }
        }
        
        // NEW: Check for Mainnet Whitelist win (5% chance)
        bool mainnetWLWon = false;
        if (!hasMainnetWhitelist[msg.sender]) { // Only if they don't already have it
            uint256 wlRoll = (seed / 2000) % 10000;
            if (wlRoll < MAINNET_WL_PROBABILITY) {
                hasMainnetWhitelist[msg.sender] = true;
                mainnetWLWon = true;
                mainnetWhitelistsAwarded++;
                
                emit MainnetWhitelistAwarded(msg.sender);
            }
        }
        
        // Apply rewards
        if (monReward > 0 && rewardPool >= monReward) {
            rewardPool -= monReward;
            payable(msg.sender).transfer(monReward);
            emit RewardPoolUpdated(rewardPool);
        }
        
        if (extraSpins > 0) {
            freeSpins[msg.sender] += extraSpins;
        }
        
        if (newDiscountGranted) {
            hasDiscount[msg.sender] = true;
            discountedSpins[msg.sender] += 5; // 5 discounted spins
        }
        
        emit SpinResult(
            msg.sender,
            combination,
            monReward,
            extraSpins,
            discountApplied,
            newDiscountGranted,
            nftWon,
            mainnetWLWon // NEW: Include mainnet WL in event
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
        
        // Three of a kind
        if (match01 && match12) {
            if (keccak256(bytes(fruits[0])) == keccak256(bytes("cherry"))) {
                monReward = 0.05 ether; // 50 coins worth
                extraSpins = 3;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("apple"))) {
                monReward = 0.02 ether; // 20 coins worth
                extraSpins = 2;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("banana"))) {
                monReward = 0.015 ether; // 15 coins worth
                extraSpins = 1;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("lemon"))) {
                monReward = 0.003 ether; // 3 coins worth
            }
        }
        // Two of a kind (consecutive from left)
        else if (match01) {
            if (keccak256(bytes(fruits[0])) == keccak256(bytes("cherry"))) {
                monReward = 0.04 ether; // 40 coins worth
                extraSpins = 2;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("apple"))) {
                monReward = 0.01 ether; // 10 coins worth
                extraSpins = 1;
            } else if (keccak256(bytes(fruits[0])) == keccak256(bytes("banana"))) {
                monReward = 0.005 ether; // 5 coins worth
            }
        }
        
        // Random discount chance (5%)
        uint256 discountRoll = (seed / 100) % 100;
        if (discountRoll < 5) {
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
    
    // NEW: Owner function to manually grant mainnet whitelist (if needed)
    function grantMainnetWhitelist(address user) external onlyOwner {
        hasMainnetWhitelist[user] = true;
        mainnetWhitelistsAwarded++;
        emit MainnetWhitelistAwarded(user);
    }
    
    // NEW: Get stats
    function getStats() external view returns (
        uint256 totalNFTsAwarded,
        uint256 totalMainnetWLAwarded,
        uint256 availableNFTs
    ) {
        return (nftsAwarded, mainnetWhitelistsAwarded, nftBalance);
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
    
    // Emergency function to withdraw NFTs if needed
    function emergencyWithdrawNFT(uint256 amount) external onlyOwner {
        NFT_CONTRACT.safeTransferFrom(address(this), owner(), NFT_TOKEN_ID, amount, "");
        nftBalance -= amount;
    }
}