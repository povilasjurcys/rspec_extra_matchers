# frozen_string_literal: true

require 'rspec_extra_matchers/graphql_matchers'
require 'graphql'
require 'graphql_rails'

RSpec.describe RSpecExtraMatchers::GraphqlMatchers do
  include RSpecExtraMatchers::GraphqlMatchers # rubocop:disable RSpec/DescribedClass

  let(:record_class) { Struct.new(:id, :name, :location, keyword_init: true) }
  let(:record) { record_class.new(record_params) }
  let(:record_params) { { id: '123', name: 'John', location: nil } }
  let(:graphql_rails_decorator) do
    Class.new do
      include GraphqlRails::Model

      graphql do |c|
        c.name("DummyUser#{rand(1**10)}")
        c.attribute(:id).type('ID!')
        c.attribute(:name).type('String!')
      end

      delegate :id, :name, :location, to: :@record

      def initialize(record)
        @record = record
      end
    end
  end

  let(:graphql_type) do
    Class.new(GraphQL::Schema::Object) do
      graphql_name "DummyUser#{rand(1**10)}"

      field :id, String, null: false
      field :name, String, null: false
    end
  end

  describe '#satisfy_graphql_type' do
    context 'when checking GraphQL::Schema::Object' do
      it 'passes when the graphql type satisfies the record' do
        expect(record).to satisfy_graphql_type(graphql_type)
      end
    end

    context 'when checking GraphqlRails::Model' do
      it 'passes when the graphql type satisfies the record' do
        expect(record).to satisfy_graphql_type(graphql_rails_decorator)
      end
    end
  end

  describe '#be_valid_graphql_type_for' do
    context 'when checking GraphQL::Schema::Object' do
      it 'passes when the graphql type satisfies the record' do
        expect(graphql_type).to be_valid_graphql_type_for(record)
      end
    end

    context 'when checking GraphqlRails::Model' do
      it 'passes when the graphql type satisfies the record' do
        expect(graphql_rails_decorator).to be_valid_graphql_type_for(record)
      end
    end
  end

  describe '#be_valid_graphql_decorator' do
    let(:graphql_decorator_instance) { graphql_rails_decorator.new(record) }

    context 'when checking GraphqlRails::Model' do
      it 'passes when the graphql type satisfies the record' do
        expect(graphql_decorator_instance).to be_valid_graphql_decorator
      end
    end

    context 'when checking non-decorator' do
      let(:graphql_decorator_instance) { record }

      it 'fails' do
        expect(graphql_decorator_instance).not_to be_valid_graphql_decorator
      end
    end
  end
end
