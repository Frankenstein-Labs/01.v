# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFields::ArchiveService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let(:custom_field) { create(:custom_field, namespace: group) }

  let(:response) do
    described_class.new(custom_field: custom_field, current_user: user).execute
  end

  let(:updated_custom_field) { response.payload[:custom_field] }

  before do
    stub_licensed_features(custom_fields: true)
  end

  it 'archives the custom field' do
    expect(response).to be_success
    expect(updated_custom_field).not_to be_active
  end

  context 'when field is already archived' do
    let(:custom_field) { create(:custom_field, :archived, namespace: group) }

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to eq(described_class::AlreadyArchivedError.message)
    end
  end

  context 'when there are other validation errors' do
    before do
      custom_field.name = ''
      custom_field.save!(validate: false)
    end

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to include("Name can't be blank")
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
