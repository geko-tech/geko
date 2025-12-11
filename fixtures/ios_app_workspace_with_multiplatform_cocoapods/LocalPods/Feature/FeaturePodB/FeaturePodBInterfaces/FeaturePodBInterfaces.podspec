Pod::Spec.new do |s|
  s.name             = 'FeaturePodBInterfaces'
  s.version          = '0.1.0'

  s.homepage         = 'Local'
  s.source           = { :path => '*' }

  s.ios.deployment_target = '15.0'
  s.static_framework = true

  s.module_map = false

  swiftgen_yamls = "#{s.name}/Yaml/**/*.yaml"
  swiftgen_resources = [
    swiftgen_yamls
  ]

  s.source_files = [
    "#{s.name}/Classes/**/*.swift",
    swiftgen_yamls
  ]
  
  s.pod_target_xcconfig = { 'SWIFT_STRICT_CONCURRENCY' => 'targeted' }
end
