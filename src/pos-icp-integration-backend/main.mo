// Importing base modules
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";

// Importing local modules
import MainTypes "main.types";
import CkBtcLedger "canister:icrc1_ledger";

import Types "Types";

/**
*  This actor is responsible for:
*  - Storing merchant information
*  - Monitoring the ledger for new transactions
*  - Notifying merchants of new transactions
*
*  `_startBlock` is the block number to start monitoring transactions from.
*/
shared (actorContext) actor class Main(_startBlock : Nat) {

  private stable var merchantStore : Trie.Trie<Text, MainTypes.Merchant> = Trie.empty();
  private stable var latestTransactionIndex : Nat = 0;
  private var logData = Buffer.Buffer<Text>(0);

  /**
    *  Get the merchant's information
    */
  public query (context) func getMerchant() : async MainTypes.Response<MainTypes.Merchant> {
    let caller : Principal = context.caller;

    switch (Trie.get(merchantStore, merchantKey(Principal.toText(caller)), Text.equal)) {
      case (?merchant) {
        {
          status = 200;
          status_text = "OK";
          data = ?merchant;
          error_text = null;
        };
      };
      case null {
        {
          status = 404;
          status_text = "Not Found";
          data = null;
          error_text = ?("Merchant with principal ID: " # Principal.toText(caller) # " not found.");
        };
      };
    };
  };

  /**
    * Update the merchant's information
    */
  public shared (context) func updateMerchant(merchant : MainTypes.Merchant) : async MainTypes.Response<MainTypes.Merchant> {

    let caller : Principal = context.caller;
    merchantStore := Trie.replace(
      merchantStore,
      merchantKey(Principal.toText(caller)),
      Text.equal,
      ?merchant,
    ).0;
    {
      status = 200;
      status_text = "OK";
      data = ?merchant;
      error_text = null;
    };
  };

  public query (context) func getTxURL(amount : Nat) : async Text {
    let recipient : Principal = context.caller;
    return "ckbtc:" # Principal.toText(recipient) # "?amount" # Nat.toText(amount);
  };

  /**
  * Get latest log items. Log output is capped at 100 items.
  */
  public query func getLogs() : async [Text] {
    Buffer.toArray(logData);
  };

  /**
    * Log a message. Log output is capped at 100 items.
    */
  private func log(text : Text) {
    Debug.print(text);
    logData.reserve(logData.size() + 1);
    logData.insert(0, text);
    // Cap the log at 100 items
    if (logData.size() == 100) {
      let _x = logData.removeLast();
    };
    return;
  };

  /**
    * Generate a Trie key based on a merchant's principal ID
    */
  private func merchantKey(x : Text) : Trie.Key<Text> {
    return { hash = Text.hash(x); key = x };
  };

  /**
    * Check for new transactions and notify the merchant if a new transaction is found.
    * This function is called by the global timer.
    */
  system func timer(setGlobalTimer : Nat64 -> ()) : async () {
    let next = Nat64.fromIntWrap(Time.now()) + 20_000_000_000; // 20 seconds
    setGlobalTimer(next);
    await checkTx();
  };

  /**
    * Check if a new transaction is found in the ledger.
    */
  private func checkTx() : async () {
    var start : Nat = _startBlock;
    if (latestTransactionIndex > 0) {
      start := latestTransactionIndex + 1;
    };

    var response = await CkBtcLedger.get_transactions({
      start = start;
      length = 1;
    });

    if (Array.size(response.transactions) > 0) {
      latestTransactionIndex := start;

      if (response.transactions[0].kind == "transfer") {
        let t = response.transactions[0];
        switch (t.transfer) {
          case (?transfer) {
            let to = transfer.to.owner;
            let amount = transfer.amount;
            // TODO: Check that the transaction is for the required amount ( idea: pass the amount to
            // the context and each machine or merchant can have only one concurrent tx, it could help
            // merchants to do onchain analysis)
            switch (Trie.get(merchantStore, merchantKey(Principal.toText(to)), Text.equal)) {
              case (?merchant) {
                log("New transaction for an amount of " # Nat.toText(amount) # "CkBtc");

                // TODO: move post-message logic after successful transaction
                //1. DECLARE IC MANAGEMENT CANISTER
                //We need this so we can use it to make the HTTP request
                let ic : Types.IC = actor ("aaaaa-aa");

                //2. SETUP ARGUMENTS FOR HTTP GET request

                // 2.1 Setup the URL and its query parameters
                //This URL is used because it allows us to inspect the HTTP request sent from the canister
                let host : Text = "127.0.0.1";
                let url = "https://127.0.0.1:5001/api/data"; //HTTP that accepts IPV6

                // 2.2 prepare headers for the system http_request call

                //idempotency keys should be unique so we create a function that generates them.
                let idempotency_key : Text = generateUUID();
                let request_headers = [
                  { name = "Host"; value = host # ":443" },
                  { name = "User-Agent"; value = "http_post_sample" },
                  { name = "Content-Type"; value = "application/json" },
                  { name = "Idempotency-Key"; value = idempotency_key },
                ];

                // The request body is an array of [Nat8] (see Types.mo) so we do the following:
                // 1. Write a JSON string
                // 2. Convert ?Text optional into a Blob, which is an intermediate reprepresentation before we cast it as an array of [Nat8]
                // 3. Convert the Blob into an array [Nat8]
                let request_body_json : Text = "{ \"name\" : \"Grogu\", \"force_sensitive\" : \"true\" }";
                let request_body_as_Blob : Blob = Text.encodeUtf8(request_body_json);
                let request_body_as_nat8 : [Nat8] = Blob.toArray(request_body_as_Blob); // e.g [34, 34,12, 0]

                // 2.3 The HTTP request
                let http_request : Types.HttpRequestArgs = {
                  url = url;
                  max_response_bytes = null; //optional for request
                  headers = request_headers;
                  //note: type of `body` is ?[Nat8] so we pass it here as "?request_body_as_nat8" instead of "request_body_as_nat8"
                  body = ?request_body_as_nat8;
                  method = #post;
                  // transform = ?transform_context;
                };

                //3. ADD CYCLES TO PAY FOR HTTP REQUEST

                //IC management canister will make the HTTP request so it needs cycles
                //See: https://internetcomputer.org/docs/current/motoko/main/cycles

                //The way Cycles.add() works is that it adds those cycles to the next asynchronous call
                //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
                Cycles.add(230_850_258_000);

                //4. MAKE HTTPS REQUEST AND WAIT FOR RESPONSE
                //Since the cycles were added above, we can just call the IC management canister with HTTPS outcalls below
                let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);
                Debug.print("HTTP request sent!");
              };

              case null {
                // No action required if merchant not found
              };
            };
          };
          case null {
            // No action required if transfer is null
          };
        };
      };
    };
  };

  // PRIVATE HELPER FUNCTION
  //Helper method that generates a Universally Unique Identifier
  //this method is used for the Idempotency Key used in the request headers of the POST request.
  //For the purposes of this exercise, it returns a constant, but in practice it should return unique identifiers
  func generateUUID() : Text {
    "UUID-123456789";
  };

  system func postupgrade() {
    // Make sure we start to montitor transactions from the block set on deployment
    latestTransactionIndex := _startBlock;
  };
};
