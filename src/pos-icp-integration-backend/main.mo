// Base modules
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Float "mo:base/Float";

//  External modules
import HttpParser "mo:http-parser";

// Local modules
import CkBtcIndex "canister:icrc1_index";
import Types "Types";

// Define the main actor class for the canister
actor Main {

  /**
   * Handles HTTP requests sent to the canister to verify transactions.
   * Parses the request, retrieves the latest transaction for a recipient, and verifies
   * whether it matches the expected amount and is within the timeout period.
   *
   * @param rawReq The raw HTTP request received by the canister.
   * @return An HTTP response indicating the result of the transaction check.
   */
  public shared func check_transaction(rawReq : Types.HttpRequest) : async HttpParser.HttpResponse {

    // Timeout period (4 minutes) in nanoseconds
    var timeout : Nat64 = 240_000_000_000;

    // Parse the incoming HTTP request
    let req = HttpParser.parse(rawReq);

    // Process the request body to retrieve transaction details
    switch (req.body) {
      case (?body) {
        // Convert the request body from Candid encoding
        let parsedTransactionInput : ?Types.CheckTransactionInput = from_candid (body.original);
        switch (parsedTransactionInput) {
          case (?input) {
            // Extract recipient and amount from the parsed input
            let recipientToCheck = input.recipient;
            let amountToCheck = input.amount;

            // Get the latest block
            let status = await CkBtcIndex.status();

            // Extract the number of blocks synced from the status
            let numBlocksSynced = status.num_blocks_synced;
            var startBlock : Nat = numBlocksSynced;

            // Fetch the latest transaction for the recipient from the ledger
            var lastTx = await CkBtcIndex.get_account_transactions({
              account = { owner = recipientToCheck; subaccount = null };
              start = ?startBlock;
              max_results = 1;
            });

            // Handle the retrieved transaction data
            switch (lastTx) {
              case (#Ok(transactions)) {
                let txs = transactions.transactions;

                if (Array.size(txs) > 0) {
                  let tx = txs[0].transaction;

                  // Verify if the transaction is a valid transfer
                  switch (tx.kind) {
                    case "transfer" {
                      switch (tx.transfer) {
                        case (?transfer) {
                          let txRecipient = transfer.to.owner;
                          let txAmount = Float.fromInt(transfer.amount);
                          let txTimestamp = tx.timestamp;
                          let txAge = Nat64.fromIntWrap(Time.now()) - txTimestamp;

                          // Check if the transaction matches the expected recipient, amount, and is within the timeout
                          if (txRecipient == recipientToCheck and txAmount == amountToCheck and txAge < timeout) {

                            // Return a response indicating that the transaction was found
                            return {
                              status_code = 200;
                              headers = [("content-type", "text/plain")];
                              body = Text.encodeUtf8("Transaction found");
                            };
                          } else {
                            // Return a response if the transaction amount is incorrect or too old
                            return {
                              status_code = 200;
                              headers = [("content-type", "text/plain")];
                              body = Text.encodeUtf8("Transaction amount incorrect or transaction too old");
                            };
                          };
                        };
                        case null {};
                      };
                    };
                    case _ {
                      // Handle invalid transaction type
                      return {
                        status_code = 400;
                        headers = [("content-type", "text/plain")];
                        body = Text.encodeUtf8("Invalid transaction type");
                      };
                    };
                  };

                  // Return a response if the transaction is not valid
                  return {
                    status_code = 404;
                    headers = [("content-type", "text/plain")];
                    body = Text.encodeUtf8("Transaction is not valid");
                  };
                } else {
                  // Return a response if no transactions were found
                  return {
                    status_code = 404;
                    headers = [("content-type", "text/plain")];
                    body = Text.encodeUtf8("No transactions found");
                  };
                };
              };
              case (#Err(error)) {
                // Log and return a response for internal errors
                return {
                  status_code = 500;
                  headers = [("content-type", "text/plain")];
                  body = Text.encodeUtf8("Internal server error: " # error.message);
                };
              };
            };

            // Return a response indicating that the request body was parsed successfully
            return {
              status_code = 200;
              headers = [("content-type", "text/plain")];
              body = Text.encodeUtf8("Request body parsed");
            };
          };
          case null {
            // Return a response for invalid request body
            return {
              status_code = 400;
              headers = [("content-type", "text/plain")];
              body = Text.encodeUtf8("Invalid request body");
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
