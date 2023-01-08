require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

folly_version = '2021.06.28.00-v2'
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'


fabric_enabled = ENV['RCT_NEW_ARCH_ENABLED'] == '1'

fabric_flags = ''
if fabric_enabled
  fabric_flags = '-DRN_FABRIC_ENABLED -DRCT_NEW_ARCH_ENABLED'
end

Pod::Spec.new do |s|

  s.subspec "Fabric" do |ss|
    ss.source_files           = "ios/AirMaps/Fabric/*.{h,mm}"
  end

  s.name         = "react-native-maps"
  s.version      = package['version']
  s.summary      = "React Native Mapview component for iOS + Android"

  s.authors      = { "intelligibabble" => "leland.m.richardson@gmail.com" }
  s.homepage     = "https://github.com/react-native-maps/react-native-maps#readme"
  s.license      = "MIT"
  s.platform     = :ios, "11.0"

  s.source       = { :git => "https://github.com/react-native-maps/react-native-maps.git", :tag=> "v#{s.version}" }
  s.source_files  = "ios/AirMaps/**/*.{h,m,mm}"
  s.exclude_files           = "ios/AirMaps/Fabric/*.{h,mm}"

  s.compiler_flags  = folly_compiler_flags + " " + fabric_flags

  s.pod_target_xcconfig    = {
    "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }

  s.dependency "React-Core"
  s.dependency "React-RCTFabric" # This is for fabric component
  s.dependency "React-Codegen"
  s.dependency "RCT-Folly", folly_version
  s.dependency "RCTRequired"
  s.dependency "RCTTypeSafety"
  s.dependency "ReactCommon/turbomodule/core"
end
