#
# Be sure to run `pod lib lint MIWireSessioniOS.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MIWireSessioniOS'
  s.version          = '0.1.0'
  s.summary          = 'iOS SDK of wire session connect iOS devices and mac device'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
iOS SDK of wire session connect iOS devices and mac device
                       DESC

  s.homepage         = 'https://github.com/BenArvin/MIWireSession'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'BenArvin' => 'benarvin93@outlook.com' }
  s.source           = { :git => 'https://github.com/BenArvin/MIWireSession.git', :tag => "iOS-#{s.version.to_s}" }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform = :ios
  s.ios.deployment_target = "9.0"

  s.source_files = 'iOS/Source/Classes/**/*', 'Cross/Classes/**/*'
  
  # s.resource_bundles = {
  #   'MIWireSessioniOS' => ['MIWireSessioniOS/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
end
