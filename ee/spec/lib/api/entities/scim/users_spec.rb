# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Scim::Users, feature_category: :system_access do
  let(:user) { build(:user) }
  let(:identity) { build(:group_saml_identity, user: user) }

  let(:entity) do
    described_class.new(resources: [identity])
  end

  subject(:json_response) { entity.as_json }

  it 'contains the schemas' do
    expect(json_response[:schemas]).to eq(['urn:ietf:params:scim:api:messages:2.0:ListResponse'])
  end

  it 'calculates the totalResults' do
    expect(json_response[:totalResults]).to eq(1)
  end

  it 'contains the default itemsPerPage' do
    expect(json_response[:itemsPerPage]).to eq(20)
  end

  it 'contains the default startIndex' do
    expect(json_response[:startIndex]).to eq(1)
  end

  it 'contains the user' do
    expect(json_response[:Resources]).not_to be_empty
  end

  it 'contains the user ID' do
    expect(json_response[:Resources].first[:id]).to eq(identity.extern_uid)
  end

  context 'with configured values' do
    let(:entity) do
      described_class.new(resources: [identity], total_results: 31, items_per_page: 10, start_index: 30)
    end

    it 'contains the configured totalResults' do
      expect(json_response[:totalResults]).to eq(31)
    end

    it 'contains the configured itemsPerPage' do
      expect(json_response[:itemsPerPage]).to eq(10)
    end

    it 'contains the configured startIndex' do
      expect(json_response[:startIndex]).to eq(30)
    end
  end
end
