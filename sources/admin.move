module coin_address::admin {

    use std::signer;

    // This allows either the deployer, OR the funds admin, to do privaleged financial operations

    const FUNDS_ADMIN_ADDRESS: address = @0x728a91997c1eaec1138bb6aca4783f02b1f8f17f1b98342ce25e9180b7909420;

    const CLAIM_ADMIN_ADDRESS: address = @0x19aba60d1d9ccfe43d49609b5551e86f5d3187b10ea912dd4f8eeaa855280357;

    /// Caller is not the required admin
    const E_NOT_ADMIN: u64 = 1;

    public fun claim_admin_address(): address {
        CLAIM_ADMIN_ADDRESS
    }

    public fun funds_admin_address(): address {
        FUNDS_ADMIN_ADDRESS
    }

    public fun is_claim_admin(caller: &signer): bool {
        let caller_address = signer::address_of(caller);
        caller_address == CLAIM_ADMIN_ADDRESS
    }

    public fun assert_fund_or_claim_admin(caller: &signer) {
        assert!(is_fund_admin_or_deployer(caller) || is_claim_admin(caller), E_NOT_ADMIN);
    }

    public fun is_fund_admin_or_deployer(caller: &signer): bool {
        let caller_address = signer::address_of(caller);
        caller_address == FUNDS_ADMIN_ADDRESS || caller_address == @coin_address
    }

    public fun assert_fund_admin_or_deployer(caller: &signer) {
        assert!(is_fund_admin_or_deployer(caller), E_NOT_ADMIN);
    }

    #[test(
        deployer = @coin_address,
        user = @0x055
    )]
    fun test_admin(deployer: &signer, user: &signer) {
        assert!(is_fund_admin_or_deployer(deployer), 0);

        assert!(!is_fund_admin_or_deployer(user), 1);
    }
}
