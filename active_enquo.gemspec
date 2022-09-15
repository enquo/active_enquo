begin
	require "git-version-bump"
rescue LoadError
	nil
end

Gem::Specification.new do |s|
	s.name = "active_enquo"

	s.version = GVB.version rescue "0.0.0.1.NOGVB"
	s.date    = GVB.date    rescue Time.now.strftime("%Y-%m-%d")

	s.platform = Gem::Platform::RUBY

	s.summary  = "ActiveRecord integration for encrypted querying operations"

	s.authors  = ["Matt Palmer"]
	s.email    = ["matt@enquo.org"]
  s.homepage = "https://enquo.org/active_enquo"

	s.files = `git ls-files -z`.split("\0").reject { |f| f =~ /^(G|spec|Rakefile)/ }

  s.required_ruby_version = ">= 2.7.0"

 	s.add_runtime_dependency "enquo-core"
  s.add_runtime_dependency "activerecord", ">= 6"

	s.add_development_dependency "bundler"
	s.add_development_dependency "github-release"
	s.add_development_dependency "guard-rspec"
  s.add_development_dependency "pg"
  s.add_development_dependency "rake", "~> 13.0"
	# Needed for guard
	s.add_development_dependency "rb-inotify", "~> 0.9"
	s.add_development_dependency "redcarpet"
	s.add_development_dependency "rspec"
  s.add_development_dependency "simplecov"
	s.add_development_dependency "yard"
end
