// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SlotMachine is Ownable, ReentrancyGuard {
    // Your pre-deployed NFT contract
    IERC721 public constant NFT_CONTRACT = IERC721(0x96F37136ed9653eb1d2D23cb86C18B8Af870e468);
    
    // Your wallet address (holds the 999 NFTs)
    address public constant NFT_HOLDER = 0x...; // YOUR WALLET ADDRESS HERE
    
    // Spin costs
    uint256 public constant SPIN_COST = 0.1 ether;
    uint256 public constant DISCOUNTED_SPIN_COST = 0.01 ether;
    
    // NFT tracking
    uint256 public nextNFTTokenId = 1; // Start from token ID 1
    uint256 public constant MAX_NFTS = 999;
    
    // Probabilities (out of 10000 for precision)
    uint256 public constant RARE_NFT_PROBABILITY = 1; // 0.01% chance for NFT
    
    // User states
    mapping(address => uint256) public freeSpins;
    mapping(address => uint256) public discountedSpins;
    mapping(address => bool) public hasDiscount;
    
    // Reward pool
    uint256 public rewardPool;
    
    event SpinResult(
        address indexed user,
        string combination,
        uint256 monReward,
        uint256 extraSpins,
        bool discountApplied,
        bool newDiscountGranted,
        bool nftMinted,
        uint256 nftTokenId
    );
    
    event RewardPoolUpdated(uint256 newBalance);
    event NFTAwarded(address indexed winner, uint256 tokenId);
    
    constructor() {
        rewardPool = 0;
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
        
        // Check for NFT win (very rare)
        bool nftWon = false;
        uint256 nftTokenId = 0;
        
        if (nextNFTTokenId <= MAX_NFTS) {
            uint256 nftRoll = (seed / 1000) % 10000;
            if (nftRoll < RARE_NFT_PROBABILITY) {
                nftWon = true;
                nftTokenId = nextNFTTokenId;
                nextNFTTokenId++;
                
                // Transfer NFT from your wallet to winner
                try NFT_CONTRACT.transferFrom(NFT_HOLDER, msg.sender, nftTokenId) {
                    emit NFTAwarded(msg.sender, nftTokenId);
                } catch {
                    // If transfer fails, revert the NFT win
                    nftWon = false;
                    nftTokenId = 0;
                    nextNFTTokenId--; // Revert the increment
                }
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
            nftTokenId
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
    
    // Emergency function to update NFT holder address if needed
    function updateNFTHolder(address newHolder) external onlyOwner {
        // This would require redeploying, but kept for reference
        revert("NFT holder is hardcoded for security");
    }
}