import requests
from ic.candid import encode, Types
import cbor2
from ic import Identity, Principal
import time


# Replace with your canister ID and method name
canister_id = "u4ezz-mqaaa-aaaan-qmrva-cai"
method_name = "http_request"

url = f"https://nns.ic0.app/api/v2/canister/{canister_id}/query"

# Define the recipient and amount arguments
recipient = "ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae"
amount = 11

# Prepare the query arguments as a dictionary and encode using Candid
args = {
    "recipient": recipient,
    "amount": amount
}

# Define the structure of the arguments
args_types = Types.Record({
    "recipient": Types.Text,
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

#print("encoded http req", encoded_http_request)

# anon sender
identity = Identity(anonymous=True)


# Prepare the query data
query_data = {
  "content":{
    "request_type": "query",
    "sender": identity.sender().bytes,
    "canister_id": Principal.from_str(canister_id).bytes,
    "ingress_expiry": int((time.time() + 60) * 1_000_000_000),
    "method_name": method_name,
    "arg": encoded_http_request
  }
}
# print("canid", cbor2.dumps(Principal.from_str(canister_id).bytes))
# Encode the entire query data to CBOR format
cbor_encoded_data = cbor2.dumps(query_data)

# Define the URL for the query call
url = f"https://ic0.app/api/v2/canister/{canister_id}/query"

# Send the query request
response = requests.post(url, headers= headers, data=cbor_encoded_data)
print("res content", response.content)
print("=========")
print("res",response)

# Decode the response from CBOR format
response_data = cbor2.loads(response.content)

# Print the response
print("=========")

print("res data", response_data)
print("=========")

print(cbor2.loads(response_data["reply"]["arg"]))
