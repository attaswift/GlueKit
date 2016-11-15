Pod::Spec.new do |spec|
  spec.name         = 'GlueKit'
  spec.version      = '0.0.1'
  spec.osx.deployment_target = "10.9"
  spec.ios.deployment_target = "8.0"
  spec.tvos.deployment_target = "9.0"
  spec.watchos.deployment_target = "2.0"
  spec.summary      = 'A type-safe observer framework for Swift'
  spec.author       = 'Károly Lőrentey'
  spec.homepage     = 'https://github.com/lorentey/GlueKit'
  spec.license      = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.source       = { :git => 'https://github.com/lorentey/GlueKit.git', :branch => 'master' }
  spec.source_files = 'Sources/*.swift'
  spec.social_media_url = 'https://twitter.com/lorentey'
  #spec.documentation_url = 'http://lorentey.github.io/GlueKit/api/'
  spec.dependency   = 'BTree', '~> 4.0'
  spec.dependency   = 'SipHash', '~> 1.0'
end
