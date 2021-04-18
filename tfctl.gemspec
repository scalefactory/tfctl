# frozen_string_literal: true

$LOAD_PATH << File.expand_path('lib', __dir__)
require 'tfctl/version'

Gem::Specification.new do |spec|
    spec.name          = 'tfctl'
    spec.version       = Tfctl::VERSION
    spec.authors       = [
        'Andrew Wasilczuk',
    ]
    spec.email         = [
        'akw@scalefactory.com',
    ]
    spec.summary       = 'Terraform wrapper for managing multi-account AWS infrastructures'
    spec.homepage      = 'https://github.com/scalefactory/tfctl'
    spec.license       = 'MIT'
    spec.files         = `git ls-files -z`.split("\x0").reject do |f|
        f.match(%r{^(test|spec|features)/})
    end
    spec.bindir        = 'bin'
    spec.executables   = spec.files.grep(%r{^bin/tfctl}) { |f| File.basename(f) }
    spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ['lib']

    spec.required_ruby_version = '>= 2.5.0'

    # Think when adding new dependencies.  Is it really necessary?
    # "The things you own end up owning you" etc.
    spec.add_dependency 'aws-sdk-organizations', '~> 1.40'
    spec.add_dependency 'json_schemer',          '~> 0.2'
    spec.add_dependency 'parallel',              '~> 1.19'
    spec.add_dependency 'terminal-table',        '>= 1.8', '< 4.0'

    spec.add_development_dependency 'guard-rspec', '~> 4.7'
    spec.add_development_dependency 'rspec',       '~> 3.9'
    spec.add_development_dependency 'rubocop',     '~> 1.3'
end
