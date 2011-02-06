require 'rake'
require 'rubygems'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'fileutils'

PROJECT_NAME = 'redmine_ics_export'

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
  project_version = get_version_from_plugin_init
  source_files = Dir.glob('**/*') - ['Rakefile']
  Zip::ZipFile.open("#{PROJECT_NAME}-#{project_version}.zip", 'w') {|zipfile|
    puts "Adding to #{zipfile}"
    source_files.each {|file|
      puts "\t#{file}"
      zipfile.add("#{PROJECT_NAME}/#{file}", file)
    }
  }
end

def get_version_from_plugin_init
  File.open( 'init.rb' ) do |f|
    f.grep( /^\s+version '(.*)'/ ) do
      return $1
    end
  end
  'snapshot'
end
