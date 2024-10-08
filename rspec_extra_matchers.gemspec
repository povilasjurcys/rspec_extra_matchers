# frozen_string_literal: true

require_relative "lib/rspec_extra_matchers/version"

Gem::Specification.new do |spec|
  spec.name          = 'rspec_extra_matchers'
  spec.version       = RSpecExtraMatchers::VERSION
  spec.authors       = ['Povilas Jurcys']
  spec.email         = ['po.jurcys@gmail.com']

  spec.summary       = 'Additional matchers for RSpec.'
  spec.homepage      = 'https://github.com/povilasjurcys/rspec_extra_matchers'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.4.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rspec'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'graphql'
  spec.add_development_dependency 'graphql_rails'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'rubocop-rake'

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
