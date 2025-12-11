Pod::Spec.new do |s|
    s.name             = 'TVOSPod'
    s.version          = '0.1.0'
    s.summary          = 'TVOSPod'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.tvos.deployment_target = "15.0"

    s.module_map = false
    s.static_framework = true
  
    s.source_files = [
        "#{s.name}/Classes/**/*.{swift}"
    ]

    s.resource_bundle = {
        "#{s.name}SharedResources" => [
            "#{s.name}/Yaml/**/*.{yaml,yml}"
        ]
    }
end
