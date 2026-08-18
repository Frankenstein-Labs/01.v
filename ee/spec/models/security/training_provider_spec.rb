# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::TrainingProvider, feature_category: :vulnerability_management do
  describe '.for_project' do
    let_it_be(:project, reload: true) { create(:project) }
    let(:only_enabled) { false }

    subject { described_class.for_project(project, only_enabled: only_enabled) }

    describe 'when no training providers are configured for a project' do
      context 'when only_enabled is false' do
        it 'returns all providers' do
          is_expected.to eq(described_class.all)
        end
      end

      context 'when only_enabled is true' do
        let(:only_enabled) { true }

        it 'returns no providers' do
          is_expected.to eq([])
        end
      end
    end

    describe 'when a training provider is configured for a project' do
      let_it_be(:training_1) { create(:security_training, :primary, :kontra, project: project) }
      let_it_be(:training_2) { create(:security_training, :secure_code_warrior, project: project) }

      context 'when only_enabled is false' do
        it 'returns all training providers with the configured one marked as enabled' do
          is_expected.to match_array([
            an_object_having_attributes(name: 'Kontra', is_primary: true, is_enabled: true),
            an_object_having_attributes(name: 'Secure Code Warrior', is_primary: false, is_enabled: true),
            an_object_having_attributes(name: 'SecureFlag', is_primary: false, is_enabled: false)
          ])
        end
      end

      context 'when only_enabled is true' do
        let(:only_enabled) { true }

        it 'returns the only enabled training provider' do
          is_expected.to match_array([
            an_object_having_attributes(name: 'Kontra', is_primary: true, is_enabled: true),
            an_object_having_attributes(name: 'Secure Code Warrior', is_primary: false, is_enabled: true)
          ])
        end
      end
    end
  end
end
