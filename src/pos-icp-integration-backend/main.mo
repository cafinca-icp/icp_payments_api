// base modules
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Blob "mo:base/Blob";

// local modules
import CkBtcLedger "canister:icrc1_ledger";

shared (actorContext) actor class Main(_startBlock : Nat) {
  type HttpResponse = {
    status_code : Nat16;
    headers : [Text];
    body : Blob;
  };
  // TODO: review that we must be compliant ICRC2
  // - currently we use ICRC1, review if we can move to ICRC2.

  /*
    * Check if a new transaction is found in the ledger.
  */
  public func checkTx(recipient : Text, amount : Nat) : async HttpResponse {
    var start : Nat = 0;
    var timeout : Nat64 = 240_000_000_000; // 4 minutes in nanoseconds

    var response = await CkBtcLedger.get_transactions({ start = start; length = 10 });
    Debug.print("n_transactions: " # Nat.toText(Array.size(response.transactions)));
    if (Array.size(response.transactions) > 0) {
      let t = response.transactions[response.transactions.size() - 1];
      // Debug.print("transaction type: " # t.kind);

      var to = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai"); // dummy principal
      var txAmount = 0;
      var timestamp = t.timestamp;
      switch (t.kind) {
        case "burn" {
          switch (t.burn) {
            case (?burn) {
              to := Principal.fromText(recipient);
              txAmount := burn.amount;
            };
            case null {};
          };
        };
        case "mint" {
          switch (t.mint) {
            case (?mint) {
              to := mint.to.owner;
              txAmount := mint.amount;
            };
            case null {};
          };
        };
        case "transfer" {
          switch (t.transfer) {
            case (?transfer) {
              to := transfer.to.owner;
              txAmount := transfer.amount;
            };
            case null {};
          };
        };
        case _ {};
      };

      // debugging logs
      // Debug.print("to       : " # Principal.toText(to));
      // Debug.print("recipient: " # recipient);
      // Debug.print("txAmount : " # Int.toText(txAmount));
      // Debug.print("amount   : " # Nat.toText(amount));
      // Debug.print("now      : " # Nat64.toText(Nat64.fromIntWrap(Time.now())));
      // Debug.print("timestamp: " # Nat64.toText(timestamp));
      // Debug.print("timeout  : " # Nat64.toText(timeout));

      if (Principal.toText(to) == recipient and txAmount == amount and Nat64.fromIntWrap(Time.now()) - timestamp < timeout) {
        Debug.print("New transaction for an amount of " # Nat.toText(amount) # " ckBTC");

        return { status_code = 200; headers = []; body = Text.encodeUtf8("Transaction found") };
      };
      return { status_code = 404; headers = []; body = Text.encodeUtf8("Transaction not found") };
    } else {
      return { status_code = 404; headers = []; body = Text.encodeUtf8("Transactions not found") };
    };
  };
};
