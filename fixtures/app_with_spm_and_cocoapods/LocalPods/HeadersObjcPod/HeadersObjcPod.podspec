Pod::Spec.new do |s|
    s.name             = 'HeadersObjcPod'
    s.version          = '0.1.0'
    s.summary          = 'HeadersObjcPod'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.ios.deployment_target = '15.0'
    s.tvos.deployment_target = "15.0"
  
    s.source_files = [
        "#{s.name}/Classes/Common/**/*.{swift,h,m}"
    ]
    s.ios.source_files = [
        "#{s.name}/Classes/IOS/**/*.{swift,h,m}"
    ]

    s.tvos.source_files = [
        "#{s.name}/Classes/TVOS/**/*.{swift,h,m}",
    ]

end
