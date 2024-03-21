# frozen_string_literal: true

module RSpec
  module ExtraMatchers
    # RSpec matchers for testing graphql types
    module GraphqlMatchers
      require_relative 'graphql_matchers/type_matcher'
      require_relative 'graphql_matchers/valid_graphql_type_matcher'
      require_relative 'graphql_matchers/valid_graphql_decorator_matcher'

      def satisfy_graphql_type(graphql_type)
        TypeMatcher.new(graphql_type)
      end

      def be_valid_graphql_type_for(record)
        ValidGraphqlTypeMatcher.new(record)
      end

      def be_valid_graphql_decorator
        ValidGraphqlDecoratorMatcher.new
      end

      def be_loosely_valid_graphql_type_for(record)
        ValidGraphqlTypeMatcher.new(record).loosely
      end
    end
  end
end
