import requests
import json
from ic.candid import encode, Types

# Define the canister URL (replace with your actual canister URL)
canister_id = "br5f7-7uaaa-aaaaa-qaaca-cai"
url = f"http://localhost:4943/?canisterId={canister_id}"

headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
}

payload = {
    "recipient": "ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae",
    "amount": 10
}
candind_payload = encode(
    [
        {"type": Types.Text, "value": "ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae"},
        {"type": Types.Nat, "value": 10},
    ]
)

response = requests.post(url, headers=headers, data=candind_payload)
print(f"{response.status_code} - {response.text}")