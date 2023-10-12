# frozen_string_literal: true

# Usage:
# expect(user).to satisfy_graphql_type(UserDecorator)
# expect(user).to satisfy_graphql_type(Types::UserType)

module RSpec
  module ExtraMatchers
    module GraphqlMatchers
      # Matcher for testing graphql types
      class TypeMatcher
        require 'rspec/matchers/composable'

        include RSpec::Matchers::Composable

        ERROR_MESSAGES = {
          not_nullable: 'expected non-nullable field "%<field>s" not to be `nil`',
          nil_in_strict_mode:
            'Using `strictly` matcher which does not allow `nil` values, but field "%<field>s" is `nil`.' \
            'Use `loosely` matcher to allow `nil` values"',
          wrong_type: 'Expected field "%<field>s" to be %<expected_type>s, but was `%<actual_type>s`',
          missing_field: 'Method `%<property>s` for "%<field>s" field does not exist on record',
          wrong_enum_value: 'Expected value of the "%<field>s" enum field to be one of %<expected_values>s, ' \
                            'but was `%<actual_value>s`'
        }

        attr_reader :detailed_error_messages, :graphql_type, :record

        def initialize(graphql_type_or_model, field_prefix: '', checked_records: Set.new, deeply: true, strictly: true)
          @field_prefix = field_prefix
          @detailed_error_messages = []
          @deeply = deeply
          @strictly = strictly
          @graphql_type = extract_graphql_type(graphql_type_or_model)
          @checked_records = checked_records
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

        attr_reader :field_prefix, :checked_records

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
          graphql_type.unwrap.fields.each_value do |field|
            assert_field(field)
          end
        end

        def assert_field(field)
          return add_missing_field_error(field) unless record_field_exist?(field)

          value = fetch_value(field)

          return assert_nullable_field(field) if value.nil?
          return assert_list_field(value, field) if list_value?(value)
          return assert_basic_field(value, field) if basic_field?(field)
          return assert_enum_field(value, field) if enum_field?(field)
          return assert_nested_field(value, field) if assert_deeply?(value)
        end

        def list_value?(value)
          value.is_a?(Array) || value.is_a?(ActiveRecord::Relation)
        end

        def record_field_exist?(field)
          @record.respond_to?(field.name.underscore)
        end

        def fetch_value(field)
          @record.send(field.method_sym)
        end

        def add_missing_field_error(field)
          add_error(:missing_field, field: field, property: field.method_str)
        end

        def assert_nullable_field(field)
          if field.type.non_null?
            add_error(:not_nullable, field: field)
          elsif strict?
            add_error(:nil_in_strict_mode, field: field)
          end
        end

        def assert_list_field(value, field)
          value.each_with_index do |item, i|
            assert_nested_field(item, field, type: unwrap_list(field.type), suffix: "[#{i}]")
          end
        end

        def unwrap_list(type)
          type = type.of_type while type.list?
          type
        end

        def assert_basic_field(value, field)
          compatible_classes = compatible_classes_for(field.type.unwrap)
          return if compatible_classes.any? { |klass| value.is_a?(klass) }

          expected_type =
            if compatible_classes.count > 1
              "one of `#{compatible_classes}`"
            else
              "`#{compatible_classes.first}`"
            end

          add_error(:wrong_type, field: field, expected_type: expected_type, actual_type: value.class.to_s)
        end

        def compatible_classes_for(graphql_scalar) # rubocop:disable Metrics/MethodLength
          if graphql_scalar <= GraphQL::Types::Int
            [Integer]
          elsif graphql_scalar <= GraphQL::Types::ID
            [Integer, String]
          elsif graphql_scalar <= GraphQL::Types::String
            [String]
          elsif graphql_scalar <= GraphQL::Types::Float
            [Float, Integer, Numeric]
          elsif graphql_scalar <= GraphQL::Types::Boolean
            [TrueClass, FalseClass]
          elsif graphql_scalar <= GraphQL::Types::ISO8601DateTime
            [Time, DateTime]
          elsif graphql_scalar <= GraphQL::Types::ISO8601Date
            [Date]
          elsif graphql_scalar <= GraphQL::Types::JSON
            [Hash, Array, String, Integer, Float, TrueClass, FalseClass, NilClass]
          else
            raise "Unknown scalar type #{graphql_scalar}"
          end
        end

        def assert_enum_field(value, field)
          expected_values = field.type.unwrap.values.values.map(&:value)
          return if expected_values.include?(value)

          message_options = {
            field: field,
            expected_values: expected_values.inspect,
            actual_value: value.inspect
          }
          add_error(:wrong_enum_value, **message_options)
        end

        def assert_nested_field(value, field, type: field.type, suffix: '')
          full_field_prefix = full_field_name(field, suffix: suffix)
          all_checked_records = checked_records + [value]
          inner_matcher = self.class.new(
            type,
            field_prefix: full_field_prefix,
            checked_records: all_checked_records
          )
          return if inner_matcher.matches?(value)

          @detailed_error_messages += inner_matcher.detailed_error_messages
        end

        def basic_field?(field)
          field.type.unwrap < GraphQL::Schema::Scalar
        end

        def enum_field?(field)
          field.type.unwrap < GraphQL::Schema::Enum
        end

        def full_field_name(field, suffix: '')
          [field_prefix, "#{field.name}#{suffix}", ].reject(&:blank?).join('.')
        end

        def error_message_for(type:, **error_options)
          format(ERROR_MESSAGES.fetch(type), error_options)
        end

        def add_error(type, **message_options)
          @detailed_error_messages << format_error_options(message_options).merge(type: type)
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
