# frozen_string_literal: true

# Usage:
# expect(user).to satisfy_graphql_type(UserDecorator)
# expect(user).to satisfy_graphql_type(Types::UserType)

require 'rspec/matchers/composable'
require_relative 'assert_type_and_value'

module RSpec
  module ExtraMatchers
    module GraphqlMatchers
      # Matcher for testing graphql types
      class TypeMatcher
        require 'rspec/matchers/composable'

        include RSpec::Matchers::Composable

        ERROR_MESSAGES = {
          not_nullable: 'expected non-nullable field "%<field_name>s" not to be `nil`',
          nil_in_strict_mode:
            'Using `strictly` matcher which does not allow `nil` values, but field "%<field_name>s" is `nil`.' \
            'Use `loosely` matcher to allow `nil` values"',
          wrong_type: 'Expected field "%<field_name>s" to be %<expected_type>s, but was `%<actual_type>s`',
          missing_field: 'Method `%<property>s` for "%<field_name>s" field does not exist on record %<record>s',
          wrong_enum_value: 'Expected value of the "%<field_name>s" enum field to be one of %<expected_values>s, ' \
                            'but was `%<actual_value>s`',
          not_a_graphql_type: 'Expected a GraphQL type, but got %<graphql_type>s'
        }.freeze

        attr_reader :detailed_error_messages, :graphql_type, :record

        def initialize(graphql_type_or_model, deeply: true, strictly: true)
          @detailed_error_messages = []
          @deeply = deeply
          @strictly = strictly
          @graphql_type = extract_graphql_type(graphql_type_or_model)
        end

        def matches?(record)
          @record = record
          assert_type

          error_messages.empty?
        end

        def shallow
          @deeply = false
        end

        def deeply
          @deeply = true
        end

        def strictly
          @strictly = true
        end

        def loosely
          @strictly = false
        end

        def failure_message
          message = "Expected #{@record} to match #{graphql_type}, but it didn't:\n"
          message + error_messages.take(5).join("\n").indent(2)
        end

        def description
          "matches GraphQL type #{graphql_type}"
        end

        def error_messages
          detailed_error_messages.map { |error| error_message_for(**error) }
        end

        private

        def assert_deeply?(value)
          @deeply && !checked_records.include?(value)
        end

        def extract_graphql_type(klass)
          klass.is_a?(Class) && klass < GraphqlRails::Model ? klass.graphql.graphql_type : klass
        end

        def strict?
          @strictly
        end

        def assert_type
          if graphql_type < GraphQL::Schema::Member
            graphql_type.unwrap.fields.each_value { |field| assert_field(field) }
          else
            @detailed_error_messages << { type: :not_a_graphql_type, graphql_type: graphql_type }
          end
        end

        def assert_field(field)
          @detailed_error_messages += AssertTypeAndValue.new(
            type: field.type,
            value_parent: record,
            field_name: field.name,
            deeply: deeply?,
            property: field.method_str,
            strictly: strict?
          ).call
        end

        def deeply?
          @deeply
        end

        def error_message_for(type:, **error_options)
          format(ERROR_MESSAGES.fetch(type), error_options)
        end
      end
    end
  end
end
