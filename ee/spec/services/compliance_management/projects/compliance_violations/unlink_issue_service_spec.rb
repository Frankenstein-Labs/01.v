# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ComplianceViolations::UnlinkIssueService, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:violation) { create(:project_compliance_violation, project: project, namespace: group) }
  let_it_be(:issue) { create(:issue, project: project) }

  let(:service) { described_class.new(current_user: user, violation: violation, issue: issue) }

  before do
    create(:project_compliance_violation_issue,
      project: project,
      issue: issue,
      project_compliance_violation: violation
    )
  end

  before_all do
    group.add_owner(user)
  end

  describe '#execute' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: true)
      end

      context 'when unlinking is successful' do
        it 'deletes compliance violation issue link' do
          expect { service.execute }.to change { ComplianceManagement::Projects::ComplianceViolationIssue.count }.by(-1)
        end

        it 'creates a system note' do
          expect { service.execute }.to change { Note.where(noteable_id: violation.id).count }.by(1)
        end

        it 'returns success response' do
          result = service.execute

          expect(result).to be_success
        end
      end

      context 'when issue is nil' do
        let(:service) { described_class.new(current_user: user, violation: violation, issue: nil) }

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Issue and violation should be non nil.")
        end
      end

      context 'when violation is nil' do
        let(:service) { described_class.new(current_user: user, violation: nil, issue: issue) }

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Issue and violation should be non nil.")
        end
      end

      context 'when link record fails to delete' do
        before do
          allow(violation).to receive_message_chain(:issues, :include?).and_return(true)
          allow(violation).to receive_message_chain(:issues, :destroy).and_return(false)
          allow(issue).to receive_message_chain(:errors, :full_messages).and_return(['Destroy error'])
        end

        it 'returns error response', :aggregate_failures do
          expect(Gitlab::ErrorTracking).to receive(:track_and_raise_exception).with(
            StandardError.new('Failed to unlink issue from violation: Destroy error'),
            { violation_id: violation.id, issue_id: issue.id }
          )

          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Failed to unlink issue')
        end
      end

      context 'when issue is not linked to violation' do
        before do
          ComplianceManagement::Projects::ComplianceViolationIssue.delete_all
        end

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Issue ID #{issue.id} is not linked to violation ID #{violation.id}")
        end

        it 'does not create a system note' do
          expect { service.execute }.not_to change { Note.where(noteable_id: violation.id).count }
        end
      end

      context 'when user lacks compliance violation permissions' do
        before_all do
          group.add_maintainer(user)
        end

        it 'returns access denied error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Access denied for user id: #{user.id}")
        end

        it 'does not delete link' do
          expect { service.execute }.not_to change { ComplianceManagement::Projects::ComplianceViolationIssue.count }
        end
      end

      context 'when user lacks issue read permissions' do
        let_it_be(:other_project) { create(:project) }
        let_it_be(:other_issue) { create(:issue, project: other_project) }
        let(:service) { described_class.new(current_user: user, violation: violation, issue: other_issue) }

        before do
          create(:project_compliance_violation_issue,
            project: project,
            issue: other_issue,
            project_compliance_violation: violation
          )
        end

        it 'deletes compliance violation issue link' do
          expect { service.execute }.to change { ComplianceManagement::Projects::ComplianceViolationIssue.count }.by(-1)
        end

        it 'returns success response' do
          result = service.execute

          expect(result).to be_success
        end
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: false)
      end

      it 'returns access denied error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Access denied for user id: #{user.id}")
      end
    end
  end
end
