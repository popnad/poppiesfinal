/*
 *  Copyright (c) Michael Kolesidis <michael.kolesidis@gmail.com>
 *  GNU Affero General Public License v3.0
 *
 *  ATTENTION! FREE SOFTWARE
 *  This website is free software (free as in freedom).
 *  If you use any part of this code, you must make your entire project's source code
 *  publicly available under the same license. This applies whether you modify the code
 *  or use it as it is in your own project. This ensures that all modifications and
 *  derivative works remain free software, so that everyone can benefit.
 *  If you are not willing to comply with these terms, you must refrain from using any part of this code.
 *
 *  For full license terms and conditions, you can read the AGPL-3.0 here:
 *  https://www.gnu.org/licenses/agpl-3.0.html
 */

import { useEffect, useState, useCallback } from 'react';
import { usePrivy, useWallets } from '@privy-io/react-auth';
import { ethers } from 'ethers';

// Updated ABI for your new contract
const SLOT_MACHINE_ABI = [
  {"inputs":[],"name":"fundContract","outputs":[],"stateMutability":"payable","type":"function"},
  {"inputs":[],"name":"spin","outputs":[],"stateMutability":"payable","type":"function"},
  {"inputs":[{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"withdraw","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[],"name":"DISCOUNTED_SPIN_COST","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"discountedSpins","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"freeSpins","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"getRewardPool","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"internalType":"address","name":"user","type":"address"}],"name":"getSpinCost","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"getStats","outputs":[{"internalType":"uint256","name":"totalPoppiesNFTsAwarded","type":"uint256"},{"internalType":"uint256","name":"totalRarestWins","type":"uint256"},{"internalType":"uint256","name":"availablePoppiesNFTs","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"hasDiscount","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"rewardPool","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"SPIN_COST","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"POPPIES_NFT","outputs":[{"internalType":"contract IERC1155","name":"","type":"address"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"POPPIES_TOKEN_ID","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"poppiesNftBalance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"poppiesNftsAwarded","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"rarestWins","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"user","type":"address"},{"indexed":false,"internalType":"string","name":"combination","type":"string"},{"indexed":false,"internalType":"uint256","name":"monReward","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"extraSpins","type":"uint256"},{"indexed":false,"internalType":"bool","name":"discountApplied","type":"bool"},{"indexed":false,"internalType":"bool","name":"newDiscountGranted","type":"bool"},{"indexed":false,"internalType":"bool","name":"poppiesNftWon","type":"bool"},{"indexed":false,"internalType":"bool","name":"rarestPending","type":"bool"}],"name":"SpinResult","type":"event"},
  {"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"newBalance","type":"uint256"}],"name":"RewardPoolUpdated","type":"event"},
  {"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"winner","type":"address"},{"indexed":false,"internalType":"uint256","name":"tokenId","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"}],"name":"PoppiesNFTAwarded","type":"event"},
  {"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"winner","type":"address"}],"name":"RarestWinPending","type":"event"}
];

// Updated contract address
const SLOT_MACHINE_ADDRESS = '0xCc53BEE0772B8A0Be08BCE3DD404bFCAC85E1635';

// Monad Testnet configuration - Chain ID 10143
export const MONAD_TESTNET = {
  id: 10143,
  name: 'Monad Testnet',
  network: 'monad-testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'MON',
    symbol: 'MON',
  },
  rpcUrls: {
    default: {
      http: ['https://testnet-rpc.monad.xyz'],
    },
    public: {
      http: ['https://testnet-rpc.monad.xyz'],
    },
  },
  blockExplorers: {
    default: { name: 'Monad Explorer', url: 'https://testnet.monadexplorer.com' },
  },
  testnet: true,
};

export function useBlockchainGame() {
  const { ready, authenticated } = usePrivy();
  const { wallets } = useWallets();

  // Only use the Privy embedded wallet
  const privyWallet = wallets.find(w => w.walletClientType === 'privy');
  
  const [provider, setProvider] = useState<ethers.BrowserProvider | null>(null);
  const [signer, setSigner] = useState<ethers.Signer | null>(null);
  const [contract, setContract] = useState<ethers.Contract | null>(null);

  // Blockchain state
  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const [monBalance, setMonBalance] = useState<string>('0');
  const [freeSpins, setFreeSpins] = useState<number>(0);
  const [discountedSpins, setDiscountedSpins] = useState<number>(0);
  const [hasDiscount, setHasDiscount] = useState<boolean>(false);
  const [rewardPool, setRewardPool] = useState<string>('0');
  const [networkError, setNetworkError] = useState<boolean>(false);

  // New state for NFT and stats
  const [poppiesNftBalance, setPoppiesNftBalance] = useState<number>(0);
  const [poppiesNftsAwarded, setPoppiesNftsAwarded] = useState<number>(0);
  const [rarestWins, setRarestWins] = useState<number>(0);

  // New state for insufficient funds
  const [showInsufficientFunds, setShowInsufficientFunds] = useState<boolean>(false);
  const [insufficientFundsData, setInsufficientFundsData] = useState<{
    currentBalance: string;
    requiredAmount: string;
  } | null>(null);

  // Gas settings for Monad testnet
  const getDynamicGasSettings = useCallback(async (provider: ethers.BrowserProvider) => {
    try {
      return {
        gasLimit: 1000000,
        maxFeePerGas: ethers.parseUnits('1000', 'gwei'),
        maxPriorityFeePerGas: ethers.parseUnits('500', 'gwei')
      };
    } catch (error) {
      console.warn('⚠️ Failed to get gas settings, using ultra-high fallback:', error);
      
      return {
        gasLimit: 1000000,
        maxFeePerGas: ethers.parseUnits('2000', 'gwei'),
        maxPriorityFeePerGas: ethers.parseUnits('1000', 'gwei')
      };
    }
  }, []);

  // Initialize provider, signer, and contract when Privy wallet is ready
  useEffect(() => {
    async function setup() {
      if (ready && authenticated && privyWallet) {
        try {
          console.log('Setting up Privy wallet...');
          const ethProvider = await privyWallet.getEthereumProvider();
          
          // Configure provider for Monad Testnet
          const ethersProvider = new ethers.BrowserProvider(ethProvider, {
            name: 'monad-testnet',
            chainId: 10143,
            ensAddress: null,
          });
          
          // Switch to Monad Testnet if needed
          try {
            await ethProvider.request({
              method: 'wallet_switchEthereumChain',
              params: [{ chainId: `0x${MONAD_TESTNET.id.toString(16)}` }],
            });
          } catch (switchError: any) {
            // If the chain doesn't exist, add it
            if (switchError.code === 4902) {
              await ethProvider.request({
                method: 'wallet_addEthereumChain',
                params: [{
                  chainId: `0x${MONAD_TESTNET.id.toString(16)}`,
                  chainName: MONAD_TESTNET.name,
                  nativeCurrency: MONAD_TESTNET.nativeCurrency,
                  rpcUrls: MONAD_TESTNET.rpcUrls.default.http,
                  blockExplorerUrls: [MONAD_TESTNET.blockExplorers.default.url],
                }],
              });
            }
          }
          
          setProvider(ethersProvider);
          
          const ethersSigner = await ethersProvider.getSigner();
          setSigner(ethersSigner);
          
          const address = await ethersSigner.getAddress();
          setWalletAddress(address);
          console.log('Wallet address:', address);
          
          const slotContract = new ethers.Contract(SLOT_MACHINE_ADDRESS, SLOT_MACHINE_ABI, ethersSigner);
          setContract(slotContract);
          console.log('Contract initialized with new address:', SLOT_MACHINE_ADDRESS);
          
          setNetworkError(false);
        } catch (error) {
          console.error('Error setting up wallet:', error);
          setNetworkError(true);
        }
      }
    }
    setup();
  }, [ready, authenticated, privyWallet]);

  // Fetch blockchain state
  const fetchState = useCallback(async () => {
    if (contract && walletAddress && provider) {
      try {
        console.log('Fetching blockchain state...');
        
        // Fetch balance
        try {
          const balance = await provider.getBalance(walletAddress);
          setMonBalance(ethers.formatEther(balance));
          console.log('MON Balance:', ethers.formatEther(balance));
          setNetworkError(false);
        } catch (balanceError) {
          console.error('Error fetching balance:', balanceError);
          setNetworkError(true);
        }
        
        // Fetch contract state with parallel calls for speed
        try {
          const [
            freeSpinsResult, 
            discountedSpinsResult, 
            hasDiscountResult, 
            rewardPoolResult,
            statsResult
          ] = await Promise.allSettled([
            contract.freeSpins(walletAddress),
            contract.discountedSpins(walletAddress),
            contract.hasDiscount(walletAddress),
            contract.getRewardPool(),
            contract.getStats()
          ]);

          if (freeSpinsResult.status === 'fulfilled') {
            setFreeSpins(Number(freeSpinsResult.value));
          }
          if (discountedSpinsResult.status === 'fulfilled') {
            setDiscountedSpins(Number(discountedSpinsResult.value));
          }
          if (hasDiscountResult.status === 'fulfilled') {
            setHasDiscount(Boolean(hasDiscountResult.value));
          }
          if (rewardPoolResult.status === 'fulfilled') {
            setRewardPool(ethers.formatEther(rewardPoolResult.value));
          }
          if (statsResult.status === 'fulfilled') {
            const [totalPoppiesNFTsAwarded, totalRarestWins, availablePoppiesNFTs] = statsResult.value;
            setPoppiesNftsAwarded(Number(totalPoppiesNFTsAwarded));
            setRarestWins(Number(totalRarestWins));
            setPoppiesNftBalance(Number(availablePoppiesNFTs));
          }
        } catch (error) {
          console.error('Error fetching contract state:', error);
          setNetworkError(true);
        }
        
        console.log('State fetched successfully');
      } catch (error) {
        console.error('Error fetching state:', error);
        setNetworkError(true);
      }
    }
  }, [contract, walletAddress, provider]);

  useEffect(() => {
    fetchState();
  }, [fetchState]);

  // Check if user has sufficient funds for spinning (with realistic gas estimation)
  const checkSufficientFunds = useCallback(async () => {
    if (!monBalance || !authenticated || !provider || !contract || !walletAddress) return false;
    
    const balance = parseFloat(monBalance);
    
    try {
      // Get actual spin cost from contract
      const spinCostWei = await contract.getSpinCost(walletAddress);
      const spinCost = parseFloat(ethers.formatEther(spinCostWei));
      
      // Calculate realistic gas cost for Monad testnet
      const gasLimit = BigInt(1000000);
      const maxFeePerGas = ethers.parseUnits('1000', 'gwei');
      
      const estimatedGasCostWei = gasLimit * maxFeePerGas;
      const estimatedGasCost = parseFloat(ethers.formatEther(estimatedGasCostWei));
      
      const totalRequired = spinCost + estimatedGasCost;
      
      console.log('💰 Fund check:', {
        balance: balance.toFixed(6),
        spinCost: spinCost.toFixed(6),
        estimatedGasCost: estimatedGasCost.toFixed(6),
        totalRequired: totalRequired.toFixed(6),
        sufficient: balance >= totalRequired
      });
      
      return balance >= totalRequired;
    } catch (error) {
      console.error('Error checking sufficient funds:', error);
      return false;
    }
  }, [monBalance, authenticated, provider, contract, walletAddress]);

  // REAL blockchain spin function
  const spin = useCallback(async () => {
    if (!contract || !signer || !provider || !walletAddress) {
      console.error('Contract not ready');
      return null;
    }
    
    if (networkError) {
      console.error('Network connection issues');
      return null;
    }
    
    // Check for sufficient funds before attempting spin
    const hasSufficientFunds = await checkSufficientFunds();
    if (!hasSufficientFunds) {
      console.log('❌ Insufficient funds - showing popup');
      showInsufficientFundsPopup();
      return null;
    }

    try {
      // Get spin cost from contract
      const spinCostWei = await contract.getSpinCost(walletAddress);
      
      console.log(`🎰 Starting blockchain spin with cost: ${ethers.formatEther(spinCostWei)} MON`);
      console.log(`📊 Current state - Free: ${freeSpins}, Discounted: ${discountedSpins}, HasDiscount: ${hasDiscount}`);
      
      // Get gas settings
      const gasSettings = await getDynamicGasSettings(provider);
      
      const txParams = {
        value: spinCostWei,
        ...gasSettings
      };
      
      console.log('📊 Using gas settings:', {
        gasLimit: txParams.gasLimit.toString(),
        maxFeePerGas: ethers.formatUnits(txParams.maxFeePerGas, 'gwei') + ' gwei',
        maxPriorityFeePerGas: ethers.formatUnits(txParams.maxPriorityFeePerGas, 'gwei') + ' gwei'
      });
      
      // Send transaction
      const tx = await contract.spin(txParams);
      console.log('📤 Transaction sent:', tx.hash);
      
      // Wait for confirmation
      const receipt = await tx.wait();
      console.log('✅ Transaction confirmed:', receipt.hash);
      
      // Parse transaction logs
      console.log('🔍 Parsing transaction logs...');
      console.log('📋 Total logs found:', receipt.logs.length);
      
      let spinResultEvent = null;
      
      // Try to find SpinResult event
      for (let i = 0; i < receipt.logs.length; i++) {
        const log = receipt.logs[i];
        try {
          const parsed = contract.interface.parseLog(log);
          console.log(`📝 Log ${i}: ${parsed?.name || 'Unknown'}`);
          
          if (parsed?.name === 'SpinResult') {
            spinResultEvent = parsed;
            console.log('🎯 Found SpinResult event!');
            break;
          }
        } catch (parseError) {
          console.log(`⚠️ Could not parse log ${i}:`, parseError);
        }
      }
      
      if (spinResultEvent) {
        const { 
          combination, 
          monReward, 
          extraSpins, 
          poppiesNftWon, 
          rarestPending,
          discountApplied, 
          newDiscountGranted 
        } = spinResultEvent.args;
        
        // Parse combination into fruit array
        const fruits = combination.split('|');
        const rewardAmount = ethers.formatEther(monReward);
        
        const result = {
          combination: fruits,
          monReward: rewardAmount,
          extraSpins: Number(extraSpins),
          nftMinted: poppiesNftWon, // Poppies NFT won
          rarestPending: rarestPending, // Rarest win pending
          discountApplied,
          newDiscountGranted,
          txHash: receipt.hash
        };
        
        console.log('🎯 Blockchain result:', {
          combination: fruits.join(' | '),
          monReward: rewardAmount + ' MON',
          extraSpins: Number(extraSpins),
          poppiesNftWon: poppiesNftWon ? 'YES' : 'NO',
          rarestPending: rarestPending ? 'YES' : 'NO',
          discountApplied: discountApplied ? 'YES' : 'NO',
          newDiscountGranted: newDiscountGranted ? 'YES' : 'NO',
          txHash: receipt.hash
        });
        
        // Refresh state in background
        setTimeout(() => {
          fetchState();
        }, 2000);
        
        return result;
      } else {
        console.error('❌ No SpinResult event found in transaction logs');
        console.log('📋 All logs:', receipt.logs);
        return null;
      }
      
    } catch (error: any) {
      console.error('❌ Blockchain spin failed:', error);
      
      if (error.code === 'INSUFFICIENT_FUNDS' || error.message?.includes('insufficient funds')) {
        showInsufficientFundsPopup();
      } else if (error.code === 'USER_REJECTED') {
        console.error('❌ Transaction cancelled');
      } else if (error.message?.includes('execution reverted')) {
        console.error('❌ Contract execution reverted:', error.message);
      }
      
      return null;
    }
  }, [contract, signer, provider, walletAddress, freeSpins, hasDiscount, discountedSpins, networkError, fetchState, getDynamicGasSettings, checkSufficientFunds]);

  const getSpinCost = useCallback(() => {
    if (freeSpins > 0) return 'Free';
    if (hasDiscount && discountedSpins > 0) return '0.01 MON';
    return '0.1 MON';
  }, [freeSpins, hasDiscount, discountedSpins]);

  // Function to show insufficient funds popup manually
  const showInsufficientFundsPopup = useCallback(() => {
    const spinCost = freeSpins > 0 ? 0 : (hasDiscount && discountedSpins > 0) ? 0.01 : 0.1;
    const gasEstimate = 1; // Rough estimate for display
    const requiredAmount = freeSpins > 0 ? `~${gasEstimate} MON (gas only)` : 
                         `~${(spinCost + gasEstimate).toFixed(2)} MON (${spinCost} + gas)`;
    
    setInsufficientFundsData({
      currentBalance: monBalance || '0',
      requiredAmount: requiredAmount
    });
    setShowInsufficientFunds(true);
  }, [freeSpins, hasDiscount, discountedSpins, monBalance]);

  const handleInsufficientFundsClose = useCallback(() => {
    setShowInsufficientFunds(false);
    setInsufficientFundsData(null);
  }, []);

  const handleInsufficientFundsRefresh = useCallback(async () => {
    await fetchState();
    
    // Check if funds are now sufficient
    const hasSufficientFunds = await checkSufficientFunds();
    if (hasSufficientFunds) {
      setShowInsufficientFunds(false);
      setInsufficientFundsData(null);
    }
  }, [fetchState, checkSufficientFunds]);

  return {
    ready,
    authenticated,
    walletAddress,
    monBalance,
    freeSpins,
    discountedSpins,
    hasDiscount,
    rewardPool,
    networkError,
    // New NFT and stats data
    poppiesNftBalance,
    poppiesNftsAwarded,
    rarestWins,
    spin,
    getSpinCost,
    refreshState: fetchState,
    checkSufficientFunds,
    showInsufficientFunds,
    setShowInsufficientFunds,
    insufficientFundsData,
    setInsufficientFundsData,
    handleInsufficientFundsClose,
    handleInsufficientFundsRefresh,
  };
}