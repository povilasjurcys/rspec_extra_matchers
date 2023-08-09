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
          wrong_type: 'Expected field "%<field>s" to be %<expected_type>s, but was `%<actual_type>s`',
          missing_field: 'Field "%<field>s" does not exist on record',
          wrong_enum_value: 'Expected value of the "%<field>s" enum field to be one of %<expected_values>s, ' \
                            'but was `%<actual_value>s`'
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
          return add_missing_field_error(field) unless record_field_exist?(field)

          value = fetch_value(field)

          return assert_nullable_field(field) if value.nil?
          return assert_list_field(value, field) if value.is_a?(Array)
          return assert_basic_field(value, field) if basic_field?(field)
          return assert_enum_field(value, field) if enum_field?(field)
          return assert_nested_field(value, field) if assert_deeply?
        end

        def record_field_exist?(field)
          @record.respond_to?(field.name.underscore)
        end

        def fetch_value(field)
          @record.send(field.name.underscore)
        end

        def add_missing_field_error(field)
          add_error(:missing_field, field: field)
        end

        def assert_nullable_field(field)
          if field.type.non_null?
            add_error(:not_nullable, field: field)
          elsif strict?
            add_error(:nil_in_strict_mode, field: field)
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

          add_error(:wrong_type, field: field, expected_type: expected_type, actual_type: value.class.to_s)
        end

        def assert_enum_field(value, field)
          expected_values = field.type.unwrap.values.values.map(&:value)
          return if expected_values.include?(value)

          message_options = {
            field: field,
            expected_values: expected_values.inspect,
            actual_value: value.inspect
          }
          add_error(:wrong_enum_value, message_options)
        end

        def assert_nested_field(value, field)
          inner_matcher = self.class.new(field.type, parent_fields: @parent_fields + [field])
          return if inner_matcher.matches?(value)

          @error_messages += inner_matcher.error_messages
        end

        def basic_field?(field)
          TYPE_MAPPING.keys.include?(field.type.unwrap)
        end

        def enum_field?(field)
          field.type.unwrap < GraphQL::Schema::Enum
        end

        def full_field_name(field)
          names = @parent_fields.map(&:name) + [field.name]
          names.join('.')
        end

        def add_error(type, **message_options)
          error_options = format_error_options(message_options)
          message = ERROR_MESSAGES.fetch(type) % error_options
          @error_messages << message
        end

        def format_error_options(message_options)
          return message_options unless message_options[:field]
          return message_options if message_options[:field].is_a?(String)

          field_name = full_field_name(message_options[:field])
          message_options.merge(field: field_name)
        end
      end
    end
  end
end
