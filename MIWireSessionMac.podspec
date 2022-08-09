#
# Be sure to run `pod lib lint MIWireSessionMac.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MIWireSessionMac'
  s.version          = '0.1.0'
  s.summary          = 'mac SDK of wire session connect iOS devices and mac device'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
mac SDK of wire session connect iOS devices and mac device
                       DESC

  s.homepage         = 'https://github.com/BenArvin/MIWireSession'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'BenArvin' => 'benarvin93@outlook.com' }
  s.source           = { :git => 'https://github.com/BenArvin/MIWireSession.git', :tag => "Mac-#{s.version.to_s}" }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform = :osx
  s.osx.deployment_target = "10.10"

  s.source_files = 'Mac/Source/Classes/**/*', 'Cross/Classes/**/*'

  # s.resource_bundles = {
  #   'MIWireSessionMac' => ['MIWireSessionMac/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'Cocoa'
end
