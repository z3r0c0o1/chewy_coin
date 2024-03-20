module coin_address::lockup {
    use std::bcs;
    use std::signer;
    use std::vector;
    use aptos_std::math64;
    use aptos_framework::aptos_account;
    use aptos_framework::coin::Coin;
    use aptos_framework::object;
    use aptos_framework::object::{ExtendRef, TransferRef};
    use aptos_framework::timestamp;
    use coin_address::admin;
    use coin_address::coin::{Self as chewy_coin, Chewy};

    const TWO_YEARS_SECS: u64 = 2 * (365 * 24 * 60 * 60);
    const FOUR_YEARS_SECS: u64 = 4 * (365 * 24 * 60 * 60);

    /// There is no vault for the given address
    const E_VAULT_DOES_NOT_EXIST: u64 = 1;
    /// There is already a vault for the given address
    const E_VAULT_ALREADY_EXISTS: u64 = 2;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ChewyVault has key {
        // The coins that are locked here
        locked_coins: Coin<Chewy>,
        // The amount of the coin that is initially locked
        initial_amount: u64,
        // The amount of the coin that has been claimed
        claimed_coins: u64,
        // The time in seconds that the lockup started
        start_time_sec: u64,
        // Time, in seconds that the vault lockup is over
        lockup_secs: u64,
        extend_ref: ExtendRef,
        transfer_ref: TransferRef,
    }

    fun init_module(deployer: &signer) {
        chewy_coin::initialize_module(deployer);
        coin_address::claims::initialize_module(deployer);

        let total_supply = chewy_coin::supply();
        assert!(chewy_coin::deployer_balance() == total_supply, 99001);

        // 20% Early Contributors (2 Years linear lockup)
        let early_contributors_address: address = @0x010000;
        let early_contributors_percent: u64 = 20;
        let early_contributors_coins = math64::mul_div(total_supply, early_contributors_percent, 100);
        create_vault(deployer, early_contributors_address, early_contributors_coins, TWO_YEARS_SECS);

        // 5%  Liquidity Provisions (4 year linear lockup)
        let liquidity_provis_address: address = @0x010001;
        let liquidity_provis_percent: u64 = 5;
        let liquidity_provis_coins = math64::mul_div(total_supply, liquidity_provis_percent, 100);
        create_vault(deployer, liquidity_provis_address, liquidity_provis_coins, FOUR_YEARS_SECS);

        // 15% Development of the ecosystem (4 year linear lockup)
        let ecosystem_fund_address: address = @0x010002;
        let ecosystem_fund_percent: u64 = 15;
        let ecosystem_fund_coins = math64::mul_div(total_supply, ecosystem_fund_percent, 100);
        create_vault(deployer, ecosystem_fund_address, ecosystem_fund_coins, FOUR_YEARS_SECS);

        // 10% Marketing (4 year linear lockup)
        let marketing_address: address = @0x010003;
        let marketing_percent: u64 = 10;
        let marketing_coins = math64::mul_div(total_supply, marketing_percent, 100);
        create_vault(deployer, marketing_address, marketing_coins, FOUR_YEARS_SECS);

        // 20% initial supply for airdrops
        let airdrop_address: address = @0x010004;
        let initial_airdrop_percent: u64 = 20;
        let initial_airdrop_coins = math64::mul_div(total_supply, initial_airdrop_percent, 100);
        // Send immediately
        aptos_account::deposit_coins<Chewy>(airdrop_address, chewy_coin::withdraw_coins(initial_airdrop_coins));

        // 30% future airdrop/etc (4 year linear lockup)
        let future_airdrop_percent: u64 = 30;
        let future_airdrop_coins = math64::mul_div(total_supply, future_airdrop_percent, 100);
        create_vault(deployer, airdrop_address, future_airdrop_coins, FOUR_YEARS_SECS);

        assert!(chewy_coin::deployer_balance() == 0, 99002);
    }

    public entry fun create_vault(deployer: &signer, for_user: address, lock_amount: u64, lockup_secs: u64) {
        admin::assert_admin(deployer);

        let user_address_bytes = bcs::to_bytes(&for_user);
        let constructor = object::create_named_object(deployer, user_address_bytes);
        let extend_ref = object::generate_extend_ref(&constructor);
        let transfer_ref = object::generate_transfer_ref(&constructor);
        let object_signer = object::generate_signer(&constructor);
        let object_address = object::address_from_constructor_ref(&constructor);

        // Transfer ownership of the object to the vault owning user
        object::transfer_call(deployer, object_address, for_user);

        // Make it soulbound
        object::disable_ungated_transfer(&transfer_ref);

        let coins = chewy_coin::withdraw_coins(lock_amount);
        let vault = ChewyVault {
            locked_coins: coins,
            initial_amount: lock_amount,
            claimed_coins: 0,
            lockup_secs,
            start_time_sec: timestamp::now_seconds(),
            extend_ref,
            transfer_ref
        };
        move_to(&object_signer, vault);
    }

    /// Lets a user claim their unlocked coins
    public entry fun claim_unlocked_coins(caller: &signer) acquires ChewyVault {
        let user_address = signer::address_of(caller);
        claim_unlocked_coins_for_user(user_address);
    }

    /// Allows anyone to distribute unlocked coins to multiple users that have a vault
    /// TODO: is this something we actually want?
    public entry fun distribute_unlocked_coins(_caller: &signer, user_addresses: vector<address>) acquires ChewyVault {
        let length = vector::length(&user_addresses);
        for (i in 0..length) {
            let user_address = *vector::borrow(&user_addresses, i);
            claim_unlocked_coins_for_user(user_address);
        }
    }

    fun claim_unlocked_coins_for_user(user_address: address) acquires ChewyVault {
        let claimable_coins = claimable_coins(user_address);
        transfer_from_vault(user_address, claimable_coins);
    }

    fun transfer_from_vault(user_address: address, amount: u64) acquires ChewyVault {
        let vault_address = assert_vault_address(user_address);
        let vault = borrow_global_mut<ChewyVault>(vault_address);

        let remaining_coins = vault.initial_amount - vault.claimed_coins;
        let amount = math64::min(remaining_coins, amount);
        if (amount == 0) {
            return
        };
        vault.claimed_coins = vault.claimed_coins + amount;
        let coins = chewy_coin::withdraw_coins(amount);
        aptos_account::deposit_coins<Chewy>(user_address, coins);
    }

    #[view]
    /// Linearly unlock the coins for the caller the vault over the duration of the lock
    public fun claimable_coins(user_address: address): u64 acquires ChewyVault {
        let vault_address = assert_vault_address(user_address);
        let vault = borrow_global<ChewyVault>(vault_address);
        let now = timestamp::now_seconds();
        // If the lockup has expired, return any remaining coins
        if (now >= vault.start_time_sec + vault.lockup_secs) {
            return vault.initial_amount - vault.claimed_coins
        };
        // Otherwise, calculate how many coins are unlockable but not yet claimed
        let elapsed_time = now - vault.start_time_sec;
        let unlocked_coins = math64::mul_div(vault.initial_amount, elapsed_time, vault.lockup_secs);
        unlocked_coins - vault.claimed_coins
    }

    public fun assert_vault_address(user_address: address): address {
        let vault_address = vault_address_inline(user_address);
        assert!(exists<ChewyVault>(vault_address), E_VAULT_DOES_NOT_EXIST);
        vault_address
    }

    #[view]
    public fun vault_address(user_address: address): address {
        vault_address_inline(user_address)
    }

    inline fun vault_address_inline(user_address: address): address {
        let user_address_bytes = bcs::to_bytes(&user_address);
        object::create_object_address(&@coin_address, user_address_bytes)
    }

    #[test(
        framework = @0x1,
        deployer = @coin_address,
        user = @0x010005
    )]
    fun test_linear_unlocks(framework: &signer, deployer: &signer, user: &signer) acquires ChewyVault {
        timestamp::set_time_has_started_for_testing(framework);

        chewy_coin::initialize_module(deployer);
        let start_time = 1;
        timestamp::update_global_time_for_test_secs(start_time);

        let user_address = signer::address_of(user);
        let user_vault_address = vault_address(user_address);
        assert!(vault_address(user_address) == user_vault_address, 1);
        let lock_amount: u64 = 100;
        let lock_time: u64 = 100;
        create_vault(deployer, user_address, lock_amount, lock_time);

        let vault = borrow_global<ChewyVault>(user_vault_address);
        assert!(aptos_framework::coin::value<Chewy>(&vault.locked_coins) == lock_amount, 2);
        assert!(vault.lockup_secs == lock_time, 3);
        assert!(vault.claimed_coins == 0, 4);
        let claimable_coins = claimable_coins(user_address);
        assert!(claimable_coins == 0, claimable_coins);

        // Test at half time
        timestamp::update_global_time_for_test_secs(start_time + lock_amount / 2);
        let claimable_coins = claimable_coins(user_address);
        assert!(claimable_coins == lock_amount / 2, claimable_coins);
        // Claim half the coins
        claim_unlocked_coins(user);
        assert!(chewy_coin::account_balance(user_address) == lock_amount / 2, 10);
        assert!(claimable_coins(user_address) == 0, 11);

        // Test at past lockup end
        timestamp::update_global_time_for_test_secs(start_time + lock_amount * 2);
        let claimable_coins = claimable_coins(user_address);
        // We already claimed half the coins
        assert!(claimable_coins == lock_amount / 2, 20);
        // Claim the rest
        claim_unlocked_coins(user);
        assert!(chewy_coin::account_balance(user_address) == lock_amount, 21);
        assert!(claimable_coins(user_address) == 0, 22);
    }

    #[test(
        framework = @0x1,
        deployer = @coin_address,
    )]
    fun test_init(framework: &signer, deployer: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        init_module(deployer);
    }
}
