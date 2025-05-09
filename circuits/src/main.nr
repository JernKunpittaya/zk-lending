/*
 * Zringotts Circuit - zk lending operation
 * This circuit is an all in one zk lending market state transition circuit.
 * Author: jernkun, yoyoismee, yoisha
*/

use dep::std;

// ==== Global config ==== (percentage-based)
global LTV_THRESHOLD: u64 = 50; //
global LEND_INTEREST_RATE: u64 = 3; // annual rate (3%)
global BORROW_INTEREST_RATE: u64 = 10; // annual rate (10%)
global ACCEPTABLE_PERCENT: u64 = 1;

// Assume price is integer
struct Liquidated {
    liq_price: u64, // in smallest unit as integer
    timestamp: u64,
}

struct MyNote {
    lend_amt: u64, // in smallest unit (scaled, e.g., x10^4)
    borrow_amt: u64, // in smallest unit (scaled, e.g., x10^4)
    will_liq_price: u64, // in smallest unit as integer
    timestamp: u64,
    nullifier: Field,
    nonce: Field,
}

fn simple_hash(left: Field, right: Field) -> Field {
    std::hash::poseidon2::Poseidon2::hash([left, right], 2)
}

fn hash_my_note(my_note: MyNote) -> Field {
    std::hash::poseidon2::Poseidon2::hash(
        [
            my_note.lend_amt as Field,
            my_note.borrow_amt as Field,
            my_note.will_liq_price as Field,
            my_note.timestamp as Field,
            my_note.nullifier,
            my_note.nonce,
        ],
        6,
    )
}

// ====== CONSTRAINT ================
// assert if LTV condition is satisfied
fn assert_ltv(my_note: MyNote) {
    assert(my_note.borrow_amt * 100 <= LTV_THRESHOLD * my_note.lend_amt * my_note.will_liq_price);
}

fn abs_diff(x: u64, y: u64) -> u64 {
    if x >= y {
        x - y
    } else {
        y - x
    }
}

// Check if two values are within a percentage range
fn is_within_percentage(x: u64, y: u64, percent: u64) -> u8 {
    let diff = abs_diff(x, y) * 100;
    let allowed_diff = percent * y;
    if diff <= allowed_diff {
        1
    } else {
        0
    }
}

// Check if our will_liq_price is actually liquidated or not, accounting for lend & borrow interest
fn is_myposition_liquidated(my_price: u64, liq_price: u64, my_time: u64, liq_time: u64) -> u8 {
    if liq_time < my_time {
        0
    } else {
        let one_year_seconds = 365 * 24 * 60 * 60;
        let time_diff = liq_time - my_time;

        let borrow_factor = one_year_seconds + BORROW_INTEREST_RATE * time_diff;
        let lend_factor = one_year_seconds + LEND_INTEREST_RATE * time_diff;

        let my_adjusted_price = borrow_factor * my_price;
        let liq_adjusted_price = lend_factor * liq_price;

        is_within_percentage(my_adjusted_price, liq_adjusted_price, ACCEPTABLE_PERCENT)
    }
}

fn assert_update_amt(
    prev_amt: u64,
    prev_timestamp: u64,
    curr_amt: u64,
    curr_timestamp: u64,
    interest_rate: u64,
) {
    let one_year_seconds = 365 * 24 * 60 * 60;
    let time_diff = curr_timestamp - prev_timestamp;

    let projected_amt = (one_year_seconds + interest_rate * time_diff) * prev_amt;
    let actual_amt = one_year_seconds * curr_amt;

    assert(is_within_percentage(projected_amt, actual_amt, ACCEPTABLE_PERCENT) == 1);
}

// check if my position is liquidated
fn is_my_pos_liquidated(my_note: MyNote, liquidated_array: [Liquidated; 3]) -> u8 {
    let mut is_liquidated: u8 = 0;

    for i in 0..3 {
        let check = is_myposition_liquidated(
            my_note.will_liq_price,
            liquidated_array[i].liq_price,
            my_note.timestamp,
            liquidated_array[i].timestamp,
        );
        is_liquidated += check;
    }
    if is_liquidated > 0 {
        1
    } else {
        0
    }
}

// assert that my position not liquidated
fn assert_non_liquidated(my_note: MyNote, liquidated_array: [Liquidated; 3]) {
    assert(is_my_pos_liquidated(my_note, liquidated_array) == 0);
}

