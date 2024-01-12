# brrETH

brrETH is a yield-bearing ETH derivative built on Compound III's Base WETH market.

brrETH is easy to use and understand: deposit ETH, receive brrETH. Your brrETH can be redeemed at any time for the amount of ETH you originally deposited, plus any interest accrued.

There are no deposit or withdrawal fees, but we may take a reward fee (the amount varies, depending on the specific deployment).

NOTE: Compound III rounds down token balances during transfers, which may result in a ~1-2 wei (an extremely small amount) discrepancy when depositing ETH/cWETH or redeeming brrETH. This is a known issue, and has been communicated to the Compound Labs team, but is ultimately out of our control.

## Installation

The steps below assume that the code repo has already been cloned and the reader has navigated to the root of the project directory.

1. Install Foundry: https://book.getfoundry.sh/.
2. Run `forge i` to install project dependencies.
3. Run `forge test --rpc-url https://mainnet.base.org` to compile contracts and run tests.

## Contract Deployments

| Chain ID         | Chain             | Contract | Contract Address                           | Deployment Tx |
| :--------------- | :---------------- | :----------------------------------------- | :----------------------------------------- | :------------ |
| 8453                | Base  | BrrETH.sol | 0xf1288441F094d0D73bcA4E57dDd07829B34de681 | [BaseScan](https://basescan.org/tx/0x290db9109fe03745ffeba27eba0df25695012eadb427799f14155f9e2be6f55e) |
| 8453                | Base  | BrrETHRedeemHelper.sol | 0x787417F293260E9800327ABFeE99874B108a6c5b | [BaseScan](https://basescan.org/tx/0xd959d51d62f67805580899b5b12437916227463e155ed31d8a7c0ae1270959be) |
