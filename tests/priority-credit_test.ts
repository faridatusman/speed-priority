import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "Speed Priority: Admin can transfer administration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const admin = accounts.get('deployer')!;
        const newAdmin = accounts.get('wallet_1')!;
        const block = chain.mineBlock([
            Tx.contractCall('priority-credit', 'transfer-administration', 
                [types.principal(newAdmin.address)], 
                admin.address
            )
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "Speed Priority: Validator registration and management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const admin = accounts.get('deployer')!;
        const validator = accounts.get('wallet_1')!;
        
        const block = chain.mineBlock([
            Tx.contractCall('priority-credit', 'register-validator', 
                [types.principal(validator.address)], 
                admin.address
            )
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "Speed Priority: Project developer registration flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const admin = accounts.get('deployer')!;
        const validator = accounts.get('wallet_1')!;
        const developer = accounts.get('wallet_2')!;
        
        const registrationBlock = chain.mineBlock([
            Tx.contractCall('priority-credit', 'register-validator', 
                [types.principal(validator.address)], 
                admin.address
            ),
            Tx.contractCall('priority-credit', 'register-project-developer', 
                [
                    types.principal(developer.address), 
                    types.ascii("Renewable Energy Solutions")
                ], 
                validator.address
            )
        ]);
        
        assertEquals(registrationBlock.receipts.length, 2);
        registrationBlock.receipts[0].result.expectOk();
        registrationBlock.receipts[1].result.expectOk();
    }
});