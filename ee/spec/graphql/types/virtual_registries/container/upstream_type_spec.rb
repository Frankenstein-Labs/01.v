# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ContainerUpstream'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  it 'uses CountableConnectionType' do
    expect(described_class.connection_type_class).to eq(::Types::CountableConnectionType)
  end

  it { is_expected.to have_attributes(interfaces: include(Types::VirtualRegistries::UpstreamInterface)) }
  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }

  describe 'expected fields' do
    let(:expected_field_types) do
      {
        id: 'ID!',
        name: 'String!',
        description: 'String',
        url: 'String!',
        cacheValidityHours: 'Int!',
        username: 'String',
        registriesCount: 'Int!'
      }
    end

    it 'are exposed' do
      expect(described_class).to have_graphql_fields(*expected_field_types.keys)
      expected_field_types.each do |field_name, type_signature|
        expect(described_class.fields[field_name.to_s].type.to_type_signature).to eq(type_signature)
      end
    end
  end

  describe 'username field authorization' do
    let(:current_user) { instance_double(User) }
    let(:object) { instance_double(VirtualRegistries::Container::Upstream) }
    let(:ctx) { { current_user: current_user } }

    subject(:username_field) { described_class.fields['username'] }

    before do
      allow(Ability).to receive(:allowed?).with(current_user, :update_virtual_registry,
        object).and_return(update_virtual_registry_ability)
    end

    context 'when user has update_virtual_registry ability' do
      let(:update_virtual_registry_ability) { true }

      it 'authorizes the field' do
        expect(username_field).to be_authorized(object, nil, ctx)
      end
    end

    context 'when user does not have update_virtual_registry ability' do
      let(:update_virtual_registry_ability) { false }

      it 'does not authorize the field' do
        expect(username_field).not_to be_authorized(object, nil, ctx)
      end
    end
  end
end
