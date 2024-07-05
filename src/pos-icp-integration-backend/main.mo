// base modules
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import { setTimer; recurringTimer } "mo:base/Timer";
import Blob "mo:base/Blob";

// local modules
import CkBtcLedger "canister:icrc1_ledger";

import Types "Types";

shared (actorContext) actor class Main(_startBlock : Nat) {
  private stable var latestTransactionIndex : Nat = 0;

  // function to transform the response
  private func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
    let transformed : Types.CanisterHttpResponsePayload = {
      status = raw.response.status;
      body = raw.response.body;
      headers = [
        {
          name = "Content-Security-Policy";
          value = "default-src 'self'";
        },
        {
          name = "Referrer-Policy";
          value = "strict-origin";
        },
        {
          name = "Permissions-Policy";
          value = "geolocation=(self)";
        },
        {
          name = "Strict-Transport-Security";
          value = "max-age=63072000";
        },
        {
          name = "X-Frame-Options";
          value = "DENY";
        },
        {
          name = "X-Content-Type-Options";
          value = "nosniff";
        },
      ];
    };
    transformed;
  };

  private func qrPayloadNotify(qrPayload : Text) : async () {
    //1. DECLARE IC MANAGEMENT CANISTER
    //We need this so we can use it to make the HTTP request
    let ic : Types.IC = actor ("aaaaa-aa");

    //2. SETUP ARGUMENTS FOR HTTP GET request

    // 2.1 Setup the URL and its query parameters
    //This URL is used because it allows us to inspect the HTTP request sent from the canister
    let host : Text = "127.0.0.1";
    let url = "https://httpbin.org/post"; //HTTP that accepts IPV6

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
    let request_body_json : Text = "{ \"qrPayload\" : \"" # qrPayload # "\" }";
    let request_body_as_Blob : Blob = Text.encodeUtf8(request_body_json);
    let request_body_as_nat8 : [Nat8] = Blob.toArray(request_body_as_Blob); // e.g [34, 34,12, 0]

    // 2.2.1 Transform context
    let transform_context : Types.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    // 2.3 The HTTP request
    let http_request : Types.HttpRequestArgs = {
      url = url;
      max_response_bytes = null; //optional for request
      headers = request_headers;
      //note: type of `body` is ?[Nat8] so we pass it here as "?request_body_as_nat8" instead of "request_body_as_nat8"
      body = ?request_body_as_nat8;
      method = #post;
      transform = ?transform_context;
    };

    //3. ADD CYCLES TO PAY FOR HTTP REQUEST

    //IC management canister will make the HTTP request so it needs cycles
    //See: https://internetcomputer.org/docs/current/motoko/main/cycles

    //The way Cycles.add() works is that it adds those cycles to the next asynchronous call
    //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
    // TODO: compute eficient cycles
    Cycles.add(230_850_258_000);

    //4. MAKE HTTPS REQUEST AND WAIT FOR RESPONSE
    //Since the cycles were added above, we can just call the IC management canister with HTTPS outcalls below
    let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);
    Debug.print("HTTP request sent!");

    let response_body : Blob = Blob.fromArray(http_response.body);
    let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
      case (null) { "No value returned" };
      case (?y) { y };
    };

    Debug.print("Response body: " # decoded_text);
  };

  private func getTxURL(amount : Nat) : async Text {
    let recipient = "ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae";
    return "ckbtc:" # recipient # "?amount=" # Nat.toText(amount);
  };

  /**
    * Check if a new transaction is found in the ledger.
    */
  private func checkTx() : async () {
    var start : Nat = 0;
    if (latestTransactionIndex > 0) {
      start := latestTransactionIndex + 1;
    };

    var response = await CkBtcLedger.get_transactions({
      start = start;
      length = 10;
    });

    Debug.print("n_transactions: " # Nat.toText(Array.size(response.transactions)));
    if (Array.size(response.transactions) > 0) {
      latestTransactionIndex := start;

      if (response.transactions[0].kind == "mint") {
        let t = response.transactions[0];
        switch (t.mint) {
          case (?mint) {
            let to = mint.to.owner;
            let amount = mint.amount;
            // TODO: Check that the transaction is for the required amount ( idea: pass the amount to
            // the context and each machine or merchant can have only one concurrent tx, it could help
            // merchants to do onchain analysis)

            if (Principal.toText(to) == "ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae") {
              Debug.print("New transaction for an amount of " # Nat.toText(amount) # " ckBTC");

              // TODO: post message of successful transaction to POS
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

  //PRIVATE HELPER FUNCTION
  //Helper method that generates a Universally Unique Identifier
  //this method is used for the Idempotency Key used in the request headers of the POST request.
  //For the purposes of this exercise, it returns a constant, but in practice it should return unique identifiers
  func generateUUID() : Text {
    "UUID-123456789";
  };

  public func initTransaction(amount : Nat) : async () {
    let qrPayload = await getTxURL(amount);
    Debug.print("QR Payload: " # qrPayload);

    await qrPayloadNotify(qrPayload);

    // start the timer to check for new transactions
    ignore setTimer<system>(
      #seconds 10,
      func() : async () {
        ignore recurringTimer<system>(#seconds 10, checkTx);
        await checkTx();
      },
    );
  };
};
