source "https://rubygems.org"
ruby File.read(File.join(__dir__, ".ruby-version")).strip

gem "fastlane", "2.241.2"
plugins_path = File.join(__dir__, "fastlane", "Pluginfile")
eval_gemfile(plugins_path)
