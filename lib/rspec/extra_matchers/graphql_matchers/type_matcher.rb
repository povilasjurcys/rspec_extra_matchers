# frozen_string_literal: true

# Usage:
# expect(user).to satisfy_graphql_type(UserDecorator)
# expect(user).to satisfy_graphql_type(Types::UserType)
# expect(user_decorator).to be_valid_graphql_model

module RSpec
  module ExtraMatchers
    module GraphqlMatchers
      # Matcher for testing graphql types
      class TypeMatcher
        require 'rspec/matchers/composable'

        include RSpec::Matchers::Composable

        TYPE_MAPPING = {
          GraphQL::Types::Int => [Integer],
          GraphQL::Types::ID => [Integer, String],
          GraphQL::Types::String => [String],
          GraphQL::Types::Float => [Float, Integer, Numeric]
        }.freeze

        ERROR_MESSAGES = {
          not_nullable: 'expected non-nullable field "%<field>s" not to be `nil`',
          nil_in_strict_mode:
            'Using `strictly` matcher which does not allow `nil` values, but field "%<field>s" is `nil`.' \
            'Use `loosely` matcher to allow `nil` values"',
          wrong_type: 'Expected field "%<field>s" to be %<expected_type>, but was `%<actual_type>s`'
        }

        attr_reader :error_messages, :graphql_type, :record

        def initialize(graphql_type_or_model, parent_fields: [])
          @parent_fields = parent_fields
          @error_messages = []
          @deeply = false
          @strictly = true
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
          message + @error_messages.take(5).join("\n").indent(2)
        end

        def failure_message_when_negated
          "Expected to not run #{count_range_description}, #{actual_result_message}"
        end

        def description
          "make DB requests #{count_range_description}"
        end

        private

        def assert_deeply?
          @deeply
        end

        def extract_graphql_type(klass)
          klass < GraphqlRails::Model ? klass.graphql.graphql_type : klass
        end

        def strict?
          @strictly
        end

        def assert_type
          graphql_type.fields.each_value do |field|
            assert_field(field)
          end
        end

        def assert_field(field)
          value = @record.send(field.name.underscore)

          return assert_nullable_field(field) if value.nil?
          return assert_list_field(value, field) if value.is_a?(Array)
          return assert_basic_field(value, field) if basic_field?(field)
          return assert_nested_field(value, field) if assert_deeply?
        end

        def assert_nullable_field(field)
          if field.type.non_null?
            add_error(:not_nullable, field: field.name)
          elsif strict?
            add_error(:nil_in_strict_mode, field: field.name)
          end
        end

        def assert_list_field(value, field)
          value.each { |item| assert_field_value(field.type.unwrap, item) }
        end

        def assert_basic_field(value, field)
          compatible_classes = TYPE_MAPPING[field.type.unwrap]
          return if compatible_classes.any? { |klass| value.is_a?(klass) }

          expected_type =
            if compatible_classes.count > 1
              "one of `#{compatible_classes}`"
            else
              "`#{compatible_classes.first}`"
            end

          add_error(:wrong_type, field: field.name, expected_type: expected_type, actual_type: value.class.to_s)
        end

        def basic_field?(field)
          TYPE_MAPPING.keys.include?(field.type.unwrap)
        end

        def add_error(type, **message_options)
          message = ERROR_MESSAGES.fetch(type) % message_options
          @error_messages << message
        end
      end
    end
  end
end
