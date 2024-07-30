import pprint
from ic.candid import Types
from ic import Identity, Principal, Client, Agent, encode
from pprint import pprint


# Replace with your canister ID and method name
canister_id = "jivd6-uaaaa-aaaar-qahbq-cai" # jivd6-uaaaa-aaaar-qahbq-cai | bd3sg-teaaa-aaaaa-qaaba-cai
method_name = "check_transaction"

url = f"https://nns.ic0.app/api/v2/canister/{canister_id}/call"
# url = f"http://127.0.0.1:4943/?canisterId={canister_id}"

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

iden = Identity(anonymous=True)
client = Client()
agent = Agent(iden, client)

res = agent.update_raw(
    canister_id=canister_id,
    method_name=method_name,
    arg=encoded_http_request,
)
value = res[0]["value"]
print("> res:\n")
print(res, "\n")

value["status"] = value.pop("_3475804314")
value["headers"] = value.pop("_1661489734")
value["body"] = "".join(chr(i) for i in value.pop("_1092319906"))
print("> parsed value:\n")
pprint(value)
