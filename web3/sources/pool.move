/// A flash loan that works for any Coin type
module lesson9::flash_lender {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct FlashLender<phantom T> has key {
        id: UID,
        to_lend: Balance<T>,
        fee: u64,
    }

    struct Receipt<phantom T> {
        flash_lender_id: ID,
        repay_amount: u64
    }

    struct AdminCap has key, store {
        id: UID,
        flash_lender_id: ID,
    }

    const ELoanTooLarge: u64 = 0;

    const EInvalidRepaymentAmount: u64 = 1;

    const ERepayToWrongLender: u64 = 2;

    const EAdminOnly: u64 = 3;

    const EWithdrawTooLarge: u64 = 4;

    // === Creating a flash lender ===
    public fun new<T>(to_lend: Balance<T>, fee: u64, ctx: &mut TxContext): AdminCap {
        let id = object::new(ctx);
        let flash_lender_id = object::uid_to_inner(&id);
        let flash_lender = FlashLender { id, to_lend, fee };
        
        transfer::share_object(flash_lender);

        AdminCap { id: object::new(ctx), flash_lender_id }
    }
    
    public entry fun create<T>(to_lend: Coin<T>, fee: u64, ctx: &mut TxContext) {
        let balance = coin::into_balance(to_lend);
        let admin_cap = new(balance, fee, ctx);

        transfer::public_transfer(admin_cap, tx_context::sender(ctx))
    }

    public fun loan<T>(
        self: &mut FlashLender<T>, amount: u64, ctx: &mut TxContext
    ): (Coin<T>, Receipt<T>) {
        let to_lend = &mut self.to_lend;
        assert!(balance::value(to_lend) >= amount, ELoanTooLarge);
        let loan = coin::take(to_lend, amount, ctx);
        let repay_amount = amount + self.fee;
        let receipt = Receipt { flash_lender_id: object::id(self), repay_amount };

        (loan, receipt)
    }

    public fun repay<T>(self: &mut FlashLender<T>, payment: Coin<T>, receipt: Receipt<T>) {
        let Receipt { flash_lender_id, repay_amount } = receipt;
        assert!(object::id(self) == flash_lender_id, ERepayToWrongLender);
        assert!(coin::value(&payment) == repay_amount, EInvalidRepaymentAmount);

        coin::put(&mut self.to_lend, payment)
    }

    public fun withdraw<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, amount: u64, ctx: &mut TxContext): Coin<T> {
        check_admin(self, admin_cap);

        let to_lend = &mut self.to_lend;
        assert!(balance::value(to_lend) >= amount, EWithdrawTooLarge);
        coin::take(to_lend, amount, ctx)
    }

    public entry fun deposit<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, coin: Coin<T>) {
        check_admin(self, admin_cap);
        coin::put(&mut self.to_lend, coin);
    }

    public entry fun update_fee<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, new_fee: u64) {
        check_admin(self, admin_cap);

        self.fee = new_fee
    }

    fun check_admin<T>(self: &FlashLender<T>, admin_cap: &AdminCap) {
        assert!(object::borrow_id(self) == &admin_cap.flash_lender_id, EAdminOnly);
    }


    public fun fee<T>(self: &FlashLender<T>): u64 {
        self.fee
    }

    public fun max_loan<T>(self: &FlashLender<T>): u64 {
        balance::value(&self.to_lend)
    }

    public fun repay_amount<T>(self: &Receipt<T>): u64 {
        self.repay_amount
    }

    public fun flash_lender_id<T>(self: &Receipt<T>): ID {
        self.flash_lender_id
    }
}
