import requests
from ic.candid import encode, Types
from random import randint

# Define the canister URL (replace with your actual canister URL)
canister_id = "br5f7-7uaaa-aaaaa-qaaca-cai"
url = f"http://localhost:4943/?canisterId={canister_id}"

headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
}

data = {
    "recipient": "ucuh4-xvinn-x5ac5-snla4-t65g2-5bpiw-awzag-znjhh-fzdek-cut2o-aae",
    "amount": 11,
}
payload_type = Types.Record({
    "recipient": Types.Principal,
    "amount": Types.Nat,
})

response = requests.post(
  url,
  headers=headers,
  data=encode([{"type": payload_type, "value": data}])
)
print(f"{response.status_code} - {response.text}")
