# zk-lending [WIP]

## TODO

### ZK part

- Support the other way round, instead of only lending ETH, Borrow USD
- Optimize check if our position is already liquidated or not

### Non-ZK

- Frontend/Contract enforces us to only select a certain amount of either borrowing or lending asset sucht that liquidation price exists in one of the liqudation bucket at that time. Logic can be found in HELPER FUNCTIONS and in test_main()
- Include Commitment into Merkle Tree & Update Tree, again can see in test_main()
- Publish Nullifer & Check for double spend nullifier Need to be done in smart contract.
- Make sure that the amount money we submit on smart contract the same as its corresponding witness
- Keeping track of all liquidated buckets, can see in test_main()

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

1. Initiate Note

- Generate MyNote

2. Borrow

- Verify note inclusion in the Merkle tree.
- Check liquidation status.
- Correctly update lend amount from interest rate
- Correctly update borrow amount from interest rate & additional borrow
- Correctly update will_liq_price from LTV constraint
- Update time, nullifer, and nonce

3. Lend

- Verify note inclusion in the Merkle tree.
- Check liquidation status.
- Correctly update lend amount from interest rate & additional lend
- Correctly update borrow amount from interest rate
- Correctly update will_liq_price from LTV constraint
- Update time, nullifer, and nonce

4. Repay

- Verify note inclusion in the Merkle tree.
- Check liquidation status.
- Correctly update lend amount from interest rate
- Correctly update borrow amount from interest rate & repay borrow
- Make sure we dont over-repay the debt
- Correctly update will_liq_price from LTV constraint
- Update time, nullifer, and nonce

5. Withdraw

- Verify note inclusion in the Merkle tree.
- Check liquidation status.
- Correctly update lend amount from interest rate & withdraw lend
- Correctly update borrow amount from interest rate
- Make sure we dont over-withdraw the lending
- Correctly update will_liq_price from LTV constraint
- Update time, nullifer, and nonce
