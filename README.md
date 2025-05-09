# Noiri: Private Money Market Protocol

Noiri is a native, privacy-preserving money market protocol on Ethereum L1, powered by Noir. It enables users to perform all core banking operations — lend, borrow, repay, and withdraw — with interest accurately accounted for, while ensuring each action is disjointed, revealing no complete view of a user’s overall position.
Most importantly, liquidations are triggered publicly, but who gets liquidated and how much remains fully private.

## Why Private Money Market

Lending/Borrowing is HUGE

- Aave V3 on Ethereum L1 alone handles [$23.6B+](https://www.galaxy.com/insights/research/the-state-of-crypto-lending/) in deposits (31 Mar 25)
- Borrowing and leverage are core financial primitives in DeFi

But Everything is PUBLIC

- On Ethereum L1, your full position is exposed:
  - How much you lent or borrowed
  - Which assets
  - Liquidation thresholds and timing

## Core Challenges

Shared State Limits Logic

- Shielded pools like Aztec Connect aggregate user funds into a single shared state
- Only support group actions like lending, staking, swapping.
- No support for individualized borrowing, interest accrual, or repayments

Stateless Model Breaks Liquidation

- When lending and borrowing are disentangled, there’s not enough information for smart contract to liquidate the position

Increased Trust Assumptions

- Trusted Execution Environments (TEE)
- Sequencers, relayers, or coordinators in Layer 2

## How Noiri Works

### Core Ideas

Public Flow, Private Position

- Assets move around publicly, but the real user's positions are private!
- Liquidations are triggered publicly, but who gets liquidated and how much remains private
- Banking operations (lend, borrow, repay, withdraw) are executed publicly, but each action is disjointed, revealing no complete view of a user’s position

Risk Preference Buckets

- Each buckets is defined by a liquidation price that once crossed, all lending amounts in that bucket are liquidated
- When updating their position, users select their preferred liquidation price, then Noiri computes the corresponding fund movement for each banking operation.

Unified Private State Transition Circuit

- A single zkp circuit handles all banking operations constraints
- Enforce other key constraints: LTV, Interest Accrual, Liquidation Checks, and Inclusion Proof

### Information Architecture

![App Screenshot](./architecture.png)

### Closer Look at our Zringotts circuit v.0

Verify Note Validity

- Merkle proof ensures that the user is authorized to modify the position

State Transition Logic

- Update positions based on banking operation type, previous balance, and interest rate
- Interest Accrual: Updated on every state change even if the token amount remains unchanged
- Liquidation Settlement: Claim = lending amount x liquidation price - borrowed

Requirement check

- LTV threshold: Enforce safe collateralization
- Correct Note construction: Ensure resulting note reflects a valid & updated position

Current Limitation

- Fixed lending & borrowing interest rate
- Siloed Market: Only support one pair of asset
