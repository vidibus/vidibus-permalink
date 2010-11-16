require "rubygems"
require "rake"
require "rake/rdoctask"
require "rspec"
require "rspec/core/rake_task"

begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|
    gem.name = "vidibus-permalink"
    gem.summary = %Q{Permalink handling}
    gem.description = %Q{This gem allows changeable permalinks.}
    gem.email = "andre@vidibus.com"
    gem.homepage = "http://github.com/vidibus/vidibus-permalink"
    gem.authors = ["Andre Pankratz"]
    gem.add_dependency "rails", "~> 3.0.0"
    gem.add_dependency "mongoid", "~> 2.0.0.beta.20"
    gem.add_dependency "vidibus-core_extensions"
    gem.add_dependency "vidibus-uuid"
    gem.add_dependency "vidibus-words"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

Rspec::Core::RakeTask.new(:rcov) do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.rcov = true
  t.rcov_opts = ["--exclude", "^spec,/gems/"]
end

Rake::RDocTask.new do |rdoc|
  version = File.exist?("VERSION") ? File.read("VERSION") : ""
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "vidibus-permalink #{version}"
  rdoc.rdoc_files.include("README*")
  rdoc.rdoc_files.include("lib/**/*.rb")
  rdoc.options << "--charset=utf-8"
end
