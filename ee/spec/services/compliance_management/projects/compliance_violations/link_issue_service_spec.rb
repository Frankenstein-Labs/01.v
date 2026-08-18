# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ComplianceViolations::LinkIssueService, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:violation) { create(:project_compliance_violation, project: project, namespace: group) }
  let_it_be(:issue) { create(:issue, project: project) }

  let(:service) { described_class.new(current_user: user, violation: violation, issue: issue) }

  before_all do
    group.add_owner(user)
  end

  describe '#execute' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: true)
      end

      context 'when linking is successful' do
        it 'creates a compliance violation issue link' do
          expect { service.execute }.to change { ComplianceManagement::Projects::ComplianceViolationIssue.count }.by(1)
        end

        it 'creates a system note' do
          expect { service.execute }.to change { Note.where(noteable_id: violation.id).count }.by(1)
        end

        it 'returns success response' do
          result = service.execute

          expect(result).to be_success
        end

        it 'sets correct attributes on the link record' do
          service.execute

          link = ComplianceManagement::Projects::ComplianceViolationIssue.last
          expect(link.issue).to eq(issue)
          expect(link.project_compliance_violation).to eq(violation)
          expect(link.project).to eq(project)
        end
      end

      context 'when issue is nil' do
        let(:issue) { nil }

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Issue and violation should be non nil.")
        end
      end

      context 'when violation is nil' do
        let(:violation) { nil }

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Issue and violation should be non nil.")
        end
      end

      context 'when issue is already linked to violation' do
        before do
          create(:project_compliance_violation_issue,
            project_compliance_violation: violation,
            issue: issue,
            project: project)
        end

        it 'does not create duplicate link' do
          expect { service.execute }.not_to change { ComplianceManagement::Projects::ComplianceViolationIssue.count }
        end

        it 'does not create a system note' do
          expect { service.execute }.not_to change { Note.where(noteable_id: violation.id).count }
        end

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Issue ID #{issue.id} is already linked to violation ID #{violation.id}")
        end
      end

      context 'when link record fails to save' do
        before do
          allow_next_instance_of(ComplianceManagement::Projects::ComplianceViolationIssue) do |instance|
            allow(instance).to receive_messages(
              save: false, errors: instance_double(ActiveModel::Errors, full_messages: ['Validation failed'])
            )
          end
        end

        it 'returns error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Failed to link issue: Validation failed')
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

        it 'does not create link' do
          expect { service.execute }.not_to change { ComplianceManagement::Projects::ComplianceViolationIssue.count }
        end
      end

      context 'when user lacks issue read permissions' do
        let_it_be(:other_project) { create(:project) }
        let_it_be(:other_issue) { create(:issue, project: other_project) }
        let(:service) { described_class.new(current_user: user, violation: violation, issue: other_issue) }

        it 'returns access denied error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq("Access denied for user id: #{user.id}")
        end
      end

      context 'when issue belongs to different project' do
        context 'when user does not have access to the other project issues' do
          let_it_be(:other_group) { create(:group, :private) }
          let_it_be(:other_project) { create(:project, :private, group: other_group) }
          let_it_be(:other_issue) { create(:issue, project: other_project) }
          let(:service) { described_class.new(current_user: user, violation: violation, issue: other_issue) }

          it 'returns access denied error' do
            result = service.execute

            expect(result).to be_error
            expect(result.message).to eq("Access denied for user id: #{user.id}")
          end
        end

        context 'when user has access to the other project issues' do
          context 'when the project and issue are public' do
            let_it_be(:other_group) { create(:group, :public) }
            let_it_be(:other_project) { create(:project, :public, group: other_group) }
            let_it_be(:other_issue) { create(:issue, project: other_project) }
            let(:service) { described_class.new(current_user: user, violation: violation, issue: other_issue) }

            it 'creates a compliance violation issue link' do
              expect { service.execute }
                .to change { ComplianceManagement::Projects::ComplianceViolationIssue.count }.by(1)
            end

            it 'returns success response' do
              result = service.execute

              expect(result).to be_success
            end
          end

          context 'when the project and issue are private' do
            let_it_be(:other_group) { create(:group, :private) }
            let_it_be(:other_project) { create(:project, :private, group: other_group) }
            let_it_be(:other_issue) { create(:issue, project: other_project) }
            let(:service) { described_class.new(current_user: user, violation: violation, issue: other_issue) }

            before_all do
              other_project.add_guest(user)
            end

            it 'creates a compliance violation issue link' do
              expect { service.execute }
                .to change { ComplianceManagement::Projects::ComplianceViolationIssue.count }.by(1)
            end

            it 'returns success response' do
              result = service.execute

              expect(result).to be_success
            end
          end
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
