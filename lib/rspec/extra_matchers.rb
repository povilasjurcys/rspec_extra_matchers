# frozen_string_literal: true

require_relative "extra_matchers/version"
require_relative "extra_matchers/graphql_matchers"

module RSpec
  module ExtraMatchers
    class Error < StandardError; end

    def self.included(base)
      base.include(GraphqlMatchers)
    end
  end
end
