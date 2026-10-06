platform :ios, '17.0'

target 'WordCover' do
  use_frameworks!

  pod 'onnxruntime-objc', '1.24.3'
  pod 'Yams', '5.0.6'

  target 'WordCoverTests' do
    inherit! :search_paths
  end
end

# Make the dependency graph explicit; Xcode must build the pods before scanning
# Swift imports, including when a Swift Package binary is also linked.
post_integrate do |installer|
  installer.aggregate_targets.each do |aggregate|
    project = aggregate.user_project
    pods_target = installer.pods_project.targets.find { |target| target.name == aggregate.label }
    next unless pods_target

    project.main_group.new_reference(installer.pods_project.path) unless project.reference_for_path(installer.pods_project.path)
    aggregate.user_targets.each { |target| target.add_dependency(pods_target) }
    project.save
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    end
  end
end
