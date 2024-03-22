module coin_address::admin {

    use std::signer;

    // This allows either the deployer, OR the funds admin, to do privaleged financial operations

    const FUNDS_ADMIN_ADDRESS: address = @coin_address;

    /// Caller is not an admin
    const E_NOT_ADMIN: u64 = 1;

    public fun funds_admin_address(): address {
        FUNDS_ADMIN_ADDRESS
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
