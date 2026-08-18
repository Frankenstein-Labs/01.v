# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulePolicy, feature_category: :source_code_management do
  let_it_be_with_refind(:project) { create(:project, :private) }
  let(:rule_type) { :regular }
  let_it_be(:guest) { create(:user) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }

  let(:user) { guest }

  subject(:permissions) { described_class.new(user, approval_rule) }

  context 'when the rule originates from project' do
    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_project,
        project: project,
        project_id: project.id,
        rule_type: rule_type
      )
    end

    context 'and the user has permission to read the project' do
      let(:user) { maintainer }

      it { is_expected.to be_allowed(:read_approval_rule) }
    end

    context 'and the user has permission to change project settings' do
      let(:user) { maintainer }

      it { is_expected.to be_allowed(:edit_approval_rule) }
    end

    context 'and the user lacks the required access level' do
      it { is_expected.not_to be_allowed(:edit_approval_rule) }
      it { is_expected.not_to be_allowed(:read_approval_rule) }
    end
  end

  context 'when the rule originates from a merge request' do
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_merge_request, merge_request: merge_request, project_id: project.id,
        rule_type: rule_type)
    end

    context 'when approval rule is user_defined' do
      before do
        allow(approval_rule).to receive(:user_defined?).and_return(true)
      end

      context 'and user can update_approvers' do
        let(:user) { maintainer }

        it { is_expected.to be_allowed(:edit_approval_rule) }
      end

      context 'and user cannot update_approvers' do
        let(:user) { developer }

        it { is_expected.not_to be_allowed(:edit_approval_rule) }
      end
    end

    context 'when approval rule is not user_defined' do
      before do
        allow(approval_rule).to receive(:user_defined?).and_return(false)
      end

      context 'and user can update_approvers' do
        let(:user) { maintainer }

        it { is_expected.not_to be_allowed(:edit_approval_rule) }
      end

      context 'and user cannot update_approvers' do
        let(:user) { developer }

        it { is_expected.not_to be_allowed(:edit_approval_rule) }
      end
    end
  end

  context 'when instance-level approval rule lock is enabled' do
    before do
      stub_licensed_features(admin_merge_request_approvers_rules: true)
      stub_application_setting(disable_overriding_approvers_per_merge_request: true)
    end

    context 'for project-origin rule' do
      let(:approval_rule) do
        build(:merge_requests_approval_rule, :from_project,
          project: project,
          project_id: project.id,
          rule_type: rule_type
        )
      end

      context 'when user is maintainer' do
        let(:user) { maintainer }

        it { is_expected.to be_disallowed(:edit_approval_rule) }
      end

      context 'when user is admin', :enable_admin_mode do
        let(:user) { create(:admin) }

        it { is_expected.to be_allowed(:edit_approval_rule) }
      end
    end

    context 'for merge-request-origin rule' do
      let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      let(:approval_rule) do
        build(:merge_requests_approval_rule, :from_merge_request, merge_request: merge_request, project_id: project.id,
          rule_type: rule_type)
      end

      before do
        allow(approval_rule).to receive(:user_defined?).and_return(true)
      end

      context 'when user is maintainer' do
        let(:user) { maintainer }

        it { is_expected.to be_disallowed(:edit_approval_rule) }
      end

      context 'when user is admin', :enable_admin_mode do
        let(:user) { create(:admin) }

        before do
          allow(project).to receive(:can_override_approvers?).and_return(true)
        end

        it { is_expected.to be_allowed(:edit_approval_rule) }
      end
    end
  end

  context 'when the instance-level setting locks per-merge-request overrides' do
    before do
      stub_application_setting(disable_overriding_approvers_per_merge_request: true)
    end

    context 'with admin_merge_request_approvers_rules license' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: true)
      end

      context 'for project-origin rule' do
        let(:approval_rule) do
          build(:merge_requests_approval_rule, :from_project,
            project: project,
            project_id: project.id,
            rule_type: rule_type
          )
        end

        context 'when user is maintainer' do
          let(:user) { maintainer }

          it { is_expected.to be_disallowed(:edit_approval_rule) }
        end

        context 'when user is admin', :enable_admin_mode do
          let(:user) { create(:admin) }

          it { is_expected.to be_allowed(:edit_approval_rule) }
        end
      end

      context 'for merge-request-origin rule' do
        let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

        let(:approval_rule) do
          build(:merge_requests_approval_rule, :from_merge_request, merge_request: merge_request,
            project_id: project.id, rule_type: rule_type)
        end

        before do
          allow(approval_rule).to receive(:user_defined?).and_return(true)
        end

        context 'when user is maintainer' do
          let(:user) { maintainer }

          it { is_expected.to be_disallowed(:edit_approval_rule) }
        end
      end
    end

    context 'without admin_merge_request_approvers_rules license' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: false)
      end

      let(:approval_rule) do
        build(:merge_requests_approval_rule, :from_project,
          project: project,
          project_id: project.id,
          rule_type: rule_type
        )
      end

      let(:user) { maintainer }

      it { is_expected.to be_allowed(:edit_approval_rule) }
    end
  end

  context 'when the rule originates from a group' do
    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_group,
        project: project,
        project_id: project.id,
        rule_type: rule_type
      )
    end

    # TODO: Update this once group approval rules have been implemented
    it { is_expected.not_to be_allowed(:edit_approval_rule) }
    it { is_expected.not_to be_allowed(:read_approval_rule) }
  end
end
