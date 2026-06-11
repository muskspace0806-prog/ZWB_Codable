Pod::Spec.new do |s|
  s.name             = 'ZWB_Codable'
  s.version          = '0.1.0'
  s.summary          = 'A tolerant Codable layer for messy JSON responses.'
  s.description      = <<-DESC
ZWB_Codable keeps native Codable model declarations while adding tolerant JSON
decoding for common backend inconsistencies such as string-number conversion,
empty values, nulls, object-array mismatches, key aliases, and debug logs.
  DESC
  s.homepage         = 'https://github.com/muskspace0806-prog/ZWB_Codable'
  s.license          = { :type => 'MIT' }
  s.author           = { 'hule' => 'hule' }
  s.source           = { :git => 'https://github.com/muskspace0806-prog/ZWB_Codable.git', :tag => s.version.to_s }
  s.ios.deployment_target = '14.0'
  s.swift_versions   = ['5.7', '5.8', '5.9', '5.10', '6.0']
  s.source_files     = 'Sources/ZWB_Codable/**/*.swift'
end
