module datatrust::data_marketplace {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use std::string::{String};
    use std::vector;
    
    const ERR_INSUFFICIENT_PAYMENT: u64 = 0;
    const ERR_NOT_AUTHORIZED: u64 = 1;
    const ERR_DATA_NOT_FOUND: u64 = 2;
    
    struct DataNFT has key, store {
        id: UID,
        name: String,
        description: String,
        walrus_blob_id: String,
        data_hash: String,
        data_type: String,
        sample_count: u64,
        price: u64,
        creator: address,
        created_at: u64,
        provenance: vector<String>,
        license_cid: String,
        rating: u64,
        purchase_count: u64,
    }
    
    struct PurchaseReceipt has key, store {
        id: UID,
        data_nft_id: address,
        buyer: address,
        purchased_at: u64,
        access_key: String,
    }
    
    struct Marketplace has key {
        id: UID,
        listings: Table<address, DataNFT>,
        fee_basis_points: u64,
        treasury: address,
        total_volume: u64,
    }
    
    struct AdminCap has key { id: UID; }
    
    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap { id: object::new(ctx) };
        let marketplace = Marketplace {
            id: object::new(ctx),
            listings: table::new(ctx),
            fee_basis_points: 250,
            treasury: tx_context::sender(ctx),
            total_volume: 0,
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(marketplace);
    }
    
    public entry fun mint_data_nft(
        name: String,
        description: String,
        walrus_blob_id: String,
        data_hash: String,
        data_type: String,
        sample_count: u64,
        price: u64,
        provenance: vector<String>,
        license_cid: String,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext
    ) {
        let data_nft = DataNFT {
            id: object::new(ctx),
            name, description, walrus_blob_id, data_hash,
            data_type, sample_count, price,
            creator: tx_context::sender(ctx),
            created_at: tx_context::epoch(ctx),
            provenance, license_cid, rating: 0, purchase_count: 0,
        };
        let data_id = object::id_address(&data_nft);
        table::add(&mut marketplace.listings, data_id, data_nft);
    }
    
    public entry fun purchase_data(
        data_id: address,
        payment: Coin<SUI>,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&marketplace.listings, data_id), ERR_DATA_NOT_FOUND);
        let data_nft = table::borrow_mut(&mut marketplace.listings, data_id);
        let price = data_nft.price;
        assert!(coin::value(&payment) >= price, ERR_INSUFFICIENT_PAYMENT);
        let fee = (price * marketplace.fee_basis_points) / 10000;
        let creator_share = price - fee;
        let fee_coin = coin::split(&mut payment, fee, ctx);
        let creator_coin = coin::split(&mut payment, creator_share, ctx);
        transfer::public_transfer(creator_coin, data_nft.creator);
        transfer::public_transfer(fee_coin, marketplace.treasury);
        if (coin::value(&payment) > 0) {
            transfer::public_transfer(payment, tx_context::sender(ctx));
        } else { coin::destroy_zero(payment); };
        data_nft.purchase_count = data_nft.purchase_count + 1;
        marketplace.total_volume = marketplace.total_volume + price;
        let receipt = PurchaseReceipt {
            id: object::new(ctx),
            data_nft_id: data_id,
            buyer: tx_context::sender(ctx),
            purchased_at: tx_context::epoch(ctx),
            access_key: generate_access_key(data_id, tx_context::sender(ctx)),
        };
        transfer::transfer(receipt, tx_context::sender(ctx));
    }
    
    fun generate_access_key(data_id: address, buyer: address): String {
        std::address::to_string(data_id)
    }
    
    public entry fun update_price(
        data_id: address,
        new_price: u64,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&marketplace.listings, data_id), ERR_DATA_NOT_FOUND);
        let data_nft = table::borrow_mut(&mut marketplace.listings, data_id);
        assert!(data_nft.creator == tx_context::sender(ctx), ERR_NOT_AUTHORIZED);
        data_nft.price = new_price;
    }
    
    public entry fun rate_data(
        data_id: address,
        score: u64,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext
    ) {
        assert!(score <= 500, 3);
        assert!(table::contains(&marketplace.listings, data_id), ERR_DATA_NOT_FOUND);
        let data_nft = table::borrow_mut(&mut marketplace.listings, data_id);
        if (data_nft.rating == 0) { data_nft.rating = score; }
        else { data_nft.rating = (data_nft.rating + score) / 2; }
    }
}