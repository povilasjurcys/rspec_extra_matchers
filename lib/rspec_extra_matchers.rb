# frozen_string_literal: true

require_relative 'rspec_extra_matchers/version'
require_relative 'rspec_extra_matchers/graphql_matchers'

# Main module for the gem
module RSpecExtraMatchers
  class Error < StandardError; end

  def self.included(base)
    base.include(GraphqlMatchers)
  end
end
