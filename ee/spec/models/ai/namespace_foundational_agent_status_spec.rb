# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::NamespaceFoundationalAgentStatus, feature_category: :ai_abstraction_layer do
  subject(:status) { build(:namespace_foundational_agent_statuses) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).class_name('Namespace') }
  end

  describe 'validations' do
    include_context 'with mocked Foundational Chat Agents'

    it { is_expected.to validate_presence_of(:reference) }
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

    describe 'uniqueness validation' do
      it 'validates uniqueness of reference scoped to namespace_id' do
        existing = create(:namespace_foundational_agent_statuses, reference: foundational_chat_agent_1_ref)
        duplicate = build(:namespace_foundational_agent_statuses,
          namespace_id: existing.namespace_id,
          reference: existing.reference)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:reference]).to include('has already been taken')
      end

      it 'allows same reference for different namespaces' do
        existing = create(:namespace_foundational_agent_statuses, reference: foundational_chat_agent_1_ref)
        different_namespace = build(:namespace_foundational_agent_statuses,
          reference: existing.reference)

        expect(different_namespace).to be_valid
      end
    end
  end
end
