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

    const EINSUFFICIENT_LOCKED: u64 = 1;
    const ENOTE_NOT_FOUND: u64 = 2;
    const ENOTE_ALREADY_SPENT: u64 = 3;
    const ENOT_NOTE_OWNER: u64 = 4;
    const EONLY_ADMIN_CAN_INIT: u64 = 5;

    public fun init_module(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @0xc0ffee, EONLY_ADMIN_CAN_INIT);

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

        coin::transfer<AptosCoin>(user, @0xc0ffee, amount);

        let vault = borrow_global_mut<Vault>(@0xc0ffee);

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
                commitment: vector::empty<u8>(), // off-chain keeps the true blob
                amount,
            },
        );
    }

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

        coin::transfer<AptosCoin>(&signer::borrow_address(caller), recipient, note_ref.amount);

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
        let vault = borrow_global<Vault>(@0xc0ffee);
        vault.total_locked
    }

    public fun get_note_count(): u64 acquires Vault {
        let vault = borrow_global<Vault>(@0xc0ffee);
        vector::length<Note>(&vault.notes) as u64
    }

    fun find_note_mut(
        notes: &mut vector<Note>,
        note_id: u64,
    ): (u64, &mut Note) {
        let i = 0;
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
}
