use dep::std;

// ==== Global config ==== (percentage-based)
global LTV_THRESHOLD: u64 = 50; //
global LEND_INTEREST_RATE: u64 = 3; // annual rate
global BORROW_INTEREST_RATE: u64 = 10; // annual rate
global ACCEPTABLE_PERCENT:u64 = 1;

// Assume price is integer
// Assume amt has at most 5 decimal, so we default times 10000
struct Liquidated{
    liq_price: u64, // in smallest units 
    timestamp: u64
}

struct MyNote{
    lend_amt: u64,   // in smallest units (scaled, e.g., x10^5)
    borrow_amt: u64, // in smallest units (scaled, e.g., x10^5)
    will_liq_price: u64, // in smallest units
    timestamp: u64,
    nullifier: Field,
    nonce: Field
}

fn simple_hash(left: Field, right: Field) -> Field{
    std::hash::pedersen_hash([left, right])
}

fn hash_my_note(my_note: MyNote) -> Field{
    std::hash::pedersen_hash([
        my_note.lend_amt as Field, 
        my_note.borrow_amt as Field, 
        my_note.will_liq_price as Field, 
        my_note.timestamp as Field, 
        my_note.nullifier, 
        my_note.nonce
    ])
}

// assert if LTV condition is satisfied
fn assert_ltv(my_note: MyNote){
    assert(my_note.borrow_amt * 100 <= LTV_THRESHOLD * my_note.lend_amt * my_note.will_liq_price);
}


fn abs_diff(x:u64, y:u64) -> u64 {
    if x >=y { x-y } else { y-x }
}

// Check if two values are within a percentage range
fn is_within_percentage(x: u64, y: u64, percent: u64) -> u8 {
    let diff = abs_diff(x, y) * 100;
    let allowed_diff = percent * y;
    if diff <= allowed_diff { 1 } else { 0 }
}


// Check if our will_liq_price is actually liquidated or not, accounting for lend & borrow interest
fn is_myposition_liquidated( my_price: u64, liq_price: u64, my_time: u64, liq_time: u64) -> u8 {
    if liq_time < my_time{
        0
    } else{
        let one_year_seconds = 365 * 24 * 60 * 60;
        let time_diff = liq_time - my_time;

        let borrow_factor = one_year_seconds + BORROW_INTEREST_RATE * time_diff;
        let lend_factor = one_year_seconds + LEND_INTEREST_RATE * time_diff;

        let my_adjusted_price = borrow_factor * my_price;
        let liq_adjusted_price = lend_factor * liq_price;

        is_within_percentage(my_adjusted_price, liq_adjusted_price, ACCEPTABLE_PERCENT)
    }
}

fn assert_update_amt(prev_amt: u64, prev_timestamp: u64, curr_amt: u64, curr_timestamp: u64, interest_rate: u64){
    let one_year_seconds = 365 * 24 * 60 * 60;
    let time_diff = curr_timestamp - prev_timestamp;

    let projected_amt = (one_year_seconds + interest_rate * time_diff) * prev_amt;
    let actual_amt = one_year_seconds * curr_amt;

    assert(is_within_percentage(projected_amt, actual_amt, ACCEPTABLE_PERCENT) == 1);
}

// assert that my position isn't liquidated 
fn assert_non_liquidation(my_note: MyNote, liquidated_array: [Liquidated; 3]) {
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
    assert(is_liquidated == 0);
}



fn assert_inclusion_proof(leaf: Field, index: u32, hash_path:[Field;3], root:Field){
    let calculated_root = std::merkle::compute_merkle_root(leaf, index as Field, hash_path);
    assert(calculated_root == root);
}

fn initial_deposit(lend_amt: u64, timestamp: u64, nullifier: Field, nonce: Field) -> Field{
    let my_note: MyNote = MyNote{
        lend_amt,
        borrow_amt: 0,
        will_liq_price: 0, // 0 indicates no possibility of liquidation
        timestamp,
        nullifier,
        nonce
    };
    assert_ltv(my_note);
    hash_my_note(my_note)
}

