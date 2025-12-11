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

    s.resource_bundle = {
        "#{s.name}SharedResources" => [
            "#{s.name}/Yaml/Shared/**/*.{yaml,yml}"
        ]
    }

end
