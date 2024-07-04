# POS ICP Integration

## Development environment setup

```bash
# yarn installation
npm install -g yarn

# dependencies installation
yarn install
```

## Run formatting and linting

```bash
npx prettier --write --plugin=prettier-plugin-motoko **/*.mo
```

## Running the project locally

If you want to test your project locally, you can use the following commands:

```bash
# Starts the replica, running in the background
dfx start --background

# Deploys your canisters to the replica and generates your candid interface
dfx deploy
```

Once the job completes, your application will be available at `http://localhost:4943?canisterId={asset_canister_id}`.

If you have made changes to your backend canister, you can generate a new candid interface with

```bash
npm run generate
```

at any time. This is recommended before starting the frontend development server, and will be run automatically any time you run `dfx deploy`.

## deploying ckbtc ledger

deploy ckbtcledger
dfx deploy --network local --specified-id mxzaz-hqaaa-aaaar-qaada-cai icrc1_ledger --argument '
(variant {
Init = record {
token_name = "Local ckBTC";
token_symbol = "LCKBTC";
minting_account = record {
owner = principal "7s5ng-b62ou-yb365-kgm6b-baeoa-6zfrp-k2a2d-yqud3-3txbe-qdwci-iae";
};
initial_balances = vec {
record {
record {
owner = principal "7s5ng-b62ou-yb365-kgm6b-baeoa-6zfrp-k2a2d-yqud3-3txbe-qdwci-iae";
};
100_000_000_000;
};
};
metadata = vec {};
transfer_fee = 10;
archive_options = record {
trigger_threshold = 2000;
num_blocks_to_archive = 1000;
controller_id = principal "7s5ng-b62ou-yb365-kgm6b-baeoa-6zfrp-k2a2d-yqud3-3txbe-qdwci-iae";
}
}
})
'
