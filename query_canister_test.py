import pprint
import requests
from ic.candid import encode, Types
import cbor2
from ic import Identity, Principal
import time
import base64


# Replace with your canister ID and method name
canister_id = "u4ezz-mqaaa-aaaan-qmrva-cai"
method_name = "http_request"

url = f"https://nns.ic0.app/api/v2/canister/{canister_id}/query"

# Define the recipient and amount arguments
recipient = Principal.from_str("ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae").bytes
amount = 11

# Prepare the query arguments as a dictionary and encode using Candid
args = {
    "recipient": recipient,
    "amount": amount
}

# Define the structure of the arguments
args_types = Types.Record({
    "recipient": Types.Principal,
    "amount": Types.Nat
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
    "request_type": "query",
    "sender": identity.sender().bytes,
    "sender_sig": identity.sign(encoded_http_request),
    "canister_id": Principal.from_str(canister_id).bytes,
    "ingress_expiry": int((time.time() + 60) * 1_000_000_000),
    "method_name": method_name,
    "arg": encoded_http_request
  }
}
# print("canid", cbor2.dumps(Principal.from_str(canister_id).bytes))
# Encode the entire query data to CBOR format
cbor_encoded_data = cbor2.dumps(query_data)

# Send the query request
response = requests.post(url, headers= headers, data=cbor_encoded_data)
print("res content\n", response.content, "\n")

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


if response_data.get("reply"):
  print("reply > arg\n", response_data["reply"]["arg"])
