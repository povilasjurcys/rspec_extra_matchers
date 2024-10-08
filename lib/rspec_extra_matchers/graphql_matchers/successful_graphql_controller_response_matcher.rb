# frozen_string_literal: true

require 'active_support/core_ext/string/indent'

require_relative 'type_matcher'

module RSpecExtraMatchers
  module GraphqlMatchers
    # Matcher for testing graphql types
    class SuccessfulGraphqlControllerResponseMatcher
      DEFAULT_ERROR_MESSAGE = 'Response is not successful'

      def matches?(controller_response)
        @controller_response = controller_response

        validate_response_status && validate_response_type
      end

      def failure_message
        error_message || DEFAULT_ERROR_MESSAGE
      end

      private

      attr_reader :controller_response, :error_message

      def validate_response_status
        return true if controller_response.success?

        add_error(DEFAULT_ERROR_MESSAGE)
        false
      end

      def validate_response_type
        validate_response_type_null_matching &&
          validate_response_type_list_matching &&
          validate_response_graphql_attributes_matching

        error_message.nil?
      end

      def validate_response_type_null_matching
        if action_response_graphql_type.non_null? && response_result.nil?
          add_error('Response type is not nullable, but the result is nil')
        end

        error_message.nil?
      end

      def validate_response_type_list_matching
        if action_response_graphql_type.list? && !list_response?
          add_error('Response type is a list, but the result is not a list-like object')
        elsif !action_response_graphql_type.list? && list_response?
          add_error('Response type is not a list, but the result is a list-like object')
        end

        error_message.nil?
      end

      def validate_response_graphql_attributes_matching
        result_instance = list_response? ? response_result.first : response_result
        matcher = TypeMatcher.new(action_response_graphql_type.unwrap, deeply: false, strictly: false)
        matcher.matches?(result_instance)
        return if matcher.error_messages.empty?

        error_message =
          "Response type does not match the expected type:\n" \
          "#{matcher.error_messages.take(5).join("\n").indent(2)}"

        add_error(error_message)
      end

      def list_response?
        return false if response_result.is_a?(Hash)
        return false if defined?(ActionController::Parameters) && response_result.is_a?(ActionController::Parameters)

        response_result.respond_to?(:each)
      end

      def controller
        controller_response.controller
      end

      def action_name
        controller_response.action_name
      end

      def response_result
        controller_response.result
      end

      def validate_shallow_attributes_matching
        matcher = TypeMatcher.new(action_response_graphql_type, deeply: false, strictly: false)
        matcher.matches?(response_result)
        return if matcher.error_messages.empty?

        error_message =
          "Response type does not match the expected type:\n" \
          "#{matcher.error_messages.take(5).join("\n").indent(2)}"

        add_error(error_message)
      end

      def action_response_graphql_type
        @action_response_graphql_type ||= controller.action(action_name).type_parser.graphql_type
      end

      def action_response_graphql_model
        return @action_response_graphql_model if defined?(@action_response_graphql_model)

        @action_response_graphql_model = controller.action(action_name).type_parser.graphql_model
      end

      def add_error(error_message)
        @error_message = error_message
      end
    end
  end
end
