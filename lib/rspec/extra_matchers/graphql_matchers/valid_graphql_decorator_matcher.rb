# frozen_string_literal: true

# Usage:
# expect(UserDecorator).to be_valid_graphql_type_for(user)
# expect(Types::UserType).to be_valid_graphql_type_for(user)

require 'rspec/extra_matchers/graphql_matchers/type_matcher'

module RSpec
  module ExtraMatchers
    module GraphqlMatchers
      # Matcher for testing graphql types
      class ValidGraphqlDecoratorMatcher < ValidGraphqlTypeMatcher
        def initialize
          super(nil)
        end

        def matches?(decorator_instance)
          @record = decorator_instance
          super(decorator_instance.class)
        end
      end
    end
  end
end
