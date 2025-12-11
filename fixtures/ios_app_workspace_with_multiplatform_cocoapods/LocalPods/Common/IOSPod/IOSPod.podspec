Pod::Spec.new do |s|
    s.name             = 'IOSPod'
    s.version          = '0.1.0'
    s.summary          = 'IOSPod'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.ios.deployment_target = '15.0'

    s.module_map = false
    s.static_framework = true
  
    s.source_files = [
        "#{s.name}/Classes/**/*.{swift}"
    ]
end
