import Principal "mo:base/Principal";
module Types {
  public type HeaderField = (Text, Text);

  public type HttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };

  public type HttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
  };

  public type CheckTransactionInput = {
    recipient : Principal;
    amount : Nat;
  };
};
