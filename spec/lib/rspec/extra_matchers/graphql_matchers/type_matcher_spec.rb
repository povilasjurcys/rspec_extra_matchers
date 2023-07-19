# frozen_string_literal: true

require 'rspec/extra_matchers/graphql_matchers/type_matcher'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe RSpec::ExtraMatchers::GraphqlMatchers::TypeMatcher do
  subject(:matcher) { described_class.new(graphql_type) }

  let(:record_class) { Struct.new(:id, :name, :location, keyword_init: true) }
  let(:record) { record_class.new(record_params) }
  let(:record_params) { { id: '123', name: 'John', location: nil } }
  let(:graphql_type) do
    Class.new do
      include GraphqlRails::Model

      graphql do |c|
        c.name("DummyUser#{rand(1**10)}")
        c.attribute(:id).type('ID!')
        c.attribute(:name).type('String!')
      end
    end
  end

  describe '#error_messages' do
    subject(:error_messages) { matcher.error_messages }

    before do
      matcher.matches?(record)
    end

    context 'when record matches graphql type' do
      context 'when graphql type is a GraphqlRails::Model' do
        it { is_expected.to be_empty }
      end

      context 'when graphql type is a GraphQL::Schema::Object' do
        let(:graphql_type) do
          Class.new(GraphQL::Schema::Object) do
            graphql_name "DummyUser#{rand(1**10)}"
            field :id, Integer, null: false
            field :name, String, null: false
          end
        end

        it { is_expected.to be_empty }
      end
    end

    context 'when record field is nil, but graphql field is non-nullable' do
      let(:record_params) { super().merge(name: nil) }

      it 'returns error message' do
        expect(error_messages).to eq(['expected non-nullable field "name" not to be `nil`'])
      end
    end

    context 'when field on record does not exist' do
      let(:record) { Struct.new(:id).new(1337) }

      it 'returns error message' do
        expect(error_messages).to eq(['expected field "name" to be present'])
      end
    end

    context 'when record field class in not compatible with graphql type field' do
      let(:record_params) { super().merge(name: 123) }

      it 'returns error message' do
        expect(error_messages).to eq(['expected field "name" to be `String`, but was `Integer`'])
      end
    end

    context 'when type references itself' do
      let(:graphql_type) do
        Class.new(GraphQL::Schema::Object) do
          graphql_name "DummyUser#{rand(1**10)}"
          field :id, Integer, null: false
          field :myself, self, null: false
        end
      end

      it { is_expected.to be_empty }
    end

    context 'with enum type' do
      let(:graphql_enum_type) do
        Class.new(GraphQL::Schema::Enum) do
          graphql_name "DummyUserRole#{rand(1**10)}Enum"
          value 'ADMIN', value: :admin
          value 'REGULAR', value: :regular
        end
      end

      let(:graphql_type) do
        Class.new(super()) do
          graphql.attribute(:role).type(graphql_enum_type)
        end
      end

      it { is_expected.to be_empty }
    end

    context 'with custom type' do
      let(:location_type) do
        Class.new(GraphQL::Schema::Object) do
          graphql_name "DummyLocation#{rand(1**10)}"
          field :country, String, null: false
          field :city, String, null: false
        end
      end

      let(:graphql_type) do
        Class.new(super()) do
          graphql.attribute(:location).type(location_type)
        end
      end

      # it { is_expected.to be_empty }

      context 'when record matches graphql type' do
        it { is_expected.to be_empty }
      end

      context 'when nested type does not match' do
        let(:record_params) { super().merge(location: invalid_location) }
        let(:invalid_location) { double('location', country: 'USA', city: 123) }

        it 'returns error message' do
          expect(error_messages).to eq(['expected non-nullable field "location" not to be `nil`'])
        end
      end
    end

    context 'with deeply nested types' do
      let(:location_type) do
        Class.new(GraphQL::Schema::Object) do
          graphql_name "DummyLocation#{rand(1**10)}"
          field :country, String, null: false
          field :city, String, null: false
        end
      end

      let(:graphql_type) do
        location = location_type
        Class.new(super()) do
          graphql.attribute(:location).type(location)
        end
      end

      before do
        location_type.field :residents, [graphql_type], null: false
      end

      context 'when record matches graphql type' do
        it { is_expected.to be_empty }
      end

      context 'when record does not match graphql type' do
        let(:record_params) { super().merge(location: nil) }

        it 'returns error message' do
          expect(error_messages).to eq(['expected non-nullable field "location" not to be `nil`'])
        end
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
