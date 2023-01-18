require_relative "lib/lrama/version.rb"

Gem::Specification.new do |spec|
  spec.name          = "lrama"
  spec.version       = Lrama::VERSION
  spec.authors       = ["Yuichiro Kaneko"]
  spec.email         = ["spiketeika@gmail.com"]

  spec.summary       = "TBD"
  spec.description   = "TBD"
  spec.homepage      = "https://github.com/yui-knk/lrama"
  spec.license       = "under consideration"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.0.0")

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end