// assert that my position gets liquidated
fn assert_liquidated(my_note: MyNote, liquidated_array: [Liquidated; 3]) {
    assert(is_my_pos_liquidated(my_note, liquidated_array) == 1);
}

fn process_path_hash(leaf: Field, index: u32, another_leaf: Field) -> Field {
    // if index is even, then leaf is left child
    // if index is odd, then leaf is right child
    if index % 2 == 0 {
        simple_hash(leaf, another_leaf)
    } else {
        simple_hash(another_leaf, leaf)
    }
}

fn assert_inclusion_proof(leaf: Field, index: u32, hash_path: [Field; 3], root: Field) {
    let mut calculated_hash = leaf;
    let mut calculated_index = index;
    for i in 0..3 {
        calculated_hash = process_path_hash(calculated_hash, calculated_index, hash_path[i]);
        calculated_index = calculated_index / 2;
    }

    assert(calculated_hash == root);
}

// ============ zk-lending OPERATION CONSTRAINT =============

// if no borrow when initiating note, set borrow_amt = 0, and will_liq_price = 0
fn init_note(
    lend_amt: u64,
    borrow_amt: u64,
    will_liq_price: u64,
    timestamp: u64,
    nullifier: Field,
    nonce: Field,
) -> MyNote {
    let my_note: MyNote =
        MyNote { lend_amt, borrow_amt, will_liq_price, timestamp, nullifier, nonce };
    assert_ltv(my_note);
    my_note
}

fn borrow(
    prev_note: MyNote,
    prev_hash: Field,
    prev_index: u32,
    prev_hash_path: [Field; 3],
    root: Field,
    liquidated_array: [Liquidated; 3],
    new_note: MyNote,
    additional_borrow_amt: u64,
) -> Field {
    assert(hash_my_note(prev_note) == prev_hash);
    assert_inclusion_proof(prev_hash, prev_index, prev_hash_path, root);
    assert_non_liquidated(prev_note, liquidated_array);

    // assert updated lending amount
    assert_update_amt(
        prev_note.lend_amt,
        prev_note.timestamp,
        new_note.lend_amt,
        new_note.timestamp,
        LEND_INTEREST_RATE,
    );

    // assert updated borrowing amount (before borrowing more)
    assert_update_amt(
        prev_note.borrow_amt,
        prev_note.timestamp,
        new_note.borrow_amt - additional_borrow_amt,
        new_note.timestamp,
        BORROW_INTEREST_RATE,
    );

    assert_ltv(new_note);
    hash_my_note(new_note)
}

fn repay(
    prev_note: MyNote,
    prev_hash: Field,
    prev_index: u32,
    prev_hash_path: [Field; 3],
    root: Field,
    liquidated_array: [Liquidated; 3],
    new_note: MyNote,
    repay_borrow_amt: u64,
) -> Field {
    assert(hash_my_note(prev_note) == prev_hash);
    assert_inclusion_proof(prev_hash, prev_index, prev_hash_path, root);
    assert_non_liquidated(prev_note, liquidated_array);

    // assert updated lending amount
    assert_update_amt(
        prev_note.lend_amt,
        prev_note.timestamp,
        new_note.lend_amt,
        new_note.timestamp,
        LEND_INTEREST_RATE,
    );

    assert(
        repay_borrow_amt
            <= update_amt(
                prev_note.borrow_amt,
                prev_note.timestamp,
                new_note.timestamp,
                BORROW_INTEREST_RATE,
            ),
    );

    // assert updated borrowing amount (before borrowing more)
    assert_update_amt(
        prev_note.borrow_amt,
        prev_note.timestamp,
        new_note.borrow_amt + repay_borrow_amt,
        new_note.timestamp,
        BORROW_INTEREST_RATE,
    );

    assert_ltv(new_note);
    hash_my_note(new_note)
}

fn lend(
    prev_note: MyNote,
    prev_hash: Field,
    prev_index: u32,
    prev_hash_path: [Field; 3],
    root: Field,
    liquidated_array: [Liquidated; 3],
    new_note: MyNote,
    additional_deposit_amt: u64,
) -> Field {
    assert(hash_my_note(prev_note) == prev_hash);
    assert_inclusion_proof(prev_hash, prev_index, prev_hash_path, root);
    assert_non_liquidated(prev_note, liquidated_array);

    // assert updated lending amount (before lending/depositing more)
    assert_update_amt(
        prev_note.lend_amt,
        prev_note.timestamp,
        new_note.lend_amt - additional_deposit_amt,
        new_note.timestamp,
        LEND_INTEREST_RATE,
    );

    // assert updated borrowing amount
    assert_update_amt(
        prev_note.borrow_amt,
        prev_note.timestamp,
        new_note.borrow_amt,
        new_note.timestamp,
        BORROW_INTEREST_RATE,
    );

    assert_ltv(new_note);
    hash_my_note(new_note)
}

