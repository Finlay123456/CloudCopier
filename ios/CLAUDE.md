# Claude Code Instructions

## Build and Test Commands

You are authorized to run the following commands without asking for permission:

- `swift -frontend -typecheck` - Type check Swift files
- `xcodebuild -project` - Build Xcode projects
- `swift build` - Build Swift packages
- Any compilation or type checking commands needed to verify code correctness

## Development Workflow

When fixing compilation errors:
1. Run type checking/compilation commands to identify errors
2. Fix the errors systematically
3. Re-run compilation to verify fixes
4. Continue until the project builds successfully

You should be proactive in testing compilation after making changes to ensure the code builds correctly.