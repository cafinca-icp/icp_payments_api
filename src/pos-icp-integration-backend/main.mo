// base modules
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Float "mo:base/Float";

//  external modules
import HttpParser "mo:http-parser";

// local modules
import CkBtcIndex "canister:icrc1_index";
import Types "Types";

shared (actorContext) actor class Main(_startBlock : Nat) {
  public shared func http_request(rawReq : Types.HttpRequest) : async HttpParser.HttpResponse {
    var recipient = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai"); // dummy principal
    var amount = 0.0;

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
            Debug.print("amount: " # Float.toText(amount));

            var timeout : Nat64 = 240_000_000_000; // 4 minutes in nanoseconds

            // TODO:: loop over the transactions until we find the transaction for the given recipient and amount
            var response = await CkBtcIndex.get_account_transactions({
              account = { owner = recipient; subaccount = null };
              start = ?0;
              max_results = 10;
            });
            #Ok { transactions; oldest_tx_id } := response;

            if (Array.size(transactions) > 0) {
              let t = response.transactions[response.transactions.size() - 1];

              var to = Principal.fromText("un4fu-tqaaa-aaaab-qadjq-cai"); // dummy principal
              var txAmount = 0.0;
              var timestamp = t.timestamp;
              switch (t.kind) {
                case "burn" {
                  switch (t.burn) {
                    case (?burn) {
                      to := recipient;
                      txAmount := Float.fromInt(burn.amount);
                    };
                    case null {};
                  };
                };
                case "mint" {
                  switch (t.mint) {
                    case (?mint) {
                      to := mint.to.owner;
                      txAmount := Float.fromInt(mint.amount);
                    };
                    case null {};
                  };
                };
                case "transfer" {
                  switch (t.transfer) {
                    case (?transfer) {
                      to := transfer.to.owner;
                      txAmount := Float.fromInt(transfer.amount);
                    };
                    case null {};
                  };
                };
                case _ {};
              };

              Debug.print("amount: " # Float.toText(amount));
              Debug.print("txAmount: " # Float.toText(txAmount));

              if (to == recipient and txAmount == amount and Nat64.fromIntWrap(Time.now()) - timestamp < timeout) {
                Debug.print("New transaction for an amount of " # Float.toText(amount) # " ckBTC");

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
