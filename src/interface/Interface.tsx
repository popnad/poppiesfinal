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

import useGame from '../stores/store';
import { useBlockchainGame } from '../hooks/useBlockchainGame';
import Modal from './modal/Modal';
import HelpButton from './helpButton/HelpButton';
import OutcomePopup from './outcomePopup/OutcomePopup';
import WalletWidget from '../components/WalletWidget';
import InsufficientFundsPopup from '../components/InsufficientFundsPopup';
import './style.css';

const Interface = () => {
  const modal = useGame((state) => state.modal);
  const outcomePopup = useGame((state) => state.outcomePopup);
  const coins = useGame((state) => state.coins);
  const spins = useGame((state) => state.spins);
  
  // Get blockchain state for display
  const { 
    monBalance, 
    authenticated, 
    walletAddress,
    showInsufficientFunds,
    insufficientFundsData,
    handleInsufficientFundsClose,
    handleInsufficientFundsRefresh
  } = useBlockchainGame();

  console.log('🎯 Interface Debug - DETAILED:', {
    showInsufficientFunds,
    insufficientFundsData,
    walletAddress,
    authenticated,
    shouldShowPopup: showInsufficientFunds && insufficientFundsData && walletAddress,
    popupComponent: showInsufficientFunds && insufficientFundsData && walletAddress ? 'SHOULD RENDER' : 'NOT RENDERING'
  });

  return (
    <>
      {/* Wallet Widget - Top Right */}
      <WalletWidget />

      {/* Help Button */}
      <HelpButton />

      {/* Modal */}
      {modal && <Modal />}

      {/* Insufficient Funds Popup - HIGHEST PRIORITY - ALWAYS RENDER WHEN CONDITIONS MET */}
      {showInsufficientFunds && insufficientFundsData && walletAddress && (
        <>
          {console.log('🚨 RENDERING INSUFFICIENT FUNDS POPUP!', {
            walletAddress,
            currentBalance: insufficientFundsData.currentBalance,
            requiredAmount: insufficientFundsData.requiredAmount
          })}
          <InsufficientFundsPopup
            walletAddress={walletAddress}
            currentBalance={insufficientFundsData.currentBalance}
            requiredAmount={insufficientFundsData.requiredAmount}
            onRefresh={handleInsufficientFundsRefresh}
            onClose={handleInsufficientFundsClose}
          />
        </>
      )}

      {/* Debug info for popup state */}
      {showInsufficientFunds && (
        <div style={{
          position: 'fixed',
          top: '100px',
          left: '10px',
          background: 'red',
          color: 'white',
          padding: '10px',
          zIndex: 9999,
          fontSize: '12px',
          borderRadius: '5px'
        }}>
          🚨 POPUP STATE: {showInsufficientFunds ? 'TRUE' : 'FALSE'}<br/>
          📊 DATA: {insufficientFundsData ? 'EXISTS' : 'NULL'}<br/>
          👤 WALLET: {walletAddress ? 'EXISTS' : 'NULL'}
        </div>
      )}

      {/* Outcome Popup */}
      {outcomePopup && (
        <OutcomePopup
          combination={outcomePopup.combination}
          monReward={outcomePopup.monReward}
          extraSpins={outcomePopup.extraSpins}
          nftMinted={outcomePopup.nftMinted}
          txHash={outcomePopup.txHash}
        />
      )}

      {/* Logo */}
      <a
        href="https://github.com/michaelkolesidis/cherry-charm"
        target="_blank"
      >
        <img className="logo" src="./images/logo.png" alt="" />
      </a>

      <div className="interface">
        {/* Coins - Show blockchain balance if authenticated, otherwise local coins */}
        <div className="coins-section">
          <div className="coins-number">
            {authenticated ? parseFloat(monBalance || '0').toFixed(2) : coins}
          </div>
          <img className="coins-image" src="./images/coin.png" />
        </div>

        {/* Spins */}
        <div className="spins-section">
          <div className="spins-number">{spins}</div>
        </div>
      </div>
    </>
  );
};

export default Interface;