fn withdraw(
    prev_note: MyNote,
    prev_hash: Field,
    prev_index: u32,
    prev_hash_path: [Field; 3],
    root: Field,
    liquidated_array: [Liquidated; 3],
    new_note: MyNote,
    withdraw_lend_amt: u64,
) -> Field {
    assert(hash_my_note(prev_note) == prev_hash);
    assert_inclusion_proof(prev_hash, prev_index, prev_hash_path, root);
    assert_non_liquidated(prev_note, liquidated_array);

    assert(
        withdraw_lend_amt
            <= update_amt(
                prev_note.lend_amt,
                prev_note.timestamp,
                new_note.timestamp,
                LEND_INTEREST_RATE,
            ),
    );

    // assert updated lending amount (before lending/depositing more)
    assert_update_amt(
        prev_note.lend_amt,
        prev_note.timestamp,
        new_note.lend_amt + withdraw_lend_amt,
        new_note.timestamp,
        LEND_INTEREST_RATE,
    );

    // assert updated borrowing amount
    assert_update_amt(
        prev_note.borrow_amt,
        prev_note.timestamp,
        new_note.borrow_amt,
        new_note.timestamp,
        BORROW_INTEREST_RATE,
    );

    assert_ltv(new_note);
    hash_my_note(new_note)
}

// =============== HELPER FUNCTIONS ========================

fn construct_merkle_tree(leaf_array: [Field; 8]) -> [Field; 7] {
    let mut lv1_nodes: [Field; 4] = [0; 4];
    for i in 0..4 {
        lv1_nodes[i] = simple_hash(leaf_array[2 * i], leaf_array[2 * i + 1]);
    }
    let mut lv2_nodes: [Field; 2] = [0; 2];
    for i in 0..2 {
        lv2_nodes[i] = simple_hash(lv1_nodes[2 * i], lv1_nodes[2 * i + 1]);
    }
    let root = simple_hash(lv2_nodes[0], lv2_nodes[1]);
    [lv1_nodes[0], lv1_nodes[1], lv1_nodes[2], lv1_nodes[3], lv2_nodes[0], lv2_nodes[1], root]
}

fn update_amt(prev_amt: u64, prev_timestamp: u64, curr_timestamp: u64, interest_rate: u64) -> u64 {
    let one_year_seconds = 365 * 24 * 60 * 60;
    let time_diff = curr_timestamp - prev_timestamp;

    (one_year_seconds + interest_rate * time_diff) * prev_amt / one_year_seconds
}

fn update_lend_amt_new_liq_price(will_liq_price: u64, borrow_amt: u64) -> u64 {
    borrow_amt * 100 / (will_liq_price * LTV_THRESHOLD) + 1
}

fn update_borrow_amt_new_liq_price(will_liq_price: u64, lend_amt: u64) -> u64 {
    will_liq_price * LTV_THRESHOLD * lend_amt / 100
}

fn global_will_liq_price(initial_will_liq_price: u64, timestamp: u64) -> u64 {
    let one_year_seconds = 365 * 24 * 60 * 60;
    let time_diff = timestamp - 0;

    let borrow_factor = one_year_seconds + BORROW_INTEREST_RATE * time_diff;
    let lend_factor = one_year_seconds + LEND_INTEREST_RATE * time_diff;

    borrow_factor * initial_will_liq_price / lend_factor
}

