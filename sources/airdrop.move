module coin_address::airdrop {

    use std::vector;
    use aptos_framework::aptos_account;
    use coin_address::coin::{Chewy, get_coin_signer_as_admin};

    /// Number of addresses doesn't match amounts
    const E_ADDRESS_COUNT_NOT_MATCH_AMOUNT_COUNT: u64 = 1;

    public entry fun airdrop(caller: &signer, account: address, amount: u64) {
        airdrop_tokens(caller, account, amount);
    }

    /// anyone can airdrop coins to anyone
    public entry fun airdrop_many(caller: &signer, accounts: vector<address>, amounts: vector<u64>) {
        let length = vector::length(&accounts);
        assert!(length == vector::length(&amounts), E_ADDRESS_COUNT_NOT_MATCH_AMOUNT_COUNT);

        // Airdrop to each
        for (i in 0..length) {
            airdrop_tokens(caller, *vector::borrow(&accounts, i), *vector::borrow(&amounts, i));
        }
    }

    /// Airdrop coins to accounts with the same amount each
    public entry fun airdrop_many_same(caller: &signer, accounts: vector<address>, amount: u64) {
        let coin_signer = get_coin_signer_as_admin(caller);

        // Airdrop to each
        vector::for_each(accounts, |account| {
            airdrop_tokens(&coin_signer, account, amount);
        });
    }

    /// Transfers tokens to a given user from callers balance
    inline fun airdrop_tokens(caller: &signer, destination: address, amount: u64) {
        aptos_account::transfer_coins<Chewy>(caller, destination, amount);
    }
}
