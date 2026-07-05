import Foundation

// `--dump` runs a one-shot parse and prints totals to stdout (handy for verifying the
// parser against the real logs without launching the UI). Otherwise start the app.
if CommandLine.arguments.contains("--dump") {
    DumpTool.run()
    exit(0)
}

ClaudeUsageBarApp.main()
