module coin_address::coin {

    use std::option;
    use std::signer;
    use std::string::utf8;
    use aptos_std::math64;

    use aptos_framework::aptos_account;
    use aptos_framework::coin::{Self, FreezeCapability, BurnCapability, Coin};
    use aptos_framework::object::{Self, ExtendRef};
    use coin_address::admin;

    friend coin_address::airdrop;
    friend coin_address::lockup;
    friend coin_address::claims;

    const COIN_NAME: vector<u8> = b"Chewy";
    const SYM: vector<u8> = b"CHEWY";
    // 1 trillion
    const SUPPLY: u64 = 1_000_000_000_000;
    const DECIMALS: u8 = 0;

    /// Not creator
    const E_NOT_CREATOR: u64 = 1;

    struct Chewy {}

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct CoinController has key {
        /// Extend ref is to make updates if pieces are missing
        extend_ref: ExtendRef,
        coin_burn_cap: BurnCapability<Chewy>,
        coin_freeze_cap: FreezeCapability<Chewy>
    }

    public(friend) fun initialize_module(deployer: &signer) {
        // Only publisher can call this function
        assert!(@coin_address == signer::address_of(deployer), E_NOT_CREATOR);

        // Only initialize once
        let object_address = object_address();
        assert!(!object::is_object(object_address), 0);

        // Create object for coin owner
        let constructor = object::create_named_object(deployer, COIN_NAME);
        let extend_ref = object::generate_extend_ref(&constructor);
        let object_signer = object::generate_signer(&constructor);
        let object_address = signer::address_of(&object_signer);

        // Create the coin
        let (burn, freeze, mint) = coin::initialize<Chewy>(
            deployer,
            utf8(COIN_NAME),
            utf8(SYM),
            DECIMALS,
            true
        );

        // Make object an account to hold coins
        aptos_account::create_account(object_address);

        // Mint initial supply, deposit in the object
        let total_supply = SUPPLY * math64::pow(10, (DECIMALS as u64));

        let coins = coin::mint(total_supply, &mint);
        coin::register<Chewy>(&object_signer);
        coin::deposit(object_address, coins);

        // Destroy unused abilities
        coin::destroy_mint_cap(mint);

        let coin_controller = CoinController {
            extend_ref,
            coin_burn_cap: burn,
            coin_freeze_cap: freeze
        };

        move_to(&object_signer, coin_controller);
    }

    /// Burns coins from the caller's account
    public(friend) fun burn_coin(caller: &signer, amount: u64) acquires CoinController {
        let controller = borrow_global<CoinController>(object_address());
        let caller_address = signer::address_of(caller);
        coin::burn_from<Chewy>(caller_address, amount, &controller.coin_burn_cap);
    }

    #[view]
    public fun deployer_balance(): u64 {
        let object_address = object_address();
        coin::balance<Chewy>(object_address)
    }

    #[view]
    public fun account_balance(account: address): u64 {
        coin::balance<Chewy>(account)
    }

    #[view]
    public fun object_address(): address {
        object::create_object_address(&@coin_address, COIN_NAME)
    }


    #[view]
    public fun supply(): u64 {
        let supply = option::extract(&mut coin::supply<Chewy>());
        (supply as u64)
    }

    /// Retrieves the signer, and ensures it's the owner of the object
    public(friend) fun get_coin_signer_as_admin(caller: &signer): signer acquires CoinController {
        admin::assert_admin(caller);
        get_coin_signer()
    }

    /// Note that this is fully unauthorized, so all friend functions can call this
    public(friend) fun get_coin_signer(): signer acquires CoinController {
        let controller = borrow_global<CoinController>(object_address());
        object::generate_signer_for_extending(&controller.extend_ref)
    }

    /// Withdraws the coins from the deployer vault, no auth needed
    public(friend) fun withdraw_coins(amount: u64): Coin<Chewy> acquires CoinController {
        coin::withdraw<Chewy>(&get_coin_signer(), amount)
    }
}
