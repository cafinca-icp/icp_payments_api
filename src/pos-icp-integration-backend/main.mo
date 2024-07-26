// base modules
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";

//  external modules
import HttpParser "mo:http-parser";

// local modules
import CkBtcLedger "canister:icrc1_ledger";
import Types "Types";

shared (actorContext) actor class Main(_startBlock : Nat) {
  public shared composite query func http_request(rawReq : Types.HttpRequest) : async HttpParser.HttpResponse {
    var recipient = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai"); // dummy principal
    var amount = 0;

    let req = HttpParser.parse(rawReq);
    let { url } = req;
    let { path } = url;

    // get the request body and fill recipient and amount vars
    switch (req.body) {
      case (?body) {

        let check_transaction_input : ?Types.CheckTransactionInput = from_candid (body.original);
        switch (check_transaction_input) {
          case (?input) {
            recipient := input.recipient;
            amount := input.amount;

            Debug.print("recipient: " # Principal.toText(recipient));
            Debug.print("amount: " # Nat.toText(amount));

            var start : Nat = 0;
            var timeout : Nat64 = 240_000_000_000; // 4 minutes in nanoseconds

            var response = await CkBtcLedger.get_transactions({ start = start; length = 10 });
            Debug.print("n_transactions: " # Nat.toText(Array.size(response.transactions)));
            if (Array.size(response.transactions) > 0) {
              let t = response.transactions[response.transactions.size() - 1];

              var to = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai"); // dummy principal
              var txAmount = 0;
              var timestamp = t.timestamp;
              switch (t.kind) {
                case "burn" {
                  switch (t.burn) {
                    case (?burn) {
                      to := recipient;
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

              if (to == recipient and txAmount == amount and Nat64.fromIntWrap(Time.now()) - timestamp < timeout) {
                Debug.print("New transaction for an amount of " # Nat.toText(amount) # " ckBTC");

                return {
                  status_code = 200;
                  headers = [("content-type", "text/plain")];
                  body = Text.encodeUtf8("Transaction found");
                };
              };
              return {
                status_code = 404;
                headers = [("content-type", "text/plain")];
                body = Text.encodeUtf8("Transaction not found");
              };
            } else {
              return {
                status_code = 404;
                headers = [("content-type", "text/plain")];
                body = Text.encodeUtf8("Transactions not found");
              };
            };

            return {
              status_code = 200;
              headers = [("content-type", "text/plain")];
              body = Text.encodeUtf8("Request body parsed");
            };
          };
          case null {
            return {
              status_code = 400;
              headers = [("content-type", "text/plain")];
              body = Text.encodeUtf8("Invalid request body [TEST]");
            };
          };
        };
      };
      case null {
        return {
          status_code = 400;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8("Null request body");
        };
      };
    };

  };
};
