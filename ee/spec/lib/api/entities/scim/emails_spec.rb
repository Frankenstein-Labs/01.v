# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Scim::Emails, feature_category: :system_access do
  let(:user) { build(:user) }
  let(:identity) { build(:group_saml_identity, user: user) }

  let(:entity) do
    described_class.new(user)
  end

  subject(:json_response) { entity.as_json }

  it 'contains the email' do
    expect(json_response[:value]).to eq(user.email)
  end

  it 'contains the type' do
    expect(json_response[:type]).to eq('work')
  end

  it 'contains the email' do
    expect(json_response[:primary]).to be true
  end
end
