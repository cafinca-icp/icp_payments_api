import Debug "mo:base/Debug";
import Nat16 "mo:base/Nat16";
import Option "mo:base/Option";
import F "mo:format";
import HttpParser "mo:http-parser";

module {
  public func debugRequestParser(req : HttpParser.ParsedHttpRequest) : () {
    Debug.print(F.format("Method ({})", [#text(req.method)]));
    Debug.print("\n");

    let { host; port; protocol; path; queryObj; anchor; original = url } = req.url;

    Debug.print(F.format("URl ({})", [#text(url)]));

    Debug.print(F.format("Protocol ({})", [#text(protocol)]));

    Debug.print(F.format("Host ({})", [#text(host.original)]));
    Debug.print(F.format("Host ({})", [#textArray(host.array)]));

    Debug.print(F.format("Port ({})", [#num(Nat16.toNat(port))]));

    Debug.print(F.format("Path ({})", [#text(path.original)]));
    Debug.print(F.format("Path ({})", [#textArray(path.array)]));

    for ((key, value) in queryObj.trieMap.entries()) {
      Debug.print(F.format("Query ({}: {})", [#text(key), #text(value)]));
    };

    Debug.print(F.format("Anchor ({})", [#text(anchor)]));

    Debug.print("\n");
    Debug.print("Headers");
    let { keys = headerKeys; get = getHeader } = req.headers;
    for (headerKey in headerKeys.vals()) {
      let values = Option.get(getHeader(headerKey), []);
      Debug.print(F.format("Header ({}: {})", [#text(headerKey), #textArray(values)]));
    };

    Debug.print("\n");
    Debug.print("Body");

    switch (req.body) {
      case (?body) {

        Debug.print("Form");
        let { keys; get = getField; files = getFiles; fileKeys } = body.form;
        for (name in keys.vals()) {
          let values = Option.get(getField(name), []);
          Debug.print(
            F.format(
              "Field ({}: {})",
              [#text(name), #textArray(values)],
            )
          );
        };

        for (name in fileKeys.vals()) {
          switch (getFiles(name)) {
            case (?files) {
              for (file in files.vals()) {

                Debug.print(
                  F.format(
                    "File ({}: filename: \"{}\", mime: \"{}/{}\", {} bytes from [start: {}, end: {}])",
                    [#text(name), #text(file.filename), #text(file.mimeType), #text(file.mimeSubType), #num(file.bytes.size()), #num(file.start), #num(file.end)],
                  )
                );
              };
            };
            case (_) {
              Debug.print("Error retrieving File");
            };
          };
        };
      };
      case (null) {
        Debug.print("no body");
      };
    };
  };
};
