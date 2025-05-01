# zk-lending [WIP]

## TODO

### ZK part

- Support the other way round, instead of only lending ETH, Borrow USD
- Optimize check if our position is already liquidated or not
- Add functions: deposit, withdraw, repay

### Non-ZK

- Frontend/Contract enforces us to only select a certain amount of either borrowing or lending asset sucht that liquidation price exists in one of the liqudation bucket at that time
- Include Commitment into Merkle Tree & Update Tree
- Publish Nullifer & Check for double spend nullifier
- Make sure that the amount money we submit on smart contract the same as its corresponding witness
- Keeping track of all liquidated buckets.

## What we have now

Tracking: Each user has a MyNote (commitment) with:

- Lend amount (lend_amt)
- Borrow amount (borrow_amt)
- Liquidation price (will_liq_price)
- Last updated time (timestamp)
- Nullifier & nonce (privacy + uniqueness)

### Main Algorithm (used in most actions)

1. Check Liquidation Status

- Check if our note falls in liquidated bucket. (Note that due to lending/borrowing interest rate), the liquidated price of each bucket will always move up, we hence check if our position moves up to be in the liquidated bucket at certain time or not

2. Verify Merkle Tree Note inclusion

3. Enforce LTV Constraint

### Main Functions

1. Initial Deposit

- Generate MyNote

2. Borrow

- Check liquidation status.
- Verify note inclusion in the Merkle tree.
- Update note (as a new one)
