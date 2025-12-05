// SPDX-License-Identifier: MIT
// zk_soundness_vault: simple note-based vault with commitments over Aptos.

module 0xc0ffee::zk_soundness_vault {
    /// A simple vault that locks AptosCoin into "notes" with opaque commitments.
    /// Notes can later be withdrawn by the owner, tracked by events.
    use std::signer;
    use std::vector;
    use aptos_std::event;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

  const ADMIN_ADDR: address = @0xc0ffee;

    struct DepositEvent has copy, drop, store {
        owner: address,
        commitment: vector<u8>,
        amount: u64,
    }

    struct WithdrawalEvent has copy, drop, store {
        owner: address,
        note_id: u64,
        amount: u64,
    }
/// Return minimal metadata for a given note ID:
    /// (owner, amount, spent)
    public fun get_note_metadata(note_id: u64): (address, u64, bool) acquires Vault {
        let vault = borrow_global_mut<Vault>(ADMIN_ADDR);
        let (_, note_ref) = find_note_mut(&mut vault.notes, note_id);
        (note_ref.owner, note_ref.amount, note_ref.spent)
    }
    struct Note has copy, drop, store {
        id: u64,
        owner: address,
        commitment: vector<u8>,
        amount: u64,
        spent: bool,
    }

    struct Vault has key {
        next_note_id: u64,
        total_locked: u64,
        notes: vector<Note>,
        deposits: event::EventHandle<DepositEvent>,
        withdrawals: event::EventHandle<WithdrawalEvent>,
    }

    /// Error: vault does not have enough locked funds.
    const EINSUFFICIENT_LOCKED: u64 = 1;
    /// Error: note with the given ID does not exist.
    const ENOTE_NOT_FOUND: u64 = 2;
    /// Error: note was already spent.
    const ENOTE_ALREADY_SPENT: u64 = 3;
    /// Error: caller is not the owner of this note.
    const ENOT_NOTE_OWNER: u64 = 4;
    /// Error: only the admin address can call `init_module`.
    const EONLY_ADMIN_CAN_INIT: u64 = 5;

    public fun init_module(admin: &signer) {
            let admin_addr = signer::address_of(admin);
        assert!(admin_addr == ADMIN_ADDR, EONLY_ADMIN_CAN_INIT);

        move_to(
            admin,
            Vault {
                next_note_id: 0,
                total_locked: 0,
                notes: vector::empty<Note>(),
                deposits: event::new_event_handle<DepositEvent>(admin),
                withdrawals: event::new_event_handle<WithdrawalEvent>(admin),
            },
        );
    }

    public entry fun deposit_with_commitment(
        user: &signer,
        commitment: vector<u8>,
        amount: u64,
    ) acquires Vault {
        let user_addr = signer::address_of(user);

        coin::transfer<AptosCoin>(user, ADMIN_ADDR, amount);

        let vault = borrow_global_mut<Vault>(ADMIN_ADDR);

        let note_id = vault.next_note_id;
        vault.next_note_id = note_id + 1;
        vault.total_locked = vault.total_locked + amount;

        let note = Note {
            id: note_id,
            owner: user_addr,
            commitment,
            amount,
            spent: false,
        };
        vector::push_back(&mut vault.notes, note);

        event::emit_event<DepositEvent>(
            &mut vault.deposits,
            DepositEvent {
                owner: user_addr,
                               // We deliberately redact the on-chain commitment for privacy.
                // Off-chain indexers or the user keep the true blob.
                commitment: vector::empty<u8>(),
                amount,
            },
        );
    }
    /// Withdraw an unspent note to the given recipient address.
    ///
    /// Checks:
    /// - caller must be the note owner
    /// - note must exist
    /// - note must not be spent
    /// - vault must have enough locked funds
    ///
    /// Effects:
    /// - marks note as spent
    /// - decrements total_locked
    /// - transfers AptosCoin to recipient
    /// - emits WithdrawalEvent
    public entry fun withdraw_note(
        caller: &signer,
        note_id: u64,
        recipient: address,
    ) acquires Vault {
        let caller_addr = signer::address_of(caller);
        let vault = borrow_global_mut<Vault>(@0xc0ffee);

        let (idx, note_ref) = find_note_mut(&mut vault.notes, note_id);
        assert!(note_ref.owner == caller_addr, ENOT_NOTE_OWNER);
        assert!(!note_ref.spent, ENOTE_ALREADY_SPENT);
        assert!(vault.total_locked >= note_ref.amount, EINSUFFICIENT_LOCKED);

        note_ref.spent = true;
        vault.total_locked = vault.total_locked - note_ref.amount;

                coin::transfer<AptosCoin>(caller, recipient, note_ref.amount);

        event::emit_event<WithdrawalEvent>(
            &mut vault.withdrawals,
            WithdrawalEvent {
                owner: caller_addr,
                note_id,
                amount: note_ref.amount,
            },
        );

        // optional cleanup: keep vector shape simple by leaving the spent note in place
        let _ = idx; // silence unused warning
    }

       public fun get_total_locked(): u64 acquires Vault {
        let vault = borrow_global<Vault>(ADMIN_ADDR);
        vault.total_locked
    }

      public fun get_note_count(): u64 acquires Vault {
        let vault = borrow_global<Vault>(ADMIN_ADDR);
        vector::length<Note>(&vault.notes) as u64
    }

    fun find_note_mut(
        notes: &mut vector<Note>,
        note_id: u64,
    ): (u64, &mut Note) {
               let mut i = 0;
        let len = vector::length<Note>(notes);
        while (i < len) {
            let note_ref = vector::borrow_mut<Note>(notes, i);
            if (note_ref.id == note_id) {
                return (i as u64, note_ref);
            };
            i = i + 1;
        };
        abort ENOTE_NOT_FOUND;
    }
    // ------------------------------------------------------------------
    // Example flow (off-chain / frontend):
    //
    // 1. User calls `deposit_with_commitment(user, commitment, amount)`
    //    to lock AptosCoin and create a note.
    // 2. Off-chain, the user tracks their note ID and commitment.
    // 3. Later, the user calls `withdraw_note(caller, note_id, recipient)`
    //    to spend their note.
    // 4. Observers can track vault size via `get_total_locked`,
    //    `get_note_count`, or `get_vault_stats`.
    // ------------------------------------------------------------------
}