fn borrow(prev_note: MyNote, prev_hash: Field, prev_index: u32, prev_hash_path: [Field; 3], root: Field, liquidated_array: [Liquidated; 3], new_note:MyNote, additional_borrow_amt:u64) -> Field{
    assert(hash_my_note(prev_note) == prev_hash);
    assert_inclusion_proof(prev_hash, prev_index, prev_hash_path, root);
    assert_non_liquidation(prev_note, liquidated_array);
    
    // assert updated lending amount
    assert_update_amt(prev_note.lend_amt, prev_note.timestamp, new_note.lend_amt, new_note.timestamp, LEND_INTEREST_RATE);

    // assert updated borrowing amount (before borrowing more)
    assert_update_amt(prev_note.borrow_amt, prev_note.timestamp, new_note.borrow_amt - additional_borrow_amt, new_note.timestamp, BORROW_INTEREST_RATE);

    assert_ltv(new_note);
    hash_my_note(new_note)
}


fn construct_merkle_tree(leaf_array:[Field;8]) -> [Field;7]{
    let mut lv1_nodes: [Field;4] = [0;4];
    for i in 0..4 {
        lv1_nodes[i] = simple_hash(leaf_array[2*i], leaf_array[2*i+1]);
    }
    let mut lv2_nodes: [Field;2] = [0;2];
    for i in 0..2 {
        lv2_nodes[i] = simple_hash(lv1_nodes[2*i], lv1_nodes[2*i+1]);
    }
    let root = simple_hash(lv2_nodes[0], lv2_nodes[1]);
    [lv1_nodes[0], lv1_nodes[1], lv1_nodes[2], lv1_nodes[3], lv2_nodes[0], lv2_nodes[1], root]

}


#[test]
fn test_inclusion_proof() {
    let a = 1 as Field;
    let b = 2 as Field;
    let c = 3 as Field;
    let d = 4 as Field;
    let zero = 0 as Field;

    let merkle = construct_merkle_tree([a, b, c, d, zero, zero, zero, zero]);
    let hash_path = [d, merkle[0], merkle[5]];
    let root = merkle[6];
    
    let leaf = c;
    let index = 2;

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
        Liquidated { liq_price: 1300, timestamp: 1005 },   
        Liquidated { liq_price: 1200, timestamp: 1010 },  
        Liquidated { liq_price: 1100, timestamp: 1200 },  
    ];
    assert_ltv(my_note);
    assert_non_liquidation(my_note, liquidated_array);
}

#[test]
fn test_initial_deposit() {
    let hash = initial_deposit(1000, 0, 123 as Field, 456 as Field);
    assert(hash != 0);
}

#[test]
fn test_borrow_flow() {
    let prev_note = MyNote {
        lend_amt: 400000,
        borrow_amt: 20000000,
        will_liq_price: 1000,
        timestamp: 1000,
        nullifier: 123 as Field,
        nonce: 456 as Field,
    };

    let prev_hash = hash_my_note(prev_note);
    let prev_index = 1;
    let zero = 0 as Field;
    let merkle = construct_merkle_tree([1 as Field, prev_hash, 34 as Field, zero, zero, zero, zero, zero ]);
    let prev_hash_path = [1 as Field, merkle[1], merkle[5]];
    let root = merkle[6];

    let liquidated_array = [
        Liquidated { liq_price: 1300, timestamp: 1100 },
        Liquidated { liq_price: 1500, timestamp: 1200 },
        Liquidated { liq_price: 1200, timestamp: 1300 },
    ];

    let new_note = MyNote {
        lend_amt: 400015,
        borrow_amt: 20502536,
        will_liq_price: 1025,
        timestamp: 1400,
        nullifier: 999 as Field,
        nonce: 888 as Field,
    };

    borrow(
        prev_note,
        prev_hash,
        prev_index,
        prev_hash_path,
        root,
        liquidated_array,
        new_note,
        500000,
    );
}
