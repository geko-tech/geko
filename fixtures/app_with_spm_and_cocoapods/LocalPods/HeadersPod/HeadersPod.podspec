Pod::Spec.new do |s|
    s.name             = 'HeadersPod'
    s.version          = '0.1.0'
    s.summary          = 'HeadersPod'
    
    s.homepage         = 'Local'
    s.source           = { :path => '*' }

    s.ios.deployment_target = '15.0'
    s.tvos.deployment_target = "15.0"

    s.static_framework = true
  
    s.source_files = [
        "#{s.name}/Swift/**/*.{swift}"
    ]
    s.ios.source_files = [
        "#{s.name}/Core/AddLib/ios/**/*.{swift,c,h}",
        "#{s.name}/Core/PrintLib/ios/**/*.{swift,c,h}"
    ]
    s.ios.private_header_files = [
        "#{s.name}/Core/AddLib/ios/**/*.{h}"
    ]
    s.ios.public_header_files = [
        "#{s.name}/Core/HeadersPod-Umbrella-IOS.h",
        "#{s.name}/Core/PrintLib/ios/**/*.{h}"
    ]
    s.ios.module_map = "#{s.name}/ModuleMap/ios/module.modulemap"

    s.tvos.source_files = [
        "#{s.name}/Core/AddLib/tvos/**/*.{swift,c,h}",
        "#{s.name}/Core/PrintLib/tvos/**/*.{swift,c,h}"
    ]
    s.tvos.private_header_files = [
        "#{s.name}/Core/AddLib/tvos/**/*.{h}"
    ]
    s.tvos.public_header_files = [
        "#{s.name}/Core/HeadersPod-Umbrella-TVOS.h",
        "#{s.name}/Core/PrintLib/tvos/**/*.{h}"
    ]
    s.tvos.module_map = "#{s.name}/ModuleMap/tvos/module.modulemap"

end
