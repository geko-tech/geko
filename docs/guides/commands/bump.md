---
title: Bump
order: 4
---

# geko bump

`geko bump` is an alternative to agvtool (Apple generic version tool) that supports `.xcconfig` settings. 

To use simply pass a path to `.xcodeproj` file and provide optional version and/or build number.

Example:

`geko bump ~/projects/project/Main.xcodeproj --build-number 123 --version 1.2.3`

This command will find plist file `INFOPLIST_FILE` associated with each native target in `Main.xcodeproj` and update fields `CFBunldeVersion` and `CFBundleShortVersionString` to specified version and build number.