// Zringotts Circuit - all in one zk banking operation 
// the name have nothing to do with goblins, wizzard, or british writers. (don't sue us)
// 1. init note - if old is empty init note with no check
// 2. if liquidated, force sell all assets and credit it as borrow asset
// 3. lend, borrow, repay, withdraw - attempt to update the note and check aginst constraints
fn main(
    new_note: MyNote,
    new_note_hash: pub Field,
    new_will_liq_price: pub u64,
    new_timestamp: pub u64,
    prev_note: MyNote,
    prev_hash: Field,
    prev_nullifier: Field,
    prev_index: u32,
    prev_hash_path: pub [Field; 3],
    root: pub Field,
    liquidated_array: pub [Liquidated; 3],
    lend_token_out: pub u64,
    borrow_token_out: pub u64,
    lend_token_in: pub u64,
    borrow_token_in: pub u64,
) {
    // return the new note hash
    assert(new_will_liq_price == new_note.will_liq_price);

    // assert that token in and out are mutually exclusive
    assert(lend_token_in * lend_token_out == 0);
    assert(borrow_token_in * borrow_token_out == 0);

    // if old is empty no inclusion proof needed.
    // note: lend_amt, borrow_amt, will_liq_price = 0 mean empty note
    if (prev_note.lend_amt + prev_note.borrow_amt + prev_note.will_liq_price) > 0 {
        // validate the old note
        assert(prev_nullifier == prev_note.nullifier);
        assert(hash_my_note(prev_note) == prev_hash);
        assert_inclusion_proof(prev_hash, prev_index, prev_hash_path, root);
    }

    // if the old note is liquidated, settle the note
    if is_my_pos_liquidated(prev_note, liquidated_array) == 1 {
        // calculate asset left after liquidation. interest is forfeited in this case.
        // give asset back to the user and reset the note
        assert_liquidated(prev_note, liquidated_array);
        let lend_asset_left_eqv = prev_note.lend_amt * prev_note.will_liq_price;
        let borrow_amt = update_amt(
            prev_note.borrow_amt,
            prev_note.timestamp,
            new_timestamp,
            BORROW_INTEREST_RATE,
        );
        let borrow_asset_left_eqv = lend_asset_left_eqv - borrow_amt;
        assert(borrow_token_out <= borrow_asset_left_eqv);
        assert(borrow_token_in == 0);
        assert(lend_token_out == 0);
        assert(lend_token_in == 0);

        assert(new_note.lend_amt == 0);
        assert(new_note.borrow_amt == 0);
        assert(new_note.will_liq_price == 0);
        assert(new_note.timestamp == new_timestamp);

        assert(new_note_hash == hash_my_note(new_note)); // create new empty note
    } else {
        // assert that the old note is not liquidated
        assert_non_liquidated(prev_note, liquidated_array);

        let new_lend_amt = update_amt(
            prev_note.lend_amt,
            prev_note.timestamp,
            new_timestamp,
            LEND_INTEREST_RATE,
        )
            + lend_token_in
            - lend_token_out;

        assert(new_lend_amt >= new_note.lend_amt);   // check for note allow for same or lower lend_amt

        let new_borrow_amt = update_amt(
            prev_note.borrow_amt,
            prev_note.timestamp,
            new_timestamp,
            BORROW_INTEREST_RATE,
        )
            + borrow_token_in
            - borrow_token_out;
        assert(new_borrow_amt <= new_note.borrow_amt); // check for note allow for same or more borrow_amt


        assert_ltv(new_note);
        // assert that the new note is not liquidated
        assert_non_liquidated(new_note, liquidated_array);
        assert(new_note_hash == hash_my_note(new_note));
    }
    // return 0 as placeholder
}

