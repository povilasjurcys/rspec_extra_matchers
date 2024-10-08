# frozen_string_literal: true

# Usage:
# expect(UserDecorator).to be_valid_graphql_type_for(user)
# expect(Types::UserType).to be_valid_graphql_type_for(user)

require 'rspec_extra_matchers/graphql_matchers/type_matcher'
require 'active_support/core_ext/string/indent'

module RSpecExtraMatchers
  module GraphqlMatchers
    # Matcher for testing graphql types
    class ValidGraphqlTypeMatcher
      attr_reader :record

      def initialize(record)
        @type_matcher_options = { deeply: true, strictly: true }
        @record = record
      end

      def matches?(graphql_type_or_model)
        @graphql_type_or_model = graphql_type_or_model
        @type_matcher = TypeMatcher.new(graphql_type_or_model, **type_matcher_options)
        type_matcher.matches?(record)

        error_messages.empty?
      end

      def shallow
        @type_matcher_options = @type_matcher_options.merge(deeply: false)
        self
      end

      def deeply
        @type_matcher_options = @type_matcher_options.merge(deeply: true)
        self
      end

      def strictly
        @type_matcher_options = @type_matcher_options.merge(strictly: true)
        self
      end

      def loosely
        @type_matcher_options = @type_matcher_options.merge(strictly: false)
        self
      end

      def failure_message
        message = "Expected #{graphql_type_or_model}, to be valid GraphqlType for #{record}, but it's not:\n"
        message + type_matcher.error_messages.take(5).join("\n").indent(2)
      end

      def description
        "valid GraphQL type for #{record}"
      end

      def error_messages
        type_matcher&.error_messages || []
      end

      private

      attr_reader :type_matcher_options, :type_matcher, :graphql_type_or_model
    end
  end
end
