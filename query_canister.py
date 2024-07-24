from ic import Principal
import requests
from ic.candid import encode, Types
import cbor2
import time


# define the canister URL (replace with your actual canister URL)
canister_id = "u4ezz-mqaaa-aaaan-qmrva-cai"
url = f"https://nns.ic0.app/api/v2/canister/{canister_id}/query"

headers = {
    "Content-Type": "application/cbor",
}

# Define the body data
body_data = {
    "recipient": "ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae",
    "amount": 11,
}

# Encode the body data correctly
body_type = Types.Record({
    "recipient": Types.Text,  # Convert Principal to Text
    "amount": Types.Nat,
})

encoded_body = encode([{
    "type": body_type,
    "value": body_data
}])

data = {
    "method": "POST",
    "url": "/",
    "headers": [
        ("Content-Type", "application/cbor"),
    ],
    "body": encoded_body
}

# Define the payload type
payload_type = Types.Record({
    "method": Types.Text,
    "url": Types.Text,
    "headers": Types.Vec(Types.Tuple(Types.Text, Types.Text)),
    "body": Types.Vec(Types.Nat8),  # Representing blob
})

encoded_args = encode([{"type": payload_type, "value": data}])

print("encoded args", encoded_args)
query_payload = {
    "content": {
        "request_type": "query",
        "sender": Principal.from_str("7s5ng-b62ou-yb365-kgm6b-baeoa-6zfrp-k2a2d-yqud3-3txbe-qdwci-iae").bytes,
        "ingress_expiry": int((time.time() + 60) * 1_000_000_000),  # 60 seconds from now in nanoseconds
        "canister_id": Principal.from_str(canister_id).bytes,
        "method_name": "http_request",
        "arg": encoded_args,
    },
}

print("query_payload", query_payload)

response = requests.post(
  url,
  headers=headers,
  data=cbor2.dumps(query_payload),
)
print(f"{response.status_code} - {response.text}")
