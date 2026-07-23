require 'xcodeproj'
project_path = 'MacEcho.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('MacEcho/Session', true)
group.set_path('Session')
file_ref = group.new_file('AppSessionManager.swift')
target.add_file_references([file_ref])

project.save
