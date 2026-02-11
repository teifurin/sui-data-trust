#[test_only]
module datatrust::data_marketplace_tests {
    use sui::test_scenario;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::string;
    use datatrust::data_marketplace::{Self, DataNFT, Marketplace, PurchaseReceipt, AdminCap};

    #[test]
    fun test_mint_and_purchase() {
        let admin = @0x1;
        let creator = @0x2;
        let buyer = @0x3;
        
        let scenario = test_scenario::begin(admin);
        
        // 初始化合约
        test_scenario::next_tx(&mut scenario, admin);
        {
            data_marketplace::test_init(test_scenario::ctx(&mut scenario));
        };
        
        // 铸造 NFT
        test_scenario::next_tx(&mut scenario, creator);
        {
            let marketplace = test_scenario::take_shared<Marketplace>(&scenario);
            
            data_marketplace::mint_data_nft(
                string::utf8(b"Test Dataset"),
                string::utf8(b"Test Description"),
                string::utf8(b"blob:test"),
                string::utf8(b"hash123"),
                string::utf8(b"image"),
                1000,
                100,
                vector::empty(),
                string::utf8(b"MIT"),
                &mut marketplace,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(marketplace);
        };
        
        test_scenario::end(scenario);
    }
}