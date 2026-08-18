# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestPresenter, feature_category: :shared do
  using RSpec::Parameterized::TableSyntax
  include LoginHelpers

  let_it_be_with_reload(:project) { create(:project, :repository) }

  let(:merge_request) { build_stubbed(:merge_request, source_project: project) }
  let(:user) { project.creator }
  let(:approval_feature_available) { true }

  before do
    stub_config_setting(relative_url_root: '/gitlab')
    stub_licensed_features(merge_request_approvers: approval_feature_available)
  end

  shared_examples 'is nil when needed' do
    where(:approval_feature_available, :with_iid) do
      false | false
      false | true
      true  | false
    end

    with_them do
      before do
        merge_request.iid = nil unless with_iid
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#api_approval_settings_path' do
    subject { described_class.new(merge_request, current_user: user).api_approval_settings_path }

    it_behaves_like 'is nil when needed'

    it { is_expected.to eq(expose_path("/api/v4/projects/#{merge_request.project.id}/merge_requests/#{merge_request.iid}/approval_settings")) }
  end

  describe '#api_project_approval_settings_path' do
    subject { described_class.new(merge_request, current_user: user).api_project_approval_settings_path }

    it { is_expected.to eq(expose_path("/api/v4/projects/#{merge_request.project.id}/approval_settings")) }

    context "when approvals not available" do
      let(:approval_feature_available) { false }

      it { is_expected.to be_nil }
    end
  end

  describe '#suggested_approvers' do
    subject { described_class.new(merge_request, current_user: user).suggested_approvers }

    it 'delegates to the approval state' do
      expect(merge_request.approval_state).to receive(:suggested_approvers).with(current_user: user).and_return([:ok])

      is_expected.to contain_exactly(:ok)
    end
  end

  describe 'create vulnerability feedback paths', feature_category: :vulnerability_management do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    where(:create_feedback_path) do
      [
        :create_vulnerability_feedback_issue_path,
        :create_vulnerability_feedback_merge_request_path,
        :create_vulnerability_feedback_dismissal_path
      ]
    end

    with_them do
      subject { described_class.new(merge_request, current_user: user).public_send(create_feedback_path, merge_request.project) }

      it { is_expected.to eq("/#{merge_request.project.full_path}/-/vulnerability_feedback") }

      context 'when not allowed to create vulnerability feedback' do
        let(:unauthorized_user) { create(:user) }

        subject { described_class.new(merge_request, current_user: unauthorized_user).public_send(create_feedback_path, merge_request.project) }

        it "does not contain #{params['create_feedback_path']}" do
          expect(subject).to be_nil
        end
      end
    end
  end

  describe '#approvals_widget_type' do
    subject { described_class.new(merge_request, current_user: user).approvals_widget_type }

    context 'when approvals feature is available for a project' do
      let(:approval_feature_available) { true }

      it 'returns full' do
        is_expected.to eq('full')
      end
    end

    context 'when approvals feature is not available for a project' do
      let(:approval_feature_available) { false }

      it 'returns base' do
        is_expected.to eq('base')
      end
    end
  end

  describe '#discover_project_security_path' do
    let(:presenter) { described_class.new(merge_request, current_user: user) }
    let(:can_discover_project_security) { true }

    subject { presenter.discover_project_security_path }

    before do
      allow(presenter).to receive(:show_discover_project_security?) { can_discover_project_security }
    end

    context 'when project security is discoverable' do
      it 'returns path' do
        is_expected.to eq(presenter.project_security_discover_path(project))
      end
    end

    context 'when project security is not discoverable' do
      let(:can_discover_project_security) { false }

      it 'returns nil' do
        is_expected.to be_nil
      end
    end
  end

  describe '#issue_keys' do
    # This feature relies on having valid Jira integration active with the project
    # if it is enabled.
    let_it_be_with_reload(:project) { create(:project, :repository, :with_jira_integration) }
    let(:merge_request) { create(:merge_request, source_project: project) }
    let(:presenter) { described_class.new(merge_request, current_user: user) }

    subject { presenter.issue_keys }

    context 'when Jira issue is provided in MR title / description' do
      let(:issue_key) { 'SIGNUP-1234' }

      before do
        merge_request.update!(title: "Fixes sign up issue #{issue_key}", description: "Related to #{issue_key}")
      end

      it { is_expected.to contain_exactly(issue_key) }
    end

    context 'when Jira issue is NOT provided in MR title / description' do
      before do
        merge_request.update!(title: "Fixes sign up issue", description: "Prevent spam sign ups by adding a rate limiter")
      end

      it { is_expected.to be_empty }
    end
  end

  describe '#api_status_checks_path' do
    subject { presenter.api_status_checks_path }

    let(:exposed_path) { expose_path("/api/v4/projects/#{merge_request.project.id}/merge_requests/#{merge_request.iid}/status_checks") }

    where(:authenticated?, :has_status_checks?, :exposes_path?) do
      false | false | false
      false | true  | false
      true  | true  | true
      true  | false | false
      true  | true  | true
    end

    with_them do
      let(:presenter) { described_class.new(merge_request, current_user: authenticated? ? user : nil) }
      let(:path) { exposes_path? ? exposed_path : nil }

      before do
        applicable_checks = has_status_checks? ? [{ branch: 'foo' }] : []
        allow(project.external_status_checks).to receive(:applicable_to_branch).with(anything).and_return(applicable_checks)
      end

      it { is_expected.to eq(path) }
    end

    context 'with the user authenticated' do
      let(:merge_request) { create(:merge_request, source_project: project) }
      let(:presenter) { described_class.new(merge_request, current_user: user) }

      # `let_it_be(:project)` shares the project instance across examples, so its
      # `external_status_checks` association proxy can retain records cached by
      # earlier examples. Reset it here so each example sees the rows created
      # in its own `before` block via the `FilterByBranch#applicable_to_branch`
      # extension (which iterates the loaded proxy).
      before do
        project.external_status_checks.reset
      end

      context 'without applicable branches' do
        before do
          create(:external_status_check, project: project, protected_branches: [create(:protected_branch, name: 'testbranch', project: project)])
        end

        it { is_expected.to be_nil }
      end

      context 'with no branches at all (any branch selected)' do
        before do
          create(:external_status_check, project: project, protected_branches: [])
        end

        it { is_expected.to eq(exposed_path) }
      end

      context 'with applicable branches' do
        before do
          create(:external_status_check, project: project, protected_branches: [create(:protected_branch, name: merge_request.target_branch, project: project)])
        end

        it { is_expected.to eq(exposed_path) }
      end
    end
  end

  describe '#saml_approval_path' do
    let(:group) { create :group, name: 'group_one', saml_discovery_token: 'token777' }
    let(:sub_group) { create :group, :nested, name: 'sub_group', parent: group, saml_discovery_token: 'foobar' }
    let(:project) { create :project, group: sub_group }

    subject(:presenter) { described_class.new(merge_request, current_user: user) }

    context 'when group saml' do
      before do
        stub_licensed_features(group_saml: true)
        create(:saml_provider, group: group, enabled: true)
        allow(presenter).to receive(:group_requires_saml_auth_for_approval?).and_return(true)
      end

      it 'uses the root group for SSO path and token' do
        expect(presenter.saml_approval_path).to start_with('/gitlab/groups/group_one/-/saml/sso?redirect')
        expect(presenter.saml_approval_path).to include('token777')
      end

      context 'without nesting' do
        let(:group) { create :group, name: 'group_wurzel', saml_discovery_token: 'root' }
        let(:project) { create :project, group: group }

        it 'uses the root group for SSO path and token' do
          expect(presenter.saml_approval_path).to start_with('/gitlab/groups/group_wurzel/-/saml/sso?redirect')
          expect(presenter.saml_approval_path).to include('root')
        end
      end
    end

    context 'when instance saml' do
      let_it_be_with_reload(:project) { create :project, :in_group }
      let_it_be(:user) { create(:user, identities: [build(:identity, provider: 'saml')]) }

      before_all do
        project.add_developer(user)
      end

      before do
        stub_omniauth_saml_config(
          enabled: true,
          auto_link_saml_user: false,
          allow_single_sign_on: ['saml'],
          providers: [mock_saml_config]
        )

        # if password auth is allowed, instance SAML is not enforced via SSOEnforcer
        stub_application_setting(password_authentication_enabled_for_web: false)
        allow(presenter).to receive(:instance_requires_saml_auth_for_approval?).and_return(true)
      end

      it 'returns the instance saml path' do
        expect(presenter.saml_approval_path).to start_with('/gitlab/users/auth/saml')
      end
    end
  end

  describe '#require_saml_auth_to_approve' do
    let(:group) { create :group, name: 'group_one', saml_discovery_token: 'token777' }
    let(:project) { create :project, :in_group, group: group }

    subject(:presenter) { described_class.new(merge_request, current_user: user) }

    before do
      stub_licensed_features(group_saml: true)
      create(:saml_provider, group: group, enabled: true)
      allow(presenter).to receive(:group_requires_saml_auth_for_approval?).and_return(true)
    end

    context 'when require_password_to_approve is enabled via group/project settings' do
      before do
        allow(presenter).to receive(:mr_approval_setting_password_required?).and_return(true)
      end

      it 'is enabled' do
        expect(presenter.require_saml_auth_to_approve).to be true
      end
    end

    context 'when require_password_to_approve is enabled via security policy', feature_category: :security_policy_management do
      let(:merge_request) { create(:merge_request, source_project: project) }
      let(:project_approval_settings) do
        { require_password_to_approve: true }
      end

      let(:security_policy) do
        create(:security_policy, content: { approval_settings: project_approval_settings })
      end

      let(:approval_policy_rule) do
        create(:approval_policy_rule, security_policy: security_policy)
      end

      let(:policy) do
        create(:scan_result_policy_read,
          project: project,
          project_approval_settings: project_approval_settings,
          approval_policy_rule: approval_policy_rule)
      end

      let!(:approval_merge_request_rule) do
        create(
          :approval_merge_request_rule,
          :any_merge_request,
          merge_request: merge_request,
          scan_result_policy_read: policy,
          approvals_required: 1)
      end

      before do
        create(
          :scan_result_policy_violation,
          project: project,
          merge_request: merge_request,
          scan_result_policy_read: policy,
          approval_policy_rule: approval_policy_rule)
      end

      it 'is enabled' do
        expect(presenter.require_saml_auth_to_approve).to be true
      end
    end

    context 'when require_password_to_approve is disabled everywhere' do
      before do
        allow(merge_request).to receive(:policy_approval_settings).and_return({})
      end

      it 'is disabled' do
        expect(presenter.require_saml_auth_to_approve).to be false
      end
    end
  end

  describe '#approvers' do
    let(:presenter) { described_class.new(merge_request, current_user: user) }

    it 'returns empty array for approvers' do
      expect(merge_request).not_to receive(:approvers)
      expect(presenter.approvers).to eq([])
    end
  end

  describe '#approver_groups' do
    let(:presenter) { described_class.new(merge_request, current_user: user) }

    it 'returns empty array for approver_groups' do
      expect(merge_request).not_to receive(:approver_groups)
      expect(presenter.approver_groups).to eq([])
    end
  end
end
