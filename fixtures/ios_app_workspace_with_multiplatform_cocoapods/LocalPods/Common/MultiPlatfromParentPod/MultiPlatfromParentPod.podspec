Pod::Spec.new do |s|
    s.name             = 'MultiPlatfromParentPod'
    s.version          = '0.1.0'
    s.summary          = 'MultiPlatfromParentPod'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.ios.deployment_target = '15.0'
    s.osx.deployment_target = "10.9"
    s.tvos.deployment_target = "15.0"
    s.static_framework = true
  
    s.requires_arc = ["#{s.name}/Classes/**/*.{swift}", "#{s.name}/ios/**/*.{swift}"]
    s.source_files = [
        "#{s.name}/Classes/**/*.{swift}",
        "#{s.name}/TestStaticLib/**/*.{h}"
    ]

    s.dependency 'MultiPlatfromChildPod'
    s.vendored_libraries = "#{s.name}/TestStaticLib/*.a"
    s.ios.dependency 'IOSPod'
    s.tvos.dependency 'TVOSPod'

    # SwiftGen
    swiftgen_resources = [
        "#{s.name}/Yaml/**/*.{yaml,yml}"
    ]

    # s.ios.requires_arc = "#{s.name}/ios/**/*.{swift}"
    s.ios.source_files = [
        "#{s.name}/ios/**/*.{swift}"
    ]
    s.osx.source_files = [
        "#{s.name}/osx/**/*.{swift}"
    ]
    # s.tvos.requires_arc = "#{s.name}/tvos/**/*.{swift}"
    s.tvos.source_files = [
        "#{s.name}/tvos/**/*.{swift}"
    ]
    
    # Tests
    
    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = "#{s.name}/Tests/**/*.{swift}"
    end   
end
