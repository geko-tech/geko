Pod::Spec.new do |s|
    s.name             = 'OrphanSinglePod'
    s.version          = '0.1.0'
    s.summary          = 'This module have not dependencies and only FeaturePodB should depend on it'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.ios.deployment_target = '15.0'
    s.module_map = false
    s.static_framework = true
  
    s.source_files = [
        "#{s.name}/Classes/**/*.{swift}"
    ]

    # SwiftGen
    swiftgen_resources = [
        "#{s.name}/Yaml/**/*.{yaml,yml}"
    ]
    
    # Tests
    
    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = "#{s.name}/Tests/**/*.{swift}"
    end   
end
