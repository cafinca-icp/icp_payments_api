import pprint
import requests
from ic.candid import encode, Types
import cbor2
from ic import Identity, Principal, decode
import time
from pprint import pprint


# Replace with your canister ID and method name
canister_id = "jivd6-uaaaa-aaaar-qahbq-cai"
method_name = "check_transaction"

url = f"https://nns.ic0.app/api/v2/canister/{canister_id}/call"

# Define the recipient and amount arguments
recipient = Principal.from_str("f6fvu-25ywu-a2oez-2oc7d-3thap-r5d6f-uez55-ltn4b-tw4yn-fqu66-aae").bytes
amount = 0.0000015

# Prepare the query arguments as a dictionary and encode using Candid
args = {
    "recipient": recipient,
    "amount": amount
}

# Define the structure of the arguments
args_types = Types.Record({
    "recipient": Types.Principal,
    "amount": Types.Float64,
})

# Encode the arguments using Candid
encoded_args = encode([{"type": args_types, "value": args}])

headers = {"Content-Type": "application/cbor"}

# Prepare the HttpRequest structure
http_values = {
    "url": "/",
    "method": "POST",
    "headers": [
      ("Content-Type", "application/cbor"),
      ],
    "body": encoded_args
}

#print("http req", http_values)

http_types = Types.Record({
  "url": Types.Text,
  "method": Types.Text,
  "headers": Types.Vec(Types.Tuple(Types.Text, Types.Text)),
  "body": Types.Vec(Types.Nat8),  # Representing blob
})

# Encode the HttpRequest using Candid
encoded_http_request = encode([{
  "type": http_types,
  "value": http_values
}])

# print("encoded http req", encoded_http_request)

# anon sender
identity = Identity(
  type="ed25519",  # ed25519 | secp256k1
  anonymous=True,
)

# Prepare the query data
query_data = {
  "content":{
    "request_type": "call",
    "sender": identity.sender().bytes,
    "sender_sig": identity.sign(encoded_http_request),
    "canister_id": Principal.from_str(canister_id).bytes,
    "ingress_expiry": int((time.time() + 60) * 1_000_000_000),
    "method_name": method_name,
    "arg": encoded_http_request
  }
}
# print("candid", cbor2.dumps(Principal.from_str(canister_id).bytes))
# Encode the entire query data to CBOR format
cbor_encoded_data = cbor2.dumps(query_data)

print("encoded data", cbor_encoded_data)
print("headers", headers)
print("url", url)

# Send the query request
response = requests.post(url, headers= headers, data=cbor_encoded_data)
print("res content\n", response.content, "\n")
print("res", response)
# Decode the response from CBOR format
response_data = cbor2.loads(response.content)

# Print the response
print("res data\n", response_data, "\n")

if response_data.get("status") == "rejected":
  print(f"status        : {response_data['status']}")
  print(f"error_code    : {response_data['error_code']}")
  print(f"reject_code   : {response_data['reject_code']}")
  print(f"reject_message: {response_data['reject_message']}")
  print(f"signatures    : \n{pprint.pformat(response_data['signatures'][0])}")


if response_data.get("status") == "replied":
  print("status\n", response_data["status"], "\n")
  print("reply\n", response_data["reply"], "\n")
  print("signatures\n", response_data["signatures"], "\n")

  print("arg")
  arg = decode(response_data["reply"]["arg"])[0]

  # rename the keys
  arg["value"]["status"] = arg["value"].pop("_3475804314")
  arg["value"]["headers"] = arg["value"].pop("_1661489734")
  arg["value"]["body"] = arg["value"].pop("_1092319906")

  arg["value"]["body"] = "".join(chr(i) for i in arg["value"]["body"])
  pprint(arg)
