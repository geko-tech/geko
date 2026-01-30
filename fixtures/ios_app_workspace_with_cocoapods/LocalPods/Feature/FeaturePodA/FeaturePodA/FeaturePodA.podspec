Pod::Spec.new do |s|
  s.name             = 'FeaturePodA'
  s.version          = '0.1.0'
  s.summary          = 'FeaturePodA'

  s.homepage         = 'Local'
  s.source           = { :path => '*' }

  s.ios.deployment_target = '15.0'
  s.static_framework = true

  s.module_map = false

  resources_bundle_name = "#{s.name}Resources"

  s.pod_target_xcconfig = { 'SWIFT_STRICT_CONCURRENCY' => 'targeted' }

  resources = [
    "#{s.name}/Localization/**/*.{json}"
  ]

  swiftgen_yamls = "#{s.name}/Yaml/**/*.yaml"
  swiftgen_resources = resources + [
    swiftgen_yamls
  ]

  s.source_files = [
    "#{s.name}/Classes/**/*.swift",
    swiftgen_yamls
  ]  

  s.resource_bundles = {
    resources_bundle_name => resources
  }
  
  # IO
  s.dependency 'FeaturePodAInterfaces'
  s.dependency 'SinglePod'
  s.dependency 'MultiPod'
  s.dependency 'MultiPodInterfaces'
  s.dependency 'SwiftyJSON'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = ["Tests/**/*.{swift}"]
    test_spec.resources = [
      "Tests/Resources/config.json",
      "Tests/Resources/folder_references/*"
    ]

    # IO
    test_spec.dependency 'FeaturePodAInterfaces'
  end
end
