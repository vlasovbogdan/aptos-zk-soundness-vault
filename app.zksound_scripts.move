// SPDX-License-Identifier: MIT
// Script helpers for interacting with 0xc0ffee::zk_soundness_vault.

module 0xc0ffee::zk_soundness_vault_scripts {
    use 0xc0ffee::zk_soundness_vault;

    /// Initialize the vault once (admin must be the module / vault admin).
    ///
    /// Transaction example:
    ///   - signer: admin account
    ///   - no extra arguments
    public entry fun init_vault(admin: &signer) {
        // calls the original module's initializer
        zk_soundness_vault::init_module(admin);
    }

    /// Deposit coins into the zk soundness vault with a commitment.
    ///
    /// Arguments:
    ///   - user: signer whose APT will be locked
    ///   - commitment: opaque bytes from your zk / FHE system
    ///   - amount: amount of APT to lock
    ///
    /// You typically construct `commitment` off-chain (hash, encrypted note, etc.).
    public entry fun deposit_with_commitment_script(
        user: &signer,
        commitment: vector<u8>,
        amount: u64,
    ) {
        zk_soundness_vault::deposit_with_commitment(user, commitment, amount);
    }

    /// Withdraw coins using an existing note.
    ///
    /// Arguments:
    ///   - caller: signer authorized (according to your off-chain logic) to spend `note_id`
    ///   - note_id: index / id of the note created by a previous deposit
    ///   - recipient: on-chain address that should receive the unlocked APT
    public entry fun withdraw_note_script(
        caller: &signer,
        note_id: u64,
        recipient: address,
    ) {
        zk_soundness_vault::withdraw_note(caller, note_id, recipient);
    }

    /// Convenience view: re-expose total locked APT so you can call
    /// this module instead of the base one if you prefer.
    public fun get_total_locked_via_script(): u64 {
        zk_soundness_vault::get_total_locked()
    }

    /// Convenience view: re-expose note count.
    public fun get_note_count_via_script(): u64 {
        zk_soundness_vault::get_note_count()
    }
}
