{
  buildDunePackage,
  paf,
  cohttp-lwt,
  domain-name,
  httpaf,
  ipaddr,
  alcotest-lwt,
  fmt,
  logs,
  mirage-crypto-rng,
  mirage-time-unix,
  tcpip,
  uri,
  lwt,
  astring,
}:

buildDunePackage {
  pname = "paf-cohttp";

  inherit (paf)
    version
    src
    ;

  propagatedBuildInputs = [
    paf
    cohttp-lwt
    domain-name
    httpaf
    ipaddr
  ];

  doCheck = true;
  checkInputs = [
    alcotest-lwt
    fmt
    logs
    mirage-crypto-rng
    mirage-time-unix
    tcpip
    uri
    lwt
    astring
  ];

  __darwinAllowLocalNetworking = true;

  meta = paf.meta // {
    description = "CoHTTP client with its HTTP/AF implementation";
  };
}
