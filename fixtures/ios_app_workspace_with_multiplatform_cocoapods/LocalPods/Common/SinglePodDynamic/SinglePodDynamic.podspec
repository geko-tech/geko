Pod::Spec.new do |s|
    s.name             = 'SinglePodDynamic'
    s.version          = '0.1.0'
    s.summary          = 'SinglePodDynamic'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.ios.deployment_target = '15.0'
    s.osx.deployment_target = "10.9"
    s.tvos.deployment_target = "15.0"

    s.module_map = false

    # Resources
    s.resources = [
        "#{s.name}/Resources/Shared/**/*.{yaml,yml,json}"
    ]
    s.ios.resources = [
        "#{s.name}/Resources/ios/**/*.{yaml,yml,json}"
    ]
    s.osx.resources = [
        "#{s.name}/Resources/osx/**/*.{yaml,yml,json}"
    ]
    s.tvos.resources = [
        "#{s.name}/Resources/tvos/**/*.{yaml,yml,json}"
    ]

    # Sources
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
    
    # Tests
    
    s.test_spec 'Tests' do |test_spec|
        test_spec.source_files = "#{s.name}/Tests/**/*.{swift}"
    end   
end
