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
            field :id, GraphQL::Types::ID, null: false
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

      it 'returns error message', :aggregate_failures do
        expect(error_messages.size).to eq(1)
        expect(error_messages.first).to match(/Method `name` for "name" field does not exist on record/)
      end
    end

    context 'when record field class in not compatible with graphql type field' do
      let(:record_params) { super().merge(name: 123) }

      it 'returns error message' do
        expect(error_messages).to eq(['Expected field "name" to be `String`, but was `Integer`'])
      end
    end

    context 'when type references itself' do
      let(:graphql_type) do
        Class.new(GraphQL::Schema::Object) do
          graphql_name "DummyUser#{rand(1**10)}"
          field :id, GraphQL::Types::ID, null: false
          field :itself, self, null: false
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
        enum = graphql_enum_type
        Class.new(super()) do
          graphql.attribute(:role).type(enum)
        end
      end

      let(:record_class) { Struct.new(:id, :name, :location, :role, keyword_init: true) }
      let(:record_params) { super().merge(role: :admin) }

      context 'when value matches enum' do
        it { is_expected.to be_empty }
      end

      context 'when value does not match enum' do
        let(:record_params) { super().merge(role: :invalid) }

        it 'returns error message' do
          expect(error_messages).to eq(['Expected value of the "role" enum field to be one of [:admin, :regular], but was `:invalid`'])
        end
      end
    end

    context 'with custom inner type' do
      let(:matcher) { super().tap(&:deeply) }

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

      let(:record_class) { Struct.new(:id, :name, :location, keyword_init: true) }
      let(:record_params) { super().merge(location: location) }
      let(:location) { double('Location', country: 'USA', city: 'New York') }

      context 'when using deep mode' do
        context 'when record matches graphql type' do
          it { is_expected.to be_empty }
        end

        context 'when nested type does not match' do
          let(:record_params) { super().merge(location: invalid_location) }
          let(:location) { Struct.new(:country, :city).new('USA', 123) }
          let(:invalid_location) { double('InvalidLocation', country: 'USA', city: 123) }

          it 'returns error message' do
            expect(error_messages).to eq(['Expected field "location.city" to be `String`, but was `Integer`'])
          end
        end

        context 'when nested type is an array' do
          let(:record_class) { Struct.new(:id, :name, :location, :locations, keyword_init: true) }
          let(:graphql_type) do
            location = location_type
            Class.new(super()) do
              graphql.attribute(:locations).type(location.to_list_type)
            end
          end
          let(:record_params) { super().merge(locations: locations) }
          let(:locations) { [location, location2] }
          let(:location2) { double('Location2', country: 'USA', city: 'Washington') }

          context 'when nested type matches' do
            it { is_expected.to be_empty }
          end

          context 'when one array item does not match' do
            let(:invalid_location) { double('InvalidLocation', country: 'USA', city: 123) }
            let(:locations) { [location, invalid_location] }

            it 'returns error message' do
              expect(error_messages).to eq(['Expected field "locations[1].city" to be `String`, but was `Integer`'])
            end
          end
        end
      end

      context 'when using shallow mode' do
        let(:matcher) { super().tap(&:shallow) }

        context 'when record matches graphql type' do
          it { is_expected.to be_empty }
        end

        context 'when nested type does not match' do
          let(:record_params) { super().merge(location: invalid_location) }
          let(:location) { Struct.new(:country, :city).new('USA', 123) }
          let(:invalid_location) { double('InvalidLocation', country: 'USA', city: 123) }

          it { is_expected.to be_empty }
        end
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