#[test]
fn test_main_real(){


    // create empty tree
    let zero_leaf = 0 as Field;
    let mut merkle_leaves: [Field; 8] = (
        [
            zero_leaf,
            zero_leaf,
            zero_leaf,
            zero_leaf,
            zero_leaf,
            zero_leaf,
            zero_leaf,
            zero_leaf,
        ]
    );
    let mut merkle_tree = construct_merkle_tree(merkle_leaves);
    let mut merkle_root = merkle_tree[6];
    let mut liquidated_array: [Liquidated; 3] = [
        Liquidated { liq_price: 1500, timestamp: 0 },
        Liquidated { liq_price: 1600, timestamp: 0 },
        Liquidated { liq_price: 1700, timestamp: 0 },
    ];

    // a, b deposit and borrow right away
    let a_init_lend_amt = 500; // already scale by (10^4)
    let a_init_will_liq_price = 2800;
    let timestamp_0 = 123;
    let a_init_borrow_amt = 1500;
    let empty_note = MyNote {
        lend_amt: 0,
        borrow_amt: 0,
        will_liq_price: 0,
        timestamp: 0,
        nullifier: 0 as Field,
        nonce: 0 as Field,
    };
    let expected_new_note = MyNote {
        lend_amt: a_init_lend_amt,
        borrow_amt: a_init_borrow_amt,
        will_liq_price: a_init_will_liq_price,
        timestamp: timestamp_0,
        nullifier: 112 as Field,
        nonce: 13 as Field,
    };
    let expected_new_note_hash = hash_my_note(expected_new_note);
    main(
        expected_new_note,
        expected_new_note_hash,
        a_init_will_liq_price,
        timestamp_0,
        empty_note,
        zero_leaf,
        zero_leaf,
        0,
        [zero_leaf, zero_leaf, zero_leaf],
        merkle_root,
        liquidated_array,
        0,
        0,
        a_init_lend_amt,
        a_init_borrow_amt,
    );

    // test borrow
    let last_note_hash = expected_new_note_hash;
    let last_note_index = 0;
    let merkle_leaves = [
        last_note_hash,
        zero_leaf,
        zero_leaf,
        zero_leaf,
        zero_leaf,
        zero_leaf,
        zero_leaf,
        zero_leaf,
    ];
    merkle_tree = construct_merkle_tree(merkle_leaves);
    merkle_root = merkle_tree[6];
    let last_note_hash_path = [zero_leaf, merkle_tree[1], merkle_tree[5]];
    

    let last_note = expected_new_note;

    let to_borrow_amt = 500;
    let expected_new_borrow_amt = a_init_borrow_amt + to_borrow_amt;
    let expected_new_note = MyNote {
        lend_amt: a_init_lend_amt,
        borrow_amt: expected_new_borrow_amt,
        will_liq_price: a_init_will_liq_price,
        timestamp: timestamp_0,
        nullifier: 114 as Field,
        nonce: 19 as Field,
    };
    let expected_new_note_hash = hash_my_note(expected_new_note);
    let old_expected_new_note_hash_path = [zero_leaf, merkle_tree[1], merkle_tree[5]];
    
    assert_inclusion_proof(last_note_hash, 0, old_expected_new_note_hash_path, merkle_root);

    main(
        expected_new_note,
        expected_new_note_hash,
        a_init_will_liq_price,
        timestamp_0,
        last_note,
        last_note_hash,
        last_note.nullifier,
        0,
        old_expected_new_note_hash_path,
        merkle_root,
        liquidated_array,
        0,
        to_borrow_amt,
        0,
        0,
    );



    


}

