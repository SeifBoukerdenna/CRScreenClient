# Podfile for CRScreenClient with WebRTC support

platform :ios, '15.0'
use_frameworks!

target 'CRScreenClient' do
  # WebRTC for real-time streaming
  pod 'GoogleWebRTC', '~> 1.1.31999'

  # Additional utilities
  pod 'Starscream', '~> 4.0' # WebSocket client for signaling (if needed)
end

target 'CRScreenClientBroadcast' do
  # WebRTC for broadcast extension
  pod 'GoogleWebRTC', '~> 1.1.31999'
end

target 'CRScreenClientBroadcastSetupUI' do
  # WebRTC for setup UI extension
  pod 'GoogleWebRTC', '~> 1.1.31999'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'

      # Fix for WebRTC compilation issues
      if target.name == 'GoogleWebRTC'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings['OTHER_LDFLAGS'] = '-framework WebRTC'
      end
    end
  end
end