# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Scim::Groups, feature_category: :system_access do
  let_it_be(:group1) { build(:saml_group_link, saml_group_name: 'Engineering', scim_group_uid: SecureRandom.uuid) }
  let_it_be(:group2) { build(:saml_group_link, saml_group_name: 'Marketing', scim_group_uid: SecureRandom.uuid) }

  let(:resources) { [group1, group2] }
  let(:options) { {} }

  let(:result_set) do
    {
      resources: resources,
      total_results: 2,
      items_per_page: 20,
      start_index: 1
    }
  end

  subject(:json_response) { described_class.represent(result_set, options).as_json }

  it 'exposes the correct SCIM schema' do
    expect(json_response[:schemas]).to eq(['urn:ietf:params:scim:api:messages:2.0:ListResponse'])
  end

  it 'exposes pagination metadata' do
    expect(json_response[:totalResults]).to eq(2)
    expect(json_response[:itemsPerPage]).to eq(20)
    expect(json_response[:startIndex]).to eq(1)
  end

  it 'exposes resources as an array' do
    expect(json_response[:Resources]).to be_an_instance_of(Array)
    expect(json_response[:Resources].length).to eq(2)
  end

  it 'represents each resource using the Group entity' do
    expect(json_response[:Resources][0][:displayName]).to eq('Engineering')
    expect(json_response[:Resources][1][:displayName]).to eq('Marketing')
  end

  context 'with excluded attributes' do
    let(:options) { { excluded_attributes: ['members'] } }

    it 'passes excluded_attributes to the Group entity' do
      expect(API::Entities::Scim::Group).to receive(:represent)
        .with(anything, hash_including(excluded_attributes: ['members']))
        .and_call_original

      json_response
    end
  end

  context 'with default values' do
    let(:result_set) { { resources: resources } }

    it 'uses default values for pagination metadata' do
      expect(json_response[:totalResults]).to eq(2)
      expect(json_response[:itemsPerPage]).to eq(Kaminari.config.default_per_page)
      expect(json_response[:startIndex]).to eq(1)
    end
  end

  context 'with empty resources' do
    let(:result_set) { {} }

    it 'handles empty resources gracefully' do
      expect(json_response[:Resources]).to eq([])
      expect(json_response[:totalResults]).to eq(0)
    end
  end
end
