Pod::Spec.new do |s|
    s.name             = 'MultiPlatfromChildPod'
    s.version          = '0.1.0'
    s.summary          = 'MultiPlatfromChildPod'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.ios.deployment_target = '15.0'
    s.osx.deployment_target = "10.9"
    s.tvos.deployment_target = "15.0"

    s.module_map = false
    s.static_framework = true
  
    s.compiler_flags = '-DGLOBAL'
    s.source_files = [
        "#{s.name}/Classes/**/*.{swift}"
    ]

    # SwiftGen
    swiftgen_resources = [
        "#{s.name}/Yaml/**/*.{yaml,yml}"
    ]

    s.ios.compiler_flags = '-DIOSFLAG'
    s.ios.source_files = [
        "#{s.name}/ios/**/*.{swift}"
    ]
    s.osx.compiler_flags = '-DOSXFLAG'
    s.osx.source_files = [
        "#{s.name}/osx/**/*.{swift}"
    ]
    s.tvos.compiler_flags = '-DTVOSFLAG'
    s.tvos.source_files = [
        "#{s.name}/tvos/**/*.{swift}"
    ]
    
    # Tests
    
    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = "#{s.name}/Tests/**/*.{swift}"
    end   
end
