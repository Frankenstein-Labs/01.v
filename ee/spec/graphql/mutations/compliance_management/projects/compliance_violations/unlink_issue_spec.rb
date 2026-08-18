# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::Projects::ComplianceViolations::UnlinkIssue,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:violation) { create(:project_compliance_violation, project: project, namespace: group) }
  let_it_be(:issue) { create(:issue, project: project) }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  let(:violation_gid) { violation.to_global_id }
  let(:issue_iid) { issue.iid }
  let(:project_path) { project.full_path }

  let(:params) do
    {
      violation_id: violation_gid,
      project_path: project_path,
      issue_iid: issue_iid
    }
  end

  before_all do
    group.add_owner(current_user)
    create(:project_compliance_violation_issue,
      project: project,
      issue: issue,
      project_compliance_violation: violation
    )
  end

  subject(:mutate) { mutation.resolve(**params) }

  describe '#resolve' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: true)
      end

      context 'when user is authorized' do
        context 'when params are correct' do
          it 'unlinks the issue from the violation' do
            expect { mutate }.to change { violation.reload.issues.count }.by(-1)
          end
        end
      end

      context 'when user is not authorized' do
        before_all do
          group.add_maintainer(current_user)
        end

        it 'raises authorization error' do
          expect { mutate }
            .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: false)
      end

      it 'raises authorization error' do
        expect { mutate }
          .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
