{
  buildWorkload,
  fetchWorkloadPack,
}:

# WebAssembly workload for .NET
# See: https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/webassembly

buildWorkload {
  pname = "dotnet-workload-wasm-tools";
  version = "8.0.100";

  manifestJson = {
    version = "8.0.19";
    workloads = {
      "wasm-tools" = {
        description = "WebAssembly workload for .NET";
        packs = [
          "Microsoft.NET.Runtime.WebAssembly.Sdk"
          "Microsoft.NETCore.App.Runtime.Mono.browser-wasm"
          "Microsoft.NETCore.App.Runtime.AOT.linux-x64.Cross.browser-wasm"
        ];
      };
    };
    packs = {
      "Microsoft.NET.Runtime.WebAssembly.Sdk" = {
        kind = "sdk";
        version = "8.0.18";
      };
      "Microsoft.NETCore.App.Runtime.Mono.browser-wasm" = {
        kind = "framework";
        version = "8.0.18";
      };
      "Microsoft.NETCore.App.Runtime.AOT.linux-x64.Cross.browser-wasm" = {
        kind = "framework";
        version = "8.0.18";
      };
    };
  };

  packs = [
    (fetchWorkloadPack {
      name = "Microsoft.NET.Runtime.WebAssembly.Sdk";
      version = "8.0.18";
      hash = "sha256-SWQuM3/55/jzp8a6rdvoG8YXCGJ30qUDot2nwF73LaU=";
    })

    (fetchWorkloadPack {
      name = "Microsoft.NETCore.App.Runtime.Mono.browser-wasm";
      version = "8.0.18";
      hash = "sha256-TRvwoWYmdup5eYxThLrRvAvwxQjwcCY0fvfpUUdna7A=";
    })

    (fetchWorkloadPack {
      name = "Microsoft.NETCore.App.Runtime.AOT.linux-x64.Cross.browser-wasm";
      version = "8.0.18";
      hash = "sha256-dde/u90Np1wEjz9u96Sf/zXQ1DS4BCoCec5c78k6QVg=";
    })
  ];
}
