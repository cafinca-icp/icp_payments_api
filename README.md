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

## Local Deployment

This is initially took from icpos example (and taking solana pay as reference) but with some twist. There are some improvements we want to implement in the future:

- Multitoken payment (ckbtc, icp, cketh, clt and many others)
- Enhanced transaction verification
- Multi instruction transactions (smart payments)

### Step 1: Start a local instance of the replica:

```bash
dfx start --clean --background
```

### Step 2: Deploy the Internet Identity canister:

Integration with the [Internet Identity](https://internetcomputer.org/internet-identity/) allows store owners to securely setup and manage their store. The Internet Identity canister is already deployed on the IC mainnet. For local development, you need to deploy it to your local instance of the IC.

```bash
dfx deploy --network local internet_identity
```

### Step 3: Save the current principal as a variable:

The principal will be used when deploying the ledger canister.

```bash
export OWNER=$(dfx identity get-principal)
```

### Step 3: Deploy the ckBTC ledger canister:

The responsibilities of the ledger canister is to keep track of token balances and handle token transfers.

The ckBTC ledger canister is already deployed on the IC mainnet. ckBTC implements the [ICRC-1](https://internetcomputer.org/docs/current/developer-docs/integrations/icrc-1/) token standard. For local development, we deploy the ledger for an ICRC-1 token mimicking the mainnet setup.

Take a moment to read the details of the call we are making below. Not only are we deploying the ledger canister, we are also:

- Deploying the canister to the same canister ID as the mainnet ledger canister. This is to make it easier to switch between local and mainnet deployments.
- Naming the token `Local ckBTC / LCKBTC`
- Setting the owner principal to the principal we saved in the previous step.
- Minting 100_000_000_000 tokens to the owner principal.
- Setting the transfer fee to 10 LCKBTC.

```bash
dfx deploy --network local --specified-id mxzaz-hqaaa-aaaar-qaada-cai icrc1_ledger --argument '
  (variant {
    Init = record {
      token_name = "Local ckBTC";
      token_symbol = "LCKBTC";
      minting_account = record {
        owner = principal "'${OWNER}'";
      };
      initial_balances = vec {
        record {
          record {
            owner = principal "'${OWNER}'";
          };
          100_000_000_000;
        };
      };
      metadata = vec {};
      transfer_fee = 10;
      archive_options = record {
        trigger_threshold = 2000;
        num_blocks_to_archive = 1000;
        controller_id = principal "'${OWNER}'";
      }
    }
  })
'
```

### Step 4: Deploy the index canister:

The index canister syncs the ledger transactions and indexes them by account.

```bash
dfx deploy --network local icrc1_index --argument 'opt variant { Init = record { ledger_id = principal "mxzaz-hqaaa-aaaar-qaada-cai"; } }'
```

### Step 5: Deploy the pos-icp-integration-backend canister:

The pos-icp-integration-backend canister manages the payment data generation and log a message when a payment is received.

The `--argument '(0)'` argument is used to initialize the canister with `startBlock` set to 0. This is used to tell the canister to start monitoring the ledger from block 0. When deploying to the IC mainnet, this should be set to the current block height to prevent the canister from processing old transactions.

```bash
dfx deploy --network local pos-icp-integration-backend --argument '(0)'
```

## Testing mainnet canister with Python

```bash
# create virtual environment
python3.11 -m venv .venv

# activate virtual environment
source .venv/bin/activate

# install dependencies
pip install -r requirements.txt

# run the test
python query_canister.py
```

source code of canister and expected responses can be reviewed at `src/pos-icp-integration-backend/main.mo`.
