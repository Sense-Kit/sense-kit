#!/usr/bin/env ruby

require "fileutils"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
IOS_DIR = File.join(ROOT, "apps", "ios")
PROJECT_PATH = File.join(IOS_DIR, "SenseKitApp.xcodeproj")

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastSwiftUpdateCheck"] = "2630"
project.root_object.attributes["LastUpgradeCheck"] = "2630"

main_group = project.main_group
app_group = main_group.find_subpath("App", true)
bench_group = main_group.find_subpath("BenchHarness", true)
packages_group = main_group.find_subpath("Packages", true)

packages_group.set_source_tree("SOURCE_ROOT")

def add_swift_sources(project, group, target, absolute_directory)
  Dir.children(absolute_directory).sort.each do |entry|
    next if entry.start_with?(".")

    absolute_path = File.join(absolute_directory, entry)
    if File.directory?(absolute_path)
      child_group = group.find_subpath(entry, true)
      add_swift_sources(project, child_group, target, absolute_path)
    elsif File.extname(entry) == ".swift"
      file_ref = group.new_file(absolute_path)
      target.add_file_references([file_ref])
    end
  end
end

def configure_target(target, bundle_identifier:)
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_identifier
    settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
    settings["SWIFT_VERSION"] = "6.0"
    settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
    settings["TARGETED_DEVICE_FAMILY"] = "1"
    settings["GENERATE_INFOPLIST_FILE"] = "YES"
    settings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] = "YES"
    settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
    settings["INFOPLIST_KEY_NSMotionUsageDescription"] = "SenseKit uses motion activity to detect wake and driving state."
    settings["INFOPLIST_KEY_NSLocationWhenInUseUsageDescription"] = "SenseKit uses location to improve driving accuracy and detect home/work arrival."
    settings["INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription"] = "SenseKit uses location to monitor home/work arrival and departure in the background."
    settings["INFOPLIST_KEY_NSHealthShareUsageDescription"] = "SenseKit reads workout events so it can send workout follow-ups."
    settings["INFOPLIST_KEY_NSCalendarsUsageDescription"] = "SenseKit reads minimal calendar context to enrich event snapshots."
    settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/Frameworks"
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["DEVELOPMENT_TEAM"] = ""
    settings["CURRENT_PROJECT_VERSION"] = "1"
    settings["MARKETING_VERSION"] = "0.1.0"
  end
end

def add_local_package_dependency(project, target, package_path:, product_name:)
  package_reference = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  package_reference.path = package_path
  project.root_object.package_references << package_reference

  product_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dependency.package = package_reference
  product_dependency.product_name = product_name
  target.package_product_dependencies << product_dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dependency
  target.frameworks_build_phase.files << build_file
end

app_target = project.new_target(:application, "SenseKitApp", :ios, "17.0")
bench_target = project.new_target(:application, "SenseKitBenchApp", :ios, "17.0")

configure_target(app_target, bundle_identifier: "dev.sensekit.app")
configure_target(bench_target, bundle_identifier: "dev.sensekit.bench")

add_swift_sources(project, app_group.find_subpath("SenseKitApp", true), app_target, File.join(IOS_DIR, "App", "SenseKitApp"))
add_swift_sources(project, bench_group.find_subpath("SenseKitBenchApp", true), bench_target, File.join(IOS_DIR, "BenchHarness", "SenseKitBenchApp"))

add_local_package_dependency(project, app_target, package_path: "Packages/SenseKitUI", product_name: "SenseKitUI")
add_local_package_dependency(project, bench_target, package_path: "Packages/SenseKitUI", product_name: "SenseKitUI")

project.save

workspace_path = File.join(IOS_DIR, "SenseKit.xcworkspace", "contents.xcworkspacedata")
File.write(
  workspace_path,
  <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Workspace
       version = "1.0">
       <FileRef
          location = "group:SenseKitApp.xcodeproj">
       </FileRef>
       <FileRef
          location = "group:Packages/SenseKitRuntime">
       </FileRef>
       <FileRef
          location = "group:Packages/SenseKitUI">
       </FileRef>
    </Workspace>
  XML
)

puts "Generated #{PROJECT_PATH}"
