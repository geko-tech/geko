Pod::Spec.new do |s|
    s.name             = 'SinglePod'
    s.version          = '0.1.0'
    s.summary          = 'SinglePod'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.ios.deployment_target = '15.0'
    s.osx.deployment_target = "10.9"
    s.tvos.deployment_target = "15.0"

    s.module_map = false
    s.static_framework = true
  
    s.source_files = [
        "#{s.name}/Classes/**/*.{swift}"
    ]

    s.ios.source_files = [
        "#{s.name}/ios/**/*.{swift}"
    ]
    s.osx.source_files = [
        "#{s.name}/osx/**/*.{swift}"
    ]
    s.tvos.source_files = [
        "#{s.name}/tvos/**/*.{swift}"
    ]

    s.resource_bundle = {
        "#{s.name}SharedResources" => [
            "#{s.name}/Yaml/Shared/**/*.{yaml,yml}"
        ]
    }

    s.ios.resource_bundle = {
        "#{s.name}iOSResources" => [
            "#{s.name}/Yaml/iOS/**/*.{yaml,yml}"
        ]
    }

    s.osx.resource_bundle = {
        "#{s.name}OSXResources" => [
            "#{s.name}/Yaml/OSX/**/*.{yaml,yml}"
        ]
    }

    s.tvos.resource_bundle = {
        "#{s.name}TVOSResources" => [
            "#{s.name}/Yaml/TVOS/**/*.{yaml,yml}"
        ]
    }

    s.frameworks = 'CoreData'
    s.ios.frameworks = 'MessageUI'
    s.osx.frameworks = 'AppKit'
    s.tvos.frameworks = 'TVUIKit'

    s.vendored_frameworks = "#{s.name}/VendoredFrameworks/Documentation.xcframework"
    s.ios.vendored_frameworks = "#{s.name}/VendoredFrameworks/iOS.framework"
    s.tvos.vendored_frameworks = "#{s.name}/VendoredFrameworks/tvOS.framework"

    s.pod_target_xcconfig = { 'MY_CUSTOM_VAR' => '-test-shared' }
    s.ios.pod_target_xcconfig = { 'MY_CUSTOM_VAR' => '-test-ios' }
    s.tvos.pod_target_xcconfig = { 'MY_CUSTOM_VAR' => '-test-osx' }
    
    # Tests
    
    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = "#{s.name}/Tests/**/*.{swift}"
    end   
end
