import IcpLedger "canister:icp_ledger_canister";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Principal "mo:base/Principal";

actor {
  type Tokens = {
    e8s : Nat64;
  };

  type TransferArgs = {
    amount : Tokens;
    recipient : Principal;
    toSubaccount : ?Blob;
  };

  public shared ({ caller }) func makeTransaction(args : TransferArgs) : async Result.Result<IcpLedger.Transaction, Text> {
    Debug.print(
      "Transferring "
      # debug_show (args.amount)
      # " tokens to principal "
      # debug_show (args.recipient)
      # " subaccount "
      # debug_show (args.toSubaccount)
    );

    let transferArgs : IcpLedger.TransferArgs = {
      // can be used to distinguish between transactions
      memo = 0;
      // the amount we want to transfer
      amount = args.amount;
      // the ICP ledger charges 10_000 e8s for a transfer
      fee = { e8s = 10_000 };
      // we are transferring from the canisters default subaccount, therefore we don't need to specify it
      from_subaccount = null;
      // we take the principal and subaccount from the arguments and convert them into an account identifier
      // TODO: review Principal and Subaccount definitions
      to = Blob.toArray(Principal.toLedgerAccount(args.recipient, args.toSubaccount));
      // a timestamp indicating when the transaction was created by the caller; if it is not specified by the caller then this is set to the current ICP time
      created_at_time = null;
    };

    try {
      // review .dfx/local/canisters/icp_ledger_canister/service.did.d.ts for further types explanation
      // TODO: send Plug needed input for QR to POS

      // get latest block transaction
      let latestBlocks = await IcpLedger.query_blocks({ start = 0; length = 1 });
      if (Array.size(latestBlocks.blocks) == 0) {
        return #err("No blocks found");
      };

      let latestBlock = latestBlocks.blocks[0];
      let transaction = latestBlock.transaction;

      /// Check transaction in block and review that amount is equal to args.amount
      switch (transaction.operation) {
        case (?operation) {
          if (operation.amount.e8s == args.amount.e8s) {
            // TODO: send HTTP POST request to POS to continue process
            return #ok(transaction);
          } else {
            return #err("Amount mismatch in transaction");
          };
        };
        case null {
          return #err("No operation found in transaction");
        };
      };
      // TODO: repeat process, keep checking (Timer cycle, etc.)
      return #ok(transaction);

    } catch (error : Error) {
      // catch any errors that might occur during the transfer
      return #err("Reject message: " # Error.message(error));
    };
  };
};
