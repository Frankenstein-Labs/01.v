# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFields::UnarchiveService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let(:custom_field) { create(:custom_field, :archived, namespace: group) }

  let(:response) do
    described_class.new(custom_field: custom_field, current_user: user).execute
  end

  let(:updated_custom_field) { response.payload[:custom_field] }

  before do
    stub_licensed_features(custom_fields: true)
  end

  it 'unarchives the custom field' do
    expect(response).to be_success
    expect(updated_custom_field).to be_active
  end

  context 'when field is already active' do
    let(:custom_field) { create(:custom_field, namespace: group) }

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to eq(described_class::AlreadyActiveError.message)
    end
  end

  context 'when number of active fields is at the limit' do
    before do
      stub_const('Issuables::CustomField::MAX_ACTIVE_FIELDS', 2)

      create_list(:custom_field, 2, namespace: group)
    end

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to include('Namespace can only have a maximum of 2 active custom fields.')
    end
  end

  context 'when user does not have access' do
    let(:user) { create(:user, guest_of: group) }

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to eq(described_class::NotAuthorizedError.message)
    end
  end
end
