Pod::Spec.new do |s|
  s.name             = 'MultiPodInterfaces'
  s.version          = '1.0.0'

  s.homepage         = 'Local'
  s.source           = { :path => '*' }

  s.ios.deployment_target = '15.0'
  s.static_framework = true
  s.module_map = false
  
  s.source_files = 'MultiPod/Classes/Interfaces/**/*.{swift}'
end
