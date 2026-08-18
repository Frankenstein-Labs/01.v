# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::RepresentationInformation, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:vulnerability) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'scopes' do
    describe '.by_vulnerability' do
      let_it_be(:project) { create(:project) }
      let_it_be(:vulnerability_1) { create(:vulnerability, project: project) }
      let_it_be(:vulnerability_2) { create(:vulnerability, project: project) }
      let_it_be(:representation_1) do
        create(:vulnerability_representation_information, vulnerability: vulnerability_1)
      end

      let_it_be(:representation_2) do
        create(:vulnerability_representation_information, vulnerability: vulnerability_2)
      end

      it 'returns representation information for the specified vulnerabilities' do
        result = described_class.by_vulnerability([vulnerability_1.id])

        expect(result).to contain_exactly(representation_1)
      end

      it 'returns multiple records when multiple vulnerability IDs are provided' do
        result = described_class.by_vulnerability([vulnerability_1.id, vulnerability_2.id])

        expect(result).to contain_exactly(representation_1, representation_2)
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:vulnerability) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_length_of(:resolved_in_commit_sha).is_at_most(64) }
  end

  describe 'SHA attribute fields' do
    subject(:sha_attribute_fields) { described_class.sha_attribute_fields }

    it 'includes the resolved_in_commit_sha attribute' do
      is_expected.to contain_exactly(:resolved_in_commit_sha)
    end
  end

  context 'with loose foreign key on vulnerability_feedback.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) do
        create(:vulnerability_representation_information, vulnerability: create(:vulnerability, project: parent))
      end
    end
  end
end
