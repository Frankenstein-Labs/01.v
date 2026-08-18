# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Scim::UserName, feature_category: :system_access do
  let(:user) { build(:user) }

  subject(:json_response) { described_class.new(user).as_json }

  it 'contains the name' do
    expect(json_response[:formatted]).to eq(user.name)
  end

  it 'contains the first name' do
    expect(json_response[:givenName]).to eq(user.first_name)
  end

  it 'contains the last name' do
    expect(json_response[:familyName]).to eq(user.last_name)
  end
end
