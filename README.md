# eth

## Installation

1. Install Foundry: https://book.getfoundry.sh/.
2. Run `forge i` to install project dependencies.
3. Run `forge test --rpc-url https://mainnet.base.org` to compile contracts and run tests.

## Features

- Deposit: Users can deposit ETH, WETH, or cWETH in return for a rebasing, liquid-staked ETH token that accrues interest (brrETH).
- Withdraw: Users can withdraw their principal, at any time, in the form of WETH.
- Harvest: Users can trigger a brrETH harvest which results in the Compound rewards being claimed and converted into more ETH.

## Features: Deposit

Deposit ETH
- Harvest (accrues rewards to existing token holders and mitigates "gaming").
- Get cWETH balance (allows us to get the exact amount of new cWETH received from the depositor).
- Deposit ETH for WETH.
- Supply WETH to Comet for cWETH.
- Get assets (the difference between the new cWETH balance and the previous)
- Calculate shares and mint brrETH for the depositor.

Deposit WETH
- Harvest.
- Get cWETH balance.
- Supply WETH to Comet for cWETH.
- Get assets.
- Calculate shares and mint brrETH for the depositor.

Deposit cWETH
- Harvest.
- Normal deposit flow.

## Features: Withdraw

Withdraw WETH
- Harvest.
- Calculate shares and burn brrETH for the withdrawer.
  - `msg.sender` is the one who has their brrETH burned.
- Withdraw WETH from Comet to the withdrawer.

## Features: Harvest

Harvest
- Accrue and claim rewards from Comet Rewards (e.g. COMP).
- Swap the rewards for WETH.
- Supply WETH to Comet for cWETH without minting shares.

## Reference Material

- [Compound Docs](https://docs.compound.finance/)
- [Building on Compound III](https://www.youtube.com/watch?v=OjYe_5sVcTM)
- External contracts
  - [WETH](basescan.org/address/0x4200000000000000000000000000000000000006)
  - [cWETH](https://basescan.org/address/0x46e6b214b524310239732D51387075E0e70970bf)
  - [cWETH Rewards](https://basescan.org/address/0x123964802e6ababbe1bc9547d72ef1b69b00a6b1)
