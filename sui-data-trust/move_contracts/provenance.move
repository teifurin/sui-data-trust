module datatrust::provenance {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use std::string::{String};
    use std::vector;

    /// 血统记录项 - 记录数据处理的一个步骤
    struct ProvenanceEntry has store, copy, drop {
        sequence: u64,
        operation: String,
        operator: address,
        timestamp: u64,
        description: String,
        proof_cid: String,
        tools_used: vector<String>,
        input_hash: String,
        output_hash: String,
    }

    /// 数据血统注册表 - 共享对象
    struct ProvenanceRegistry has key {
        id: UID,
        records: Table<ID, vector<ProvenanceEntry>>,
        verified_operators: Table<address, bool>,
    }

    /// 管理员权限
    struct ProvenanceAdmin has key {
        id: UID,
    }

    /// 初始化
    fun init(ctx: &mut TxContext) {
        let admin = ProvenanceAdmin {
            id: object::new(ctx),
        };
        
        let registry = ProvenanceRegistry {
            id: object::new(ctx),
            records: table::new(ctx),
            verified_operators: table::new(ctx),
        };
        
        transfer::transfer(admin, tx_context::sender(ctx));
        transfer::share_object(registry);
    }

    /// 添加血统记录
    public entry fun add_provenance(
        data_nft_id: ID,
        operation: String,
        description: String,
        proof_cid: String,
        tools_used: vector<String>,
        input_hash: String,
        output_hash: String,
        registry: &mut ProvenanceRegistry,
        ctx: &mut TxContext
    ) {
        let entry = ProvenanceEntry {
            sequence: get_next_sequence(registry, data_nft_id),
            operation,
            operator: tx_context::sender(ctx),
            timestamp: tx_context::epoch(ctx),
            description,
            proof_cid,
            tools_used,
            input_hash,
            output_hash,
        };

        if (table::contains(&registry.records, data_nft_id)) {
            let records = table::borrow_mut(&mut registry.records, data_nft_id);
            vector::push_back(records, entry);
        } else {
            let new_records = vector::singleton(entry);
            table::add(&mut registry.records, data_nft_id, new_records);
        }
    }

    /// 获取下一个序号
    fun get_next_sequence(registry: &ProvenanceRegistry, data_nft_id: ID): u64 {
        if (table::contains(&registry.records, data_nft_id)) {
            let records = table::borrow(&registry.records, data_nft_id);
            vector::length(records)
        } else {
            0
        }
    }

    /// 查询血统记录
    public fun get_provenance_history(
        registry: &ProvenanceRegistry,
        data_nft_id: ID
    ): vector<ProvenanceEntry> {
        if (table::contains(&registry.records, data_nft_id)) {
            *table::borrow(&registry.records, data_nft_id)
        } else {
            vector::empty()
        }
    }

    /// 验证血统完整性
    public fun verify_provenance_chain(
        registry: &ProvenanceRegistry,
        data_nft_id: ID,
        expected_final_hash: String
    ): bool {
        if (!table::contains(&registry.records, data_nft_id)) {
            return false
        };
        
        let records = table::borrow(&registry.records, data_nft_id);
        let len = vector::length(records);
        
        if (len == 0) {
            return false
        };

        // 验证链条连续性
        let i = 1;
        while (i < len) {
            let prev = vector::borrow(records, i - 1);
            let curr = vector::borrow(records, i);
            if (prev.output_hash != curr.input_hash) {
                return false
            };
            i = i + 1;
        };

        // 验证最终哈希
        let last = vector::borrow(records, len - 1);
        last.output_hash == expected_final_hash
    }

    /// 添加验证者
    public entry fun add_verified_operator(
        _admin: &ProvenanceAdmin,
        operator: address,
        registry: &mut ProvenanceRegistry
    ) {
        table::add(&mut registry.verified_operators, operator, true);
    }
}