# frozen_string_literal: true
$LOAD_PATH << File.expand_path("../lib", __FILE__)
require 'tfctl/version'

Gem::Specification.new do |spec|
    spec.name          = 'tfctl'
    spec.version       = Tfctl::VERSION
    spec.authors       = [
        'Andrew Wasilczuk'
    ]
    spec.email         = [
        'akw@scalefactory.com'
    ]
    spec.summary       = 'Terraform wrapper for managing dynamic, multi-account AWS environments'
    spec.homepage      = 'https://github.com/essentia-team/tfctl'
    spec.license       = "MIT"
    spec.files         = `git ls-files -z`.split("\x0").reject { |f|
        f.match(%r{^(test|spec|features)/})
    }
    spec.bindir        = "bin"
    spec.executables   = spec.files.grep(%r{^bin/tfctl}) { |f| File.basename(f) }
    spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ["lib"]

    spec.add_dependency 'aws-sdk-organizations', '~> 1.13'
    spec.add_dependency 'parallel',              '~> 1.17'

    spec.add_development_dependency 'rspec', '~> 3.8'
end
