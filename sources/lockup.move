module coin_address::lockup {
    use std::bcs;
    use std::signer;
    use std::vector;
    use aptos_std::math64;
    use aptos_framework::aptos_account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::object::{Self, ExtendRef, TransferRef};
    use aptos_framework::timestamp;
    use coin_address::claims;
    use coin_address::admin;
    use coin_address::coin::{Self as chewy_coin, Chewy};

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

        let one_year_secs: u64 = 365 * 24 * 60 * 60;
        let two_years_secs: u64 = 2 * one_year_secs;
        let four_years_secs: u64 = 4 * one_year_secs;

        let total_supply = chewy_coin::supply();
        assert!(chewy_coin::deployer_balance() == total_supply, 99001);
        assert!(total_supply == 1_000_000_000_000, 99002);

        // 20% Early Contributors (2 Years linear lockup)
        let early_contrib_percent: u64 = 20;
        let early_contrib_coins = math64::mul_div(total_supply, early_contrib_percent, 100);
        // These vars are just so linter doesnt wrap all these lines
        let d = deployer;
        let tys = two_years_secs;
        create_vault(d, @0x4ccc3b9b9d7e1bafa3a5ac28653e293dcbaf51fa00508173398b13a1fcaf18f5, 10_000_000_000, tys);
        create_vault(d, @0x2095e2dee5f4eb209c850134fdcfbfc6de0d2017162efba1e88e78ada29ac729, 10_000_000_000, tys);
        create_vault(d, @0x9b747e69215d3cc9b43b6ab4e7596e561c75f5c8de707ce1770d28491ed2243f, 10_000_000_000, tys);
        create_vault(d, @0x2ed71316ffe576c53b8d8672bd84cdfb1275246819fac2259189e4b944f86eca, 10_000_000_000, tys);
        create_vault(d, @0x9844692b35c338fe9407e5f445ae13dcc0ebc260a94a1e318ca2f26d596e6e17, 10_000_000_000, tys);
        create_vault(d, @0x907c8d5c482c4e9092dfdbedf51b5a4087e84ed47db40629b9f1a25986132a5a, 10_000_000_000, tys);
        create_vault(d, @0xcedb2a38d7339927761b156a0719067a55241a398f789c9c6ea2843fddfced53, 10_000_000_000, tys);
        create_vault(d, @0x9c5266556aa3e1350912f68b28e352f3bd83c9c890cf9dfb68e69a70d7ed3579, 10_000_000_000, tys);
        create_vault(d, @0x8f79f5a477941d2989f7a728c529f6ea4b911a860daa45d64fca7834310800d4, 2_500_000_000, tys);
        create_vault(d, @0xa3f8ad95d7a2d8e237c1a03c9e0e6bf6fd1710752c601b3befab948210b93697, 10_000_000_000, tys);
        create_vault(d, @0x64cad0f1b8b0d477244a9019a867c1fbf68540f3b01cd8e500342726dc77943b, 10_000_000_000, tys);
        create_vault(d, @0x0107619000eb52e29967a172809220f28d581345ef33b70969bebb3868948e38, 1_000_000_000, tys);
        create_vault(d, @0xf1d6cf706c1fbf995b1d5613efc05b55b9248c627f4982d1310b28c3d689d4cf, 10_000_000_000, tys);
        create_vault(d, @0x2d9416852731b07eed2216f5cda16f7d79d627f0c4526135b690d77f53e2772d, 5_000_000_000, tys);
        create_vault(d, @0xdc9bc3f8edcf382d54bbdb21691e0733b638444d35f83de6bfbef6b729789ff0, 5_000_000_000, tys);
        create_vault(d, @0xb6ae5f39eda32f8e3a7ceaab2529ce314fb75abdb29197d457c4a0476de8b6d8, 400_000_000, tys);
        create_vault(d, @0x07c70937d519e9b03b989886037766968055c599fe456c1dbb9252085023d855, 2_000_000_000, tys);
        create_vault(d, @0x175aae5e20512e6e3a8018a8ff00be21f2de3bac84a574312bab2d47b64e594d, 10_000_000_000, tys);
        create_vault(d, @0x814ccf1811daa30b576e5708dba3641ef71cd6b2c48d229d77bff90064fa35b3, 6_500_000_000, tys);
        create_vault(d, @0x8038525a9185e7cdb7bc5fc90a7ca0dbfed53a911e7d313dc0bbdbbacb9991cd, 10_000_000_000, tys);
        create_vault(d, @0x578bd62922a9e6b8dd6fc87930d77e11e53d10e79c0168c43deb8721404c99e7, 5_600_000_000, tys);
        create_vault(d, @0xb19352cef00355d3e19ee937eebabb0b1986e4c9efd9dfa7b0b17301139b418d, 10_000_000_000, tys);
        create_vault(d, @0x0f2c8fd0b000384a9d65d7e97b368255e4afeac92b7b13b11708fb1280008bf6, 3_300_000_000, tys);
        create_vault(d, @0xd6f6a7327ed37248a32143bc7c26b9cfbc762765cbedfc1471adbda5a83e55ab, 3_300_000_000, tys);
        create_vault(d, @0x35313da796e350a54bfe7bbf8f6da62078d3923a7a46af9d82d0881ebfd744ef, 1_600_000_000, tys);
        create_vault(d, @0xa23a31bd20afd9e9e2792c1015d2d02f6bef222f3018921a6f02ceed46779144, 5_000_000_000, tys);
        create_vault(d, @0xb69057eb3c48340e30820f90283b65364639e74ce0266e0391431bdf7ec14c04, 5_000_000_000, tys);
        create_vault(d, @0xdbfd48566a4f2fdc09c008198963c8be545b201cfe8c92239c7bc08ad7e14bf2, 5_000_000_000, tys);
        create_vault(d, @0x6d2add1a815e9acf6b053bcbd41c510484f1ce816ec16a889d8c619153ffcfc8, 8_800_000_000, tys);

        let early_contrib_spent = total_supply - chewy_coin::deployer_balance();
        assert!(early_contrib_spent == early_contrib_coins, early_contrib_spent);

        // 5%  Liquidity Provisions: instant unlock
        let liquidity_provis_address: address = @0x51a17e598d3ab1ca671204114a21f7dbec8f42d6723691a15607b589d9347d9e;
        let liquidity_provis_percent: u64 = 5;
        let liquidity_provis_coins = math64::mul_div(total_supply, liquidity_provis_percent, 100);
        // Send immediately
        aptos_account::deposit_coins<Chewy>(liquidity_provis_address, chewy_coin::withdraw_coins(liquidity_provis_coins));

        // 10% Development of the ecosystem/Grants (4 year linear lockup)
        let ecosystem_fund_address: address = @0x46f7a9640521b63db61754bf59c05e9a447b8fc4c24d2b6ea43120c359c24796;
        let ecosystem_fund_percent: u64 = 10;
        let ecosystem_fund_coins = math64::mul_div(total_supply, ecosystem_fund_percent, 100);
        create_vault(deployer, ecosystem_fund_address, ecosystem_fund_coins, four_years_secs);

        // 10% Marketing (4 year linear lockup)
        let marketing_address: address = @0xc61b9fb26138134b1fd083f713ca118e3b9d8938ddc68f6c441f4c7680fd55d8;
        let marketing_percent: u64 = 10;
        let marketing_coins = math64::mul_div(total_supply, marketing_percent, 100);
        create_vault(deployer, marketing_address, marketing_coins, four_years_secs);

        // 1 Chewy each for testing the claims
        let dev_test_addresses: vector<address> = vector[
            @0x6387624e5119b373eadc741be5dababccce564cd909afbaeb83d1cc8db4e56a3,
            @0x15e11919a869fa240f9204c77e9a57922fea4c13ed784b02888cd976a9ec524f
        ];
        let num_dev_coin = vector::length(&dev_test_addresses);
        let deployer_address = signer::address_of(deployer);
        vector::for_each(dev_test_addresses, |dev_address| {
            let coins = chewy_coin::withdraw_coins(1);
            aptos_account::deposit_coins<Chewy>(deployer_address, coins);
            claims::add_claim(deployer, dev_address, 1);
        });

        // 35% initial supply for airdrops
        let airdrop_address: address = admin::claim_admin_address();
        let initial_airdrop_percent: u64 = 35;
        // We withhold the dev address coins from here; is very minimal
        let initial_airdrop_coins = math64::mul_div(total_supply, initial_airdrop_percent, 100) - num_dev_coin;
        // Send immediately
        aptos_account::deposit_coins<Chewy>(airdrop_address, chewy_coin::withdraw_coins(initial_airdrop_coins));

        // 20% future airdrop/etc (4 year linear lockup)
        let future_airdrop_percent: u64 = 20;
        let future_airdrop_coins = math64::mul_div(total_supply, future_airdrop_percent, 100);
        create_vault(deployer, airdrop_address, future_airdrop_coins, four_years_secs);

        let remaining_balance = chewy_coin::deployer_balance();
        assert!(remaining_balance == 0, remaining_balance);
    }

    public entry fun create_vault(deployer: &signer, for_user: address, lock_amount: u64, lockup_secs: u64) {
        admin::assert_fund_admin_or_deployer(deployer);

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
        let coins = coin::extract(&mut vault.locked_coins, amount);
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
