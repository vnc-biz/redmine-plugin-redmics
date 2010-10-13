require 'rake'
require 'rubygems'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'fileutils'

PROJECT_NAME = 'redmine_ics_export'
PROJECT_VERSION = '1.0.2'

task :default => [:clean, :dist]

desc 'Cleans up'
task :clean do
  Dir.glob("*.zip").each {|file|
    puts "Deleting #{file}"
    File.unlink(file)
  }
end

desc 'Packages the distribution'
task :dist do
  source_files = Dir.glob('**/*') - ['Rakefile']
  Zip::ZipFile.open("#{PROJECT_NAME}-#{PROJECT_VERSION}.zip", 'w') {|zipfile|
    puts "Adding to #{zipfile}"
    source_files.each {|file|
      puts "\t#{file}"
      zipfile.add("#{PROJECT_NAME}/#{file}", file)
    }
  }
end
