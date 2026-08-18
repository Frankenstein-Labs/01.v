# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ComplianceViolationIssue,
  feature_category: :compliance_management do
  describe 'associations' do
    it 'belongs to project_compliance_violation' do
      is_expected.to belong_to(:project_compliance_violation)
        .class_name('ComplianceManagement::Projects::ComplianceViolation')
    end

    it { is_expected.to belong_to(:issue) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project_compliance_violation) }
    it { is_expected.to validate_presence_of(:issue) }
    it { is_expected.to validate_presence_of(:project) }

    describe 'custom validations' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:other_project) { create(:project, namespace: namespace) }
      let_it_be(:issue) { create(:issue, project: project) }
      let_it_be(:other_issue) { create(:issue, project: other_project) }
      let_it_be(:compliance_violation) { create(:project_compliance_violation, project: project, namespace: namespace) }

      let_it_be(:other_compliance_violation) do
        create(:project_compliance_violation, project: other_project, namespace: namespace)
      end

      describe '#violation_belongs_to_project' do
        context 'when compliance violation belongs to project' do
          subject(:violation_issue) do
            build(:project_compliance_violation_issue,
              project: project,
              issue: issue,
              project_compliance_violation: compliance_violation
            )
          end

          it 'is valid' do
            expect(violation_issue).to be_valid
          end
        end

        context 'when compliance violation does not belong to project' do
          subject(:violation_issue) do
            build(:project_compliance_violation_issue,
              project: project,
              issue: issue,
              project_compliance_violation: other_compliance_violation
            )
          end

          it 'is invalid' do
            expect(violation_issue).not_to be_valid
            expect(violation_issue.errors[:project_compliance_violation])
              .to include('must belong to the specified project')
          end
        end
      end
    end
  end
end
