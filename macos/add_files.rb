require 'xcodeproj'
project_path = 'MacEcho.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('MacEcho/Pairing', true)

files = [
    'MacEcho/Pairing/MacPairingState.swift',
    'MacEcho/Pairing/PairingHandshakeController.swift',
    'MacEcho/Pairing/PairingMessageSerialization.swift'
]

files.each do |file_path|
    file_ref = group.new_file(File.basename(file_path))
    target.add_file_references([file_ref])
end

project.save
