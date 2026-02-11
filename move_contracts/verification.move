module datatrust::verification {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use std::string::{String};
    use sui::hash;

    /// 验证证书
    struct VerificationCertificate has key, store {
        id: UID,
        data_nft_id: address,
        verifier: address,
        verification_type: String,
        result: String,
        score: u64,
        report_cid: String,
        timestamp: u64,
        valid_until: u64,
    }

    /// 验证者注册表
    struct VerifierRegistry has key {
        id: UID,
        verifiers: Table<address, u64>,
        certificates: Table<address, vector<address>>,
    }

    /// 管理员权限
    struct VerifierAdmin has key {
        id: UID,
    }

    const ERR_UNAUTHORIZED_VERIFIER: u64 = 0;
    const ERR_INVALID_SCORE: u64 = 1;

    /// 初始化
    fun init(ctx: &mut TxContext) {
        let admin = VerifierAdmin {
            id: object::new(ctx),
        };
        
        let registry = VerifierRegistry {
            id: object::new(ctx),
            verifiers: table::new(ctx),
            certificates: table::new(ctx),
        };
        
        transfer::transfer(admin, tx_context::sender(ctx));
        transfer::share_object(registry);
    }

    /// 注册验证者
    public entry fun register_verifier(
        _admin: &VerifierAdmin,
        verifier: address,
        initial_reputation: u64,
        registry: &mut VerifierRegistry
    ) {
        table::add(&mut registry.verifiers, verifier, initial_reputation);
    }

    /// 提交验证证书
    public entry fun submit_certificate(
        data_nft_id: address,
        verification_type: String,
        result: String,
        score: u64,
        report_cid: String,
        valid_duration: u64,
        registry: &mut VerifierRegistry,
        ctx: &mut TxContext
    ) {
        assert!(
            table::contains(&registry.verifiers, tx_context::sender(ctx)),
            ERR_UNAUTHORIZED_VERIFIER
        );
        assert!(score <= 100, ERR_INVALID_SCORE);

        let certificate = VerificationCertificate {
            id: object::new(ctx),
            data_nft_id,
            verifier: tx_context::sender(ctx),
            verification_type,
            result,
            score,
            report_cid,
            timestamp: tx_context::epoch(ctx),
            valid_until: tx_context::epoch(ctx) + valid_duration,
        };

        let cert_id = object::id_address(&certificate);
        
        if (table::contains(&registry.certificates, data_nft_id)) {
            let certs = table::borrow_mut(&mut registry.certificates, data_nft_id);
            vector::push_back(certs, cert_id);
        } else {
            table::add(&mut registry.certificates, data_nft_id, vector::singleton(cert_id));
        };

        transfer::share_object(certificate);
    }

    /// 计算数据质量分数
    public fun calculate_quality_score(
        sample_count: u64,
        consistency_score: u64,
        coverage_score: u64
    ): u64 {
        let sample_factor = if (sample_count > 10000) { 100 } else { (sample_count * 100) / 10000 };
        (sample_factor * 30 + consistency_score * 40 + coverage_score * 30) / 100
    }

    /// 验证数据哈希
    public fun verify_data_integrity(
        data: vector<u8>,
        expected_hash: vector<u8>
    ): bool {
        let computed_hash = hash::sha2_256(data);
        computed_hash == expected_hash
    }

    /// 获取验证者信誉
    public fun get_verifier_reputation(
        registry: &VerifierRegistry,
        verifier: address
    ): u64 {
        if (table::contains(&registry.verifiers, verifier)) {
            *table::borrow(&registry.verifiers, verifier)
        } else {
            0
        }
    }
}