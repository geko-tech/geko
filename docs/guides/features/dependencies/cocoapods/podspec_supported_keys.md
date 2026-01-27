---
title: Podspec Supported Keys
order: 2
---

# Cocoapods podspec supported keys and multiplatform

Geko supports the use of multi-platform podspec files. However, the implementation approaches differ, which may impose some limitations.

Cocoapods creates separate Frameworks for each platform, while Geko leverages Xcode's multi-platform capabilities and regulates the use of various dependencies, files, and resources through platform filters.

## Supported keys in Podspec


| Field         | Geko support | Cocoapods Multiplatform Support | Geko multiplatform support | Comments |
|--------------|----------------------------|-----------------------------------------|------------------------------------|-------------|
| name | ✅ | ❌ | ❌ | - |
| version | ✅ | ❌ | ❌ | - |
| source | ✅ | ❌ | ❌ | - |
| prepare_command | ✅ | ❌ | ❌ | - |
| static_framework | ✅ | ❌ | ❌ | - |
| module_name | ✅ | ❌ | ❌ | - |
| test_type | ✅ | ❌ | ❌ | - |
| default_subspecs | ✅ | ❌ | ❌ | - |
| source_files | ✅ | ✅ | ✅ | - |
| resources | ✅ | ✅ | ✅ | - |
| resource_bundles | ✅ | ✅ | ✅ | - |
| exclude_files | ✅ | ✅ | ✅ | - |
| deployment_target | ✅ | ✅ | ✅ | - |
| dependencies | ✅ | ✅ | ✅ | - |
| frameworks | ✅ | ✅ | ✅ | - |
| weak_frameworks | ✅ | ✅ | ✅ | - |
| libraries | ✅ | ✅ | ✅ | - |
| vendored_frameworks | ✅ | ✅ | ✅ | - |
| vendored_libraries | ✅ | ✅ | ✅ | - |
| pod_target_xcconfig | ✅ | ✅ | ✅ | - |
| user_target_xcconfig | ❌ | ✅ | ❌ | This field is deprecated in Cocoapods. Geko will not support this field. |
| module_map | ✅ | ✅ | ✅ | - |
| public_header_files | ✅ | ✅ | ✅ | - |
| project_header_files | ✅ | ✅ | ✅ | - |
| private_header_files | ✅ | ✅ | ✅ | - |
| header_mappings_dir | ✅ | ✅ | ✅ | - |
| info_plist | ✅ | ❌ | ❌ | Cocoapods claims to support it, but it doesn't. Apple also suggests using user-defined settings to customize fields for each platform's needs. |
| script_phases | ✅ | ✅ | ❌ | Xcode's native tools don't allow you to run platform-specific scripts. However, you can do this yourself in your script. |
| requires_app_host | ✅ | ✅ | ❌ | - |
| app_host_name | ✅ | ✅ | ❌ | - |
| preserve_path | ✅ | ✅ | ❌ | - |
| requires_arc | ✅ | ✅ | ✅ | - |
| compiler_flags | ✅ | ✅ | ✅ | - |
| swift_versions | ✅ | ❌ | ❌ | - |
| scheme | ❌ | ✅ | ❌ | - |
| prefix_header_contents | ❌ | ✅ | ❌ | - |
| prefix_header_file | ❌ | ✅ | ❌ | - |
| header_dir | ❌ | ✅ | ❌ | - |
| cocoapods_version | ❌ | ❌ | ❌ | - |
| authors | ❌ | ❌ | ❌ | - |
| social_media_url | ❌ | ❌ | ❌ | - |
| license | ❌ | ❌ | ❌ | - |
| homepage | ❌ | ❌ | ❌ | - |
| readme | ❌ | ❌ | ❌ | - |
| changelog | ❌ | ❌ | ❌ | - |
| summary | ❌ | ❌ | ❌ | - |
| description | ❌ | ❌ | ❌ | - |
| screenshots | ❌ | ❌ | ❌ | - |
| documentation_url | ❌ | ❌ | ❌ | - |
| deprecated | ❌ | ❌ | ❌ | - |
| deprecated_in_favor_of | ❌ | ❌ | ❌ | - |
