# frozen_string_literal: true

require 'rspec/extra_matchers/graphql_matchers/valid_graphql_decorator_matcher'

RSpec.describe RSpec::ExtraMatchers::GraphqlMatchers::ValidGraphqlDecoratorMatcher do
  subject(:matcher) { described_class.new }

  let(:record_params) { { id: '123', name: 'John' } }
  let(:graphql_decorator) do
    Class.new do
      include GraphqlRails::Model

      graphql do |c|
        c.name("DummyUser#{rand(1**10)}")
        c.attribute(:id).type('ID!')
        c.attribute(:name).type('String!')
      end

      attr_reader :id, :name

      def initialize(id:, name:)
        @id = id
        @name = name
      end
    end
  end
  let(:graphql_decorator_instance) { graphql_decorator.new(**record_params) }

  describe '#error_messages' do
    subject(:error_messages) { matcher.error_messages }

    before do
      matcher.matches?(graphql_decorator_instance)
    end

    context 'when record matches graphql type' do
      it { is_expected.to be_empty }
    end

    context 'when record field is nil, but graphql field is non-nullable' do
      let(:record_params) { super().merge(name: nil) }

      it 'returns error message' do
        expect(error_messages).to eq(['expected non-nullable field "name" not to be `nil`'])
      end
    end
  end
end
