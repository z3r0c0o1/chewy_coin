module coin_address::claims {

    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::aptos_account;
    use aptos_framework::coin::{Self, Coin};
    use coin_address::coin::{Chewy};

    friend coin_address::lockup;

    /// Only the deployer is allowed to call this
    const E_NOT_DEPLOYER: u64 = 1;
    /// The address has no claims associated with it
    const E_NO_CLAIM_EXISTS: u64 = 2;
    /// The address has already claimed
    const E_ALREADY_CLAIMED: u64 = 3;
    /// This address already has a claim
    const E_ALREADY_HAS_CLAIM: u64 = 4;
    /// The address and amount vectors are not the same length
    const E_MISMATCHED_LENGTHS: u64 = 5;

    // Allow people to claim coins from the contract if allowed to
    // Maps from address to the coins allowed to be claimed
    // If a user has already claimed, amount will be 0
    struct ClaimHolder has key {
        claims: Table<address, Coin<Chewy>>
    }

    entry fun initialize(deployer: &signer) {
        // Only publisher can call this function
        assert!(@coin_address == signer::address_of(deployer), E_NOT_DEPLOYER);

        let claims = ClaimHolder {
            claims: table::new(),
        };
        move_to(deployer, claims);
    }

    #[view]
    public fun claimable(user_address: address): u64 acquires ClaimHolder {
        let claim_holder = borrow_global<ClaimHolder>(@coin_address);
        if (table::contains(&claim_holder.claims, user_address)) {
            let coins = table::borrow(&claim_holder.claims, user_address);
            coin::value(coins)
        } else {
            0
        }
    }

    public entry fun claim(caller: &signer) acquires ClaimHolder {
        let user_address = signer::address_of(caller);

        let claim_holder = borrow_global_mut<ClaimHolder>(@coin_address);
        assert!(table::contains(&claim_holder.claims, user_address), E_NO_CLAIM_EXISTS);

        let escrowed_coins = table::borrow_mut(&mut claim_holder.claims, user_address);
        assert!(coin::value(escrowed_coins) > 0, E_ALREADY_CLAIMED);

        // Extract the coins from the claim, setting amount to 0
        let coins = coin::extract_all(escrowed_coins);

        // Deposit the coins into the users account
        aptos_account::deposit_coins(user_address, coins);
    }

    public entry fun add_claim(caller: &signer, for_address: address, amount: u64) acquires ClaimHolder {
        let claim_holder = borrow_global_mut<ClaimHolder>(@coin_address);
        withdraw_and_add_claim_internal(&mut claim_holder.claims, caller, for_address, amount);
    }

    public entry fun add_many_claims(
        caller: &signer,
        for_addresses: vector<address>,
        amounts: vector<u64>
    ) acquires ClaimHolder {
        assert!(vector::length(&for_addresses) == vector::length(&amounts), E_MISMATCHED_LENGTHS);
        let claim_holder = borrow_global_mut<ClaimHolder>(@coin_address);
        vector::zip_reverse(for_addresses, amounts, |address, amount| {
            withdraw_and_add_claim_internal(&mut claim_holder.claims, caller, address, amount);
        });
    }

    public entry fun increase_claim(caller: &signer, for_address: address, amount: u64) acquires ClaimHolder {
        let claim_holder = borrow_global_mut<ClaimHolder>(@coin_address);
        withdraw_and_increase_claim_internal(&mut claim_holder.claims, caller, for_address, amount);
    }

    public entry fun increase_many_claims(
        caller: &signer,
        for_addresses: vector<address>,
        amounts: vector<u64>
    ) acquires ClaimHolder {
        assert!(vector::length(&for_addresses) == vector::length(&amounts), E_MISMATCHED_LENGTHS);
        let claim_holder = borrow_global_mut<ClaimHolder>(@coin_address);
        vector::zip_reverse(for_addresses, amounts, |address, amount| {
            withdraw_and_increase_claim_internal(&mut claim_holder.claims, caller, address, amount);
        });
    }

    fun withdraw_and_add_claim_internal(
        claims: &mut Table<address, Coin<Chewy>>,
        caller: &signer,
        for_address: address,
        amount: u64
    ) {
        assert!(!table::contains(claims, for_address), E_ALREADY_HAS_CLAIM);
        let coins = coin::withdraw<Chewy>(caller, amount);
        table::add(claims, for_address, coins);
    }

    fun withdraw_and_increase_claim_internal(
        claims: &mut Table<address, Coin<Chewy>>,
        caller: &signer,
        for_address: address,
        amount: u64
    ) {
        assert!(table::contains(claims, for_address), E_NO_CLAIM_EXISTS);
        let coins = coin::withdraw<Chewy>(caller, amount);
        let existing_coins = table::borrow_mut(claims, for_address);
        coin::merge(existing_coins, coins);
    }

    #[test_only]
    fun init_and_get_coins(deployer: &signer): Coin<Chewy> {
        initialize(deployer);
        coin_address::coin::initialize_module(deployer);
        coin_address::coin::withdraw_coins(1000)
    }

    #[test(
        deployer = @coin_address,
        user1 = @0x3001,
    )]
    fun test_can_add_and_claim(deployer: &signer, user1: &signer) acquires ClaimHolder {
        let coins = init_and_get_coins(deployer);
        let start_balance = coin::value(&coins);

        let user1_address = signer::address_of(user1);

        aptos_account::deposit_coins(@coin_address, coins);
        assert!(coin::balance<Chewy>(@coin_address) == start_balance, 0);
        assert!(claimable(user1_address) == 0, 1);

        add_claim(deployer, user1_address, 100);
        assert!(coin::balance<Chewy>(@coin_address) == start_balance - 100, 10);
        assert!(claimable(user1_address) == 100, 11);

        claim(user1);
        assert!(coin::balance<Chewy>(user1_address) == 100, 20);
        assert!(claimable(user1_address) == 0, 21);
    }
}
