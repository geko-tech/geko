Pod::Spec.new do |s|
    s.name             = 'MultiPod'
    s.version          = '1.0.0'
  
    s.homepage         = 'Local'
    s.source           = { :path => '*' }
  
    s.ios.deployment_target = '15.0'
    s.static_framework = true
    s.module_map = false
  
    swiftgen_yamls = "#{s.name}/Yaml/Implementations/**/*.yaml"
    
    swiftgen_resources = [
      swiftgen_yamls
    ]
  
    s.source_files = [
      "#{s.name}/Classes/Implementations/**/*.{swift}",
      swiftgen_yamls
    ]

    s.dependency 'MultiPodInterfaces'
    
    s.test_spec "Tests" do |test_spec|
      test_spec.source_files = "MultiPod/Tests/**/*.{swift}"
      test_spec.resource_bundles = {
        "#{s.name}TestsResources" => [
          "#{s.name}/Tests/Resources/**/*"
        ]
      }
      test_spec.dependency 'MultiPodMock'
    end
end
  