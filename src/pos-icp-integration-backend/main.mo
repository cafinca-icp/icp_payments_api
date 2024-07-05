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

// Importing local modules
import MainTypes "main.types";
import CkBtcLedger "canister:icrc1_ledger";

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

  system func postupgrade() {
    // Make sure we start to montitor transactions from the block set on deployment
    latestTransactionIndex := _startBlock;
  };
};
