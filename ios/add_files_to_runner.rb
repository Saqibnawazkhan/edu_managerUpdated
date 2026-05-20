#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.expand_path('Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless runner_target

runner_group = project.main_group.find_subpath('Runner', false)
abort 'Runner group not found' unless runner_group

files_to_add = ['GoogleService-Info.plist', 'PrivacyInfo.xcprivacy']

files_to_add.each do |filename|
  full_path = File.join(__dir__, 'Runner', filename)
  unless File.exist?(full_path)
    puts "  SKIP #{filename} (file not found at #{full_path})"
    next
  end

  existing = runner_group.files.find { |f| f.path == filename || f.display_name == filename }
  if existing
    in_resources = runner_target.resources_build_phase.files_references.include?(existing)
    unless in_resources
      runner_target.add_resources([existing])
      puts "  ADD-TO-TARGET #{filename}"
    else
      puts "  EXISTS   #{filename} (already in Runner target)"
    end
    next
  end

  file_ref = runner_group.new_file(filename)
  runner_target.add_resources([file_ref])
  puts "  ADDED    #{filename}"
end

project.save
puts "\nDone. Project saved."
