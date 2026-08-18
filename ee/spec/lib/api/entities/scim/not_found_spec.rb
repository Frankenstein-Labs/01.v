# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Scim::NotFound, feature_category: :system_access do
  let(:entity) do
    described_class.new({})
  end

  subject(:json_response) { entity.as_json }

  it 'contains the schemas' do
    expect(json_response[:schemas]).not_to be_empty
  end

  it 'contains the detail' do
    expect(json_response[:detail]).to be_nil
  end

  it 'contains the status' do
    expect(json_response[:status]).to eq(404)
  end
end
