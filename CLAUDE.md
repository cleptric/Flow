## General

- Flow is an app that allows a user to view log files.
- Aim to build all functionality using SwiftUI unless there is a feature that is only supported in AppKit.
- Design UI in a way that is idiomatic for the macOS platform and follows Apple Human Interface Guidelines.
- Use SF Symbols for iconography.
- Use the most modern macOS APIs. Since there is no backward compatibility constraint, this app can target the latest macOS version with the newest APIs.
- Use the most modern Swift language features and conventions. Target Swift 6 and use Swift concurrency (async/await, actors) and Swift macros where applicable.

## Code Style

- Do not add excessive comments within function bodies. Only add comments within function bodies to highlight specific details that may not be obvious.
- Use 2 spaces for indentation
- Run `swift format -i <path>` to format the code in place

## MCP Servers

- Use the XcodeBuildMCP server to build and run the macOS application
- Before launching the app, kill the app if it's already running using the command "killall Context || true"
- Use the build_run_mac_proj tool from XcodeBuildMCP to build and run the Mac app