#[test]
fn test_main() {
    // Time = 0, current ETH price = 3000,
    // there exists buckets at liquidation price 2800, 2600, 2400, 2200
 

    let zero_leaf = 0 as Field;
    let mut merkle_leaves: [Field; 8] = (
        [
            1234 as Field,
            542 as Field,
            zero_leaf,
            zero_leaf,
            zero_leaf,
            zero_leaf,
            zero_leaf,
            zero_leaf,
        ]
    );
    let mut liquidated_array: [Liquidated; 3] = [
        Liquidated { liq_price: 0, timestamp: 0 },
        Liquidated { liq_price: 0, timestamp: 0 },
        Liquidated { liq_price: 0, timestamp: 0 },
    ];
    // a, b deposit and borrow right away
    let a_init_lend_amt = 50000; // already scale by (10^4)
    let a_init_will_liq_price = 2800;
    let a_init_borrow_amt = update_borrow_amt_new_liq_price(a_init_will_liq_price, a_init_lend_amt);
    let a_init_note = init_note(
        a_init_lend_amt,
        a_init_borrow_amt,
        a_init_will_liq_price,
        0,
        112 as Field,
        13 as Field,
    );

    let b_init_lend_amt = 20000; // already scale by (10^4)
    let b_init_will_liq_price = 2600;
    let b_init_borrow_amt = update_borrow_amt_new_liq_price(b_init_will_liq_price, b_init_lend_amt);
    let b_init_note = init_note(
        b_init_lend_amt,
        b_init_borrow_amt,
        b_init_will_liq_price,
        0,
        132 as Field,
        156 as Field,
    );

    let a_init_note_hash = hash_my_note(a_init_note);
    let a_init_note_index = 2;
    merkle_leaves[a_init_note_index] = a_init_note_hash;
    let b_init_note_hash = hash_my_note(b_init_note);
    let b_init_note_index = 3;
    merkle_leaves[b_init_note_index] = b_init_note_hash;

    // T = 4 hrs, liquidate 2800 ish, then bounce back 2900
    let timestamp_4_hrs = 4 * 60 * 60;
    liquidated_array[0] = Liquidated {
        liq_price: global_will_liq_price(2800, timestamp_4_hrs),
        timestamp: timestamp_4_hrs,
    };

    // T = 12 hrs, liquidate 2800 ish again (since someone initiate position in this bucket)
    let timestamp_12_hrs = 12 * 60 * 60;
    liquidated_array[1] = Liquidated {
        liq_price: global_will_liq_price(2800, timestamp_12_hrs),
        timestamp: timestamp_12_hrs,
    };

    // a's position is gone
    assert_liquidated(a_init_note, liquidated_array);

    // T = 32 hrs
    // b lend more, making will_liq_price drop to around 2200
    let timestamp_32_hrs = 32 * 60 * 60;
    let merkle_tree = construct_merkle_tree(merkle_leaves);
    let b_init_note_hash_path = [merkle_leaves[2], merkle_tree[0], merkle_tree[5]];
    let merkle_root = merkle_tree[6];

    let b_2200_will_liq_price = global_will_liq_price(2200, timestamp_32_hrs);
    let b_2200_borrow_amt = update_amt(
        b_init_note.borrow_amt,
        b_init_note.timestamp,
        timestamp_32_hrs,
        BORROW_INTEREST_RATE,
    );

    let b_2200_lend_amt = update_lend_amt_new_liq_price(b_2200_will_liq_price, b_2200_borrow_amt);
    let b_updated_lend_amt = update_amt(
        b_init_note.lend_amt,
        b_init_note.timestamp,
        timestamp_32_hrs,
        LEND_INTEREST_RATE,
    );
    let b_additional_lend_amt = b_2200_lend_amt - b_updated_lend_amt;

    let b_2200_note = MyNote {
        lend_amt: b_2200_lend_amt,
        borrow_amt: b_2200_borrow_amt,
        will_liq_price: b_2200_will_liq_price,
        timestamp: timestamp_32_hrs,
        nullifier: 999 as Field,
        nonce: 888 as Field,
    };

    lend(
        b_init_note,
        b_init_note_hash,
        b_init_note_index,
        b_init_note_hash_path,
        merkle_root,
        liquidated_array,
        b_2200_note,
        b_additional_lend_amt,
    );

    let b_2200_note_hash = hash_my_note(b_2200_note);
    let b_2200_note_index = 4;
    merkle_leaves[b_2200_note_index] = b_2200_note_hash;

    // T = 32 hrs
    // b borrow more, making will_liq_price rise to around 2400
    let merkle_tree = construct_merkle_tree(merkle_leaves);
    let b_2200_note_hash_path = [zero_leaf, merkle_tree[3], merkle_tree[4]];
    let merkle_root = merkle_tree[6];

    let b_2400_will_liq_price = global_will_liq_price(2400, timestamp_32_hrs);
    let b_2400_lend_amt = update_amt(
        b_2200_note.lend_amt,
        b_2200_note.timestamp,
        timestamp_32_hrs,
        LEND_INTEREST_RATE,
    );

    let b_2400_borrow_amt = update_borrow_amt_new_liq_price(b_2400_will_liq_price, b_2400_lend_amt);
    let b_updated_borrow_amt = update_amt(
        b_2200_note.borrow_amt,
        b_2200_note.timestamp,
        timestamp_32_hrs,
        BORROW_INTEREST_RATE,
    );
    let b_additional_borrow_amt = b_2400_borrow_amt - b_updated_borrow_amt;

    let b_2400_note = MyNote {
        lend_amt: b_2400_lend_amt,
        borrow_amt: b_2400_borrow_amt,
        will_liq_price: b_2400_will_liq_price,
        timestamp: timestamp_32_hrs,
        nullifier: 1890 as Field,
        nonce: 97 as Field,
    };

    borrow(
        b_2200_note,
        b_2200_note_hash,
        b_2200_note_index,
        b_2200_note_hash_path,
        merkle_root,
        liquidated_array,
        b_2400_note,
        b_additional_borrow_amt,
    );

    let b_2400_note_hash = hash_my_note(b_2400_note);
    let b_2400_note_index = 5;
    merkle_leaves[b_2400_note_index] = b_2400_note_hash;

    // T = 72 hrs, liquidate 2600 ish..
    let timestamp_72_hrs = 72 * 60 * 60;
    liquidated_array[2] = Liquidated {
        liq_price: global_will_liq_price(2600, timestamp_72_hrs),
        timestamp: timestamp_72_hrs,
    };

    // T = 96 hrs, b repays all his debt
    let timestamp_96_hrs = 96 * 60 * 60;
    let merkle_tree = construct_merkle_tree(merkle_leaves);
    let b_2400_note_hash_path = [merkle_leaves[4], merkle_tree[3], merkle_tree[4]];
    let merkle_root = merkle_tree[6];

    // repay all debt
    let b_0_will_liq_price = 0;
    let b_0_lend_amt = update_amt(
        b_2400_note.lend_amt,
        b_2400_note.timestamp,
        timestamp_96_hrs,
        LEND_INTEREST_RATE,
    );

    let b_0_borrow_amt = 0;
    let b_updated_borrow_amt = update_amt(
        b_2400_note.borrow_amt,
        b_2400_note.timestamp,
        timestamp_96_hrs,
        BORROW_INTEREST_RATE,
    );
    let b_repay_borrow_amt = b_updated_borrow_amt - b_0_borrow_amt;

    let b_0_note = MyNote {
        lend_amt: b_0_lend_amt,
        borrow_amt: b_0_borrow_amt,
        will_liq_price: b_0_will_liq_price,
        timestamp: timestamp_96_hrs,
        nullifier: 2 as Field,
        nonce: 932494 as Field,
    };

    repay(
        b_2400_note,
        b_2400_note_hash,
        b_2400_note_index,
        b_2400_note_hash_path,
        merkle_root,
        liquidated_array,
        b_0_note,
        b_repay_borrow_amt,
    );

    let b_0_note_hash = hash_my_note(b_0_note);
    let b_0_note_index = 6;
    merkle_leaves[b_0_note_index] = b_0_note_hash;

    // T = 120 hrs, b withdraw some money
    let timestamp_120_hrs = 120 * 60 * 60;
    let merkle_tree = construct_merkle_tree(merkle_leaves);
    let b_0_note_hash_path = [zero_leaf, merkle_tree[2], merkle_tree[4]];
    let merkle_root = merkle_tree[6];

    let b_updated_lend_amt = update_amt(
        b_0_note.lend_amt,
        b_0_note.timestamp,
        timestamp_120_hrs,
        LEND_INTEREST_RATE,
    );
    let b_final_lend_amt = 20000;
    let b_final_borrow_amt = 0;
    let b_withdraw_lend_amt = b_updated_lend_amt - b_final_lend_amt;

    let b_final_note = MyNote {
        lend_amt: b_final_lend_amt,
        borrow_amt: b_final_borrow_amt,
        will_liq_price: 0,
        timestamp: timestamp_120_hrs,
        nullifier: 223 as Field,
        nonce: 12309 as Field,
    };

    withdraw(
        b_0_note,
        b_0_note_hash,
        b_0_note_index,
        b_0_note_hash_path,
        merkle_root,
        liquidated_array,
        b_final_note,
        b_withdraw_lend_amt,
    );
}

