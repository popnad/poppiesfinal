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

import { useEffect, useState } from 'react';
import { MONAD_TESTNET } from '../hooks/useBlockchainGame';
import './InsufficientFundsPopup.css';

interface InsufficientFundsPopupProps {
  walletAddress: string;
  currentBalance: string;
  requiredAmount: string;
  onRefresh: () => void;
  onClose: () => void;
}

const InsufficientFundsPopup = ({ 
  walletAddress, 
  currentBalance, 
  requiredAmount, 
  onRefresh, 
  onClose 
}: InsufficientFundsPopupProps) => {
  const [copied, setCopied] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  console.log('🚨 InsufficientFundsPopup RENDERED!', {
    walletAddress,
    currentBalance,
    requiredAmount
  });

  // Prevent background scrolling when popup is open
  useEffect(() => {
    console.log('🚨 Popup mounted - preventing body scroll');
    document.body.style.overflow = 'hidden';
    return () => {
      console.log('🚨 Popup unmounted - restoring body scroll');
      document.body.style.overflow = 'unset';
    };
  }, []);

  // Handle ESC key to close popup
  useEffect(() => {
    const handleEsc = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        console.log('🚨 ESC pressed - closing popup');
        onClose();
      }
    };
    document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, [onClose]);

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(walletAddress);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
      console.log('📋 Address copied to clipboard');
    } catch (err) {
      console.error('Failed to copy address:', err);
      // Fallback for older browsers
      const textArea = document.createElement('textarea');
      textArea.value = walletAddress;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
      console.log('📋 Address copied to clipboard (fallback)');
    }
  };

  const handleRefresh = async () => {
    console.log('🔄 Refreshing balance...');
    setIsRefreshing(true);
    await onRefresh();
    setIsRefreshing(false);
    console.log('✅ Balance refresh complete');
  };

  const handleClose = () => {
    console.log('❌ Closing popup manually');
    onClose();
  };

  const explorerUrl = `${MONAD_TESTNET.blockExplorers.default.url}/address/${walletAddress}`;

  return (
    <div className="insufficient-funds-popup" onClick={handleClose}>
      <div className="insufficient-funds-popup-box" onClick={(e) => e.stopPropagation()}>
        <div className="insufficient-funds-popup-main">
          {/* Close button */}
          <button 
            className="insufficient-funds-close-btn" 
            onClick={handleClose}
          >
            ✕
          </button>
          
          {/* Title */}
          <div className="insufficient-funds-title">💰 Insufficient Funds</div>
          
          {/* Balance info */}
          <div className="balance-info">
            <div className="balance-row">
              <span>Current Balance:</span>
              <span className="balance-amount">{parseFloat(currentBalance).toFixed(4)} MON</span>
            </div>
            <div className="balance-row">
              <span>Required Amount:</span>
              <span className="required-amount">{requiredAmount}</span>
            </div>
          </div>
          
          {/* Instructions */}
          <div className="funding-instructions">
            <h3>How to Fund Your Wallet:</h3>
            <ol>
              <li>Copy your wallet address below</li>
              <li>Send testnet MON from another wallet or faucet</li>
              <li>Click "Check Balance" to refresh</li>
            </ol>
          </div>
          
          {/* Wallet Address */}
          <div className="wallet-address-section">
            <label>Your Wallet Address:</label>
            <div className="wallet-address-container">
              <div className="wallet-address-display">
                {walletAddress}
              </div>
              <button 
                className={`copy-btn ${copied ? 'copied' : ''}`}
                onClick={copyToClipboard}
              >
                {copied ? '✓ Copied!' : '📋 Copy'}
              </button>
            </div>
          </div>
          
          {/* Explorer link */}
          <div className="explorer-link-section">
            <a 
              href={explorerUrl} 
              target="_blank" 
              rel="noopener noreferrer"
              className="explorer-link"
            >
              🔗 View Wallet on Monad Explorer
            </a>
          </div>
          
          {/* Action buttons */}
          <div className="popup-actions">
            <button 
              className={`refresh-btn ${isRefreshing ? 'refreshing' : ''}`}
              onClick={handleRefresh}
              disabled={isRefreshing}
            >
              {isRefreshing ? '🔄 Checking...' : '🔄 Check Balance'}
            </button>
            <button className="close-btn" onClick={handleClose}>
              Close
            </button>
          </div>
          
          {/* Help text */}
          <div className="help-text">
            Need testnet MON? Try searching for "Monad testnet faucet" or ask in the Monad Discord community.
          </div>
        </div>
      </div>
    </div>
  );
};

export default InsufficientFundsPopup;