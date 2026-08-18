# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::OrganizationFoundationalAgentStatus, feature_category: :ai_abstraction_layer do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization').optional }
  end

  include_context 'with mocked Foundational Chat Agents'

  subject(:status) { build(:organization_foundational_agents_status, reference: foundational_chat_agent_1_ref) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:reference) }
    it { is_expected.to validate_uniqueness_of(:reference).scoped_to(:organization_id) }
    it { is_expected.to validate_length_of(:reference).is_at_most(255) }
    it { is_expected.to validate_inclusion_of(:enabled).in_array([true, false]) }

    context 'when reference is valid' do
      it 'is valid' do
        status.reference = foundational_chat_agent_1_ref
        expect(status).to be_valid
      end
    end

    context 'when reference is invalid' do
      it 'adds an error' do
        status.reference = invalid_agent_reference
        expect(status).not_to be_valid
        expect(status.errors[:reference]).to include('is not a valid foundational agent reference')
      end
    end
  end
end
