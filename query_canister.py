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

data = {
    "method": "POST",
    "url": "/",
    "headers": [
        ("Content-Type", "application/cbor"),
    ],
    "body": {
        "recipient": "ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae",
        "amount": 11,
    },
}
payload_type = Types.Record({
    "method": Types.Text,
    "url": Types.Text,
    "headers": Types.Vec(Types.Tuple(Types.Text)),
    "body": Types.Record({
        "recipient": Types.Principal,
        "amount": Types.Nat,
    })
})
encoded_args = encode([{"type": payload_type, "value": data}])
query_payload = {
    "content": {
        "request_type": "query",
        "sender": "7s5ng-b62ou-yb365-kgm6b-baeoa-6zfrp-k2a2d-yqud3-3txbe-qdwci-iae",
        "ingress_expiry": int((time.time() + 60) * 1_000_000_000),  # 60 seconds from now in nanoseconds
        "canister_id": canister_id,
        "method_name": "http_request",
        "arg": encoded_args,
    },
}

response = requests.post(
  url,
  headers=headers,
  data=cbor2.dumps(query_payload),
)
print(f"{response.status_code} - {response.text}")
