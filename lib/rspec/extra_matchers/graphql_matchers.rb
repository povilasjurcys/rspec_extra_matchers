# frozen_string_literal: true

module RSpec
  module ExtraMatchers
    module GraphqlMatchers
      def satisfy_graphql_type(graphql_type)
        TypeMatcher.new(graphql_type)
      end
    end
  end
end
