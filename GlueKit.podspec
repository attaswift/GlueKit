Pod::Spec.new do |spec|
  spec.name         = 'GlueKit'
  spec.version      = '0.2.0'
  spec.ios.deployment_target = "9.3"
  spec.osx.deployment_target = "10.11"
  spec.tvos.deployment_target = "10.0"
  spec.watchos.deployment_target = "3.0"
  spec.summary      = 'Type-safe observable values and collections in Swift'
  spec.author       = 'Károly Lőrentey'
  spec.homepage     = 'https://github.com/attaswift/GlueKit'
  spec.license      = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.source       = { :git => 'https://github.com/attaswift/GlueKit.git', :tag => 'v' + String(spec.version) }
  spec.source_files = 'Sources/*.swift'
  spec.social_media_url = 'https://twitter.com/lorentey'
  #spec.documentation_url = 'http://lorentey.github.io/GlueKit/'
  spec.dependency 'BTree', '~> 4.1'
  spec.dependency 'SipHash', '~> 1.2'
end
