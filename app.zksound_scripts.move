// SPDX-License-Identifier: MIT
// Script helpers for interacting with 0xc0ffee::zk_soundness_vault.

module 0xc0ffee::zk_soundness_vault_scripts {
    use 0xc0ffee::zk_soundness_vault;
    use std::vector;

    /// Initialize the vault once (admin must be the module / vault admin).
    ///
    /// Transaction example (CLI / wallet):
    ///   - function: 0xc0ffee::zk_soundness_vault_scripts::init_vault
    ///   - signer:  admin account at 0xc0ffee
    ///   - args:    none
    public entry fun init_vault(admin: &signer) {
        // calls the original module's initializer
               vault::init_module(admin);
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
              vault::deposit_with_commitment(user, commitment, amount);
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
              vault::withdraw_note(caller, note_id, recipient);
    }
    /// Convenience: withdraw a note directly back to the caller's own address.
    public entry fun withdraw_note_to_caller_script(
        caller: &signer,
        note_id: u64,
    ) {
        let recipient = signer::address_of(caller);
        vault::withdraw_note(caller, note_id, recipient);
    }
    /// Convenience view: return true if the vault has created any notes.
    public fun has_any_notes_via_script(): bool {
        vault::get_note_count() > 0
    }
    /// Convenience view: return true if no coins are currently locked.
    public fun is_vault_empty_via_script(): bool {
        vault::get_total_locked() == 0
    }

    /// Convenience view: re-expose total locked APT so you can call
    /// this module instead of the base one if you prefer.
    public fun get_total_locked_via_script(): u64 {
                vault::get_total_locked()
    }

    /// Convenience view: re-expose note count.
    public fun get_note_count_via_script(): u64 {
               vault::get_note_count()
    }
    /// Convenience: deposit with an empty commitment.
    /// Useful for simple demos where you don't yet have a zk/FHE commitment.
    public entry fun deposit_with_empty_commitment_script(
        user: &signer,
        amount: u64,
    ) {
        let commitment = vector::empty<u8>();
        vault::deposit_with_commitment(user, commitment, amount);
    }

}

