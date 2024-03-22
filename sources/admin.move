module coin_address::admin {

    use std::signer;

    // This allows either the deployer, OR the funds admin, to do privaleged financial operations

    const FUNDS_ADMIN_ADDRESS: address = @0x728a91997c1eaec1138bb6aca4783f02b1f8f17f1b98342ce25e9180b7909420;

    const AIRDROPPER_ADDRESS: address = @0x7e5579b0405e8a6d87957e0c1a859189f7a5dbd2ed7047bcbc5269936a0a1e03;

    /// Caller is not an admin
    const E_NOT_ADMIN: u64 = 1;

    public fun airdropper_address(): address {
        AIRDROPPER_ADDRESS
    }

    public fun funds_admin_address(): address {
        FUNDS_ADMIN_ADDRESS
    }

    public fun is_airdropper(caller: &signer): bool {
        let caller_address = signer::address_of(caller);
        caller_address == AIRDROPPER_ADDRESS
    }

    public fun assert_admin_or_airdropper(caller: &signer) {
        assert!(is_admin(caller) || is_airdropper(caller), E_NOT_ADMIN);
    }

    public fun is_admin(caller: &signer): bool {
        let caller_address = signer::address_of(caller);
        caller_address == FUNDS_ADMIN_ADDRESS || caller_address == @coin_address
    }

    public fun assert_admin(caller: &signer) {
        assert!(is_admin(caller), E_NOT_ADMIN);
    }

    #[test(
        deployer = @coin_address,
        user = @0x055
    )]
    fun test_admin(deployer: &signer, user: &signer) {
        assert!(is_admin(deployer), 0);

        assert!(!is_admin(user), 1);
    }
}
