# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindingDueDate, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:finding).required }
    it { is_expected.to belong_to(:project).required }
  end

  describe 'validations' do
    subject { build(:vulnerability_finding_due_date) }

    it { is_expected.to validate_presence_of(:due_date) }
    it { is_expected.to validate_uniqueness_of(:vulnerability_occurrence_id) }

    it 'is invalid when project does not match finding project' do
      finding = create(:vulnerabilities_finding)
      other_project = create(:project)

      record = build(
        :vulnerability_finding_due_date,
        finding: finding,
        project: other_project
      )

      expect(record).to be_invalid
      expect(record.errors[:project_id]).to be_present
    end
  end

  describe '.by_finding_ids' do
    let_it_be(:project) { create(:project) }
    let_it_be(:finding1) { create(:vulnerabilities_finding, project: project) }
    let_it_be(:finding2) { create(:vulnerabilities_finding, project: project) }
    let_it_be(:finding3) { create(:vulnerabilities_finding, project: project) }

    let_it_be(:due_date1) { create(:vulnerability_finding_due_date, finding: finding1, project: project) }
    let_it_be(:due_date2) { create(:vulnerability_finding_due_date, finding: finding2, project: project) }
    let_it_be(:due_date3) { create(:vulnerability_finding_due_date, finding: finding3, project: project) }

    it 'returns records matching given finding ids' do
      result = described_class.by_finding_ids([finding1.id, finding2.id])

      expect(result).to match_array([due_date1, due_date2])
    end

    it 'returns empty when no ids match' do
      result = described_class.by_finding_ids([-1])

      expect(result).to be_empty
    end

    it 'returns all when all ids provided' do
      result = described_class.by_finding_ids([finding1.id, finding2.id, finding3.id])

      expect(result).to match_array([due_date1, due_date2, due_date3])
    end
  end
end
