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
    toPrincipal : Principal;
    toSubaccount : ?Blob;
  };

  public query func InitiateTx(recipient : Text, amount : Nat) : async Text {
    let transferArgs : IcpLedger.TransferArgs = {
      // can be used to distinguish between transactions
      memo = 0;
      // the amount we want to transfer
      amount = amount; // transform to e8s
      // the ICP ledger charges 10_000 e8s for a transfer
      fee = { e8s = 10_000 };
      // we are transferring from the canisters default subaccount, therefore we don't need to specify it
      from_subaccount = null;
      // we take the principal and subaccount from the arguments and convert them into an account identifier
      to = Blob.toArray(Principal.toLedgerAccount(args.toPrincipal, args.toSubaccount)); // recipient
      // a timestamp indicating when the transaction was created by the caller; if it is not specified by the caller then this is set to the current ICP time
      created_at_time = null;
    };
  };

  private func Timer() {
    checkTx();
  };

  private func checkTx(recipient : Text, amount : Nat) {
    // check amount and recipient
    // if success -> send notification to POS
  };
};