#[test]
fn test_inclusion_proof() {
    let a = 1 as Field;
    let b = 2 as Field;
    let c = 3 as Field;
    let d = 4 as Field;
    let zero = 0 as Field;

    let merkle_leaves = [a, b, c, d, zero, zero, zero, zero];
    let merkle = construct_merkle_tree(merkle_leaves);

    let leaf = c;
    let index = 2;
    let hash_path = [d, merkle[0], merkle[5]];
    let root = merkle[6];

    assert_inclusion_proof(leaf, index, hash_path, root);
}

#[test]
fn test_ltv() {
    let my_note = MyNote {
        lend_amt: 5,
        borrow_amt: 10,
        will_liq_price: 4,
        timestamp: 1000,
        nullifier: 111 as Field,
        nonce: 222 as Field,
    };
    assert_ltv(my_note);
}

#[test]
fn test_liquidation_check() {
    let my_note = MyNote {
        lend_amt: 1,
        borrow_amt: 500,
        will_liq_price: 1000,
        timestamp: 1000,
        nullifier: 111 as Field,
        nonce: 222 as Field,
    };

    let liquidated_array = [
        Liquidated { liq_price: 1100, timestamp: 1005 },
        Liquidated { liq_price: 1200, timestamp: 1010 },
        Liquidated { liq_price: 1100, timestamp: 1200 },
    ];
    assert_ltv(my_note);
    assert_non_liquidated(my_note, liquidated_array);
}
