# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Settings', feature_category: :ai_abstraction_layer do
  subject(:load_file) { load Rails.root.join('ee/db/fixtures/production/041_create_ai_settings.rb') }

  let_it_be(:organizations) { create_list(:organization, 2) }

  it 'creates an AI settings record for every organization' do
    load_file

    organizations.each do |organization|
      expect(Ai::Setting.find_by(organization_id: organization.id)).to be_present
    end

    expect(Ai::Setting.count).to eq(Organizations::Organization.count)
  end

  it 'does not raise when records already exist' do
    Organizations::Organization.find_each do |organization|
      Ai::Setting.for_organization(organization)
    end

    expect { load_file }.not_to raise_error
    expect(Ai::Setting.count).to eq(Organizations::Organization.count)
  end
end
