Pod::Spec.new do |s|
  s.name             = 'MultiPodMock'
  s.version          = '1.0.0'

  s.homepage         = 'Local'
  s.source           = { :path => '*' }

  s.ios.deployment_target = '15.0'
  s.static_framework = true
  s.module_map = false

  s.source_files = 'MultiPod/Classes/Mocks/**/*.{swift}'

  # Interfaces
  s.dependency 'MultiPodInterfaces'
end
