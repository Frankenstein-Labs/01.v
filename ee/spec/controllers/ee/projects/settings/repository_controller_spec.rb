# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::RepositoryController, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project_empty_repo, :public, namespace: group, maintainers: user) }

  before do
    sign_in(user)
  end

  describe 'GET show' do
    context 'push rule' do
      subject(:push_rule) { assigns(:push_rule) }

      context 'when global push rule is present' do
        before do
          OrganizationPushRule.find_or_create_by!(organization: project.organization).tap do |rule|
            rule.update!(commit_message_regex: 'Test')
          end
        end

        it 'creates project push rule from global push rule' do
          get :show, params: { namespace_id: project.namespace, project_id: project }

          is_expected.to be_persisted
          expect(project.reload.project_setting.push_rule).to eq(push_rule)
          expect(project.push_rule.commit_message_regex).to eq('Test')
        end
      end

      context 'when group-level predefined push rule is present' do
        before do
          create(:group_push_rule, group: group, commit_message_regex: 'GroupRegex')
        end

        it 'creates project push rule from group predefined push rule' do
          get :show, params: { namespace_id: project.namespace, project_id: project }

          is_expected.to be_persisted
          expect(project.reload.project_setting.push_rule).to eq(push_rule)
          expect(project.push_rule.commit_message_regex).to eq('GroupRegex')
        end
      end

      context 'when global push rule is missing' do
        it 'creates default project push rule' do
          get :show, params: { namespace_id: project.namespace, project_id: project }

          is_expected.to be_persisted
          expect(project.reload.project_setting.push_rule).to eq(push_rule)
        end
      end

      context 'unlicensed' do
        before do
          stub_licensed_features(push_rules: false)
        end

        it 'is not created' do
          get :show, params: { namespace_id: project.namespace, project_id: project }

          is_expected.to be_nil
        end
      end
    end

    context 'mirrors pagination with pull and push mirrors' do
      let_it_be_with_reload(:project) { create(:project_empty_repo, :mirror, maintainers: user) }
      let_it_be(:remote_mirrors) { create_list(:remote_mirror, 3, project: project) }

      let(:base_params) { { namespace_id: project.namespace, project_id: project } }

      render_views

      before do
        stub_feature_flags(vue_mirror_table: false)
        allow(Kaminari.config).to receive(:default_per_page).and_return(2)
      end

      it 'displays pull mirror on first page only' do
        get :show, params: base_params.merge(page: 1)

        expect(response.body).to include('js-delete-pull-mirror')
        expect(assigns(:remote_mirrors).count).to eq(2)
        expect(assigns(:remote_mirrors)).to be_a(ActiveRecord::Relation)
      end

      it 'does not display pull mirror on subsequent pages' do
        get :show, params: base_params.merge(page: 2)

        expect(response.body).not_to include('js-delete-pull-mirror')
        expect(assigns(:remote_mirrors).count).to eq(1)
        expect(assigns(:remote_mirrors).current_page).to eq(2)
      end
    end

    describe 'group protected branches' do
      using RSpec::Parameterized::TableSyntax

      where(:licensed_feature, :expected_include_group) do
        false           | false
        true            | true
      end

      let!(:protected_branch) { create(:protected_branch, project: nil, group: group) }

      let(:base_params) { { namespace_id: project.namespace, project_id: project } }
      let(:include_group) { assigns[:protected_branches].include?(protected_branch) }

      subject(:show_request) { get :show, params: base_params }

      with_them do
        before do
          stub_licensed_features(group_protected_branches: licensed_feature)
        end

        it 'include group correctly' do
          show_request

          expect(include_group).to eq(expected_include_group)
        end
      end
    end

    describe '#default_branch_blocked_by_security_policy' do
      subject(:show_request) { get :show, params: { namespace_id: project.namespace, project_id: project } }

      let(:blocked_by_security_policy) { true }

      before do
        allow_next_instance_of(
          ::Security::SecurityOrchestrationPolicies::DefaultBranchUpdationCheckService
        ) do |instance|
          allow(instance).to receive(:execute).and_return(blocked_by_security_policy)
        end
      end

      context 'when blocked by security policy' do
        it 'sets default_branch_blocked_by_security_policy' do
          show_request

          expect(assigns[:default_branch_blocked_by_security_policy]).to be(true)
        end
      end

      context 'when not blocked by security policy' do
        let(:blocked_by_security_policy) { false }

        it 'does not set default_branch_blocked_by_security_policy' do
          show_request

          expect(assigns[:default_branch_blocked_by_security_policy]).to be(false)
        end
      end
    end

    describe '#fetch_branches_protected_from_push' do
      using RSpec::Parameterized::TableSyntax

      where(:licensed_feature, :branches_protected_from_push, :expected_result) do
        false           | []                       | []
        true            | []                       | []
        false           | []                       | []
        true            | [ref(:protected_branch)] | [ref(:protected_branch)]
      end

      let!(:protected_branch) { create(:protected_branch, project: project) }
      let(:base_params) { { namespace_id: project.namespace, project_id: project } }

      subject(:show_request) { get :show, params: base_params }

      with_them do
        before do
          stub_licensed_features(security_orchestration_policies: licensed_feature)

          allow_next_instance_of(
            ::Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService
          ) do |instance|
            allow(instance).to receive(:execute).and_return(branches_protected_from_push)
          end
        end

        it 'assigns the list of protected branches' do
          expect(::Security::PolicyAvailability).to receive(:available?).with(project, :security_orchestration_policies)
            .and_call_original

          show_request

          expect(assigns[:branches_protected_from_push]).to eq(expected_result)
        end
      end
    end

    describe 'avoid N+1 sql queries' do
      subject(:show_request) { get :show, params: { namespace_id: project.namespace, project_id: project } }

      context 'when the feature group protected branches disabled' do
        it 'does not perform N+1 sql queries' do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { show_request }

          create_list(:protected_branch, 2, project: project)
          create_list(:protected_branch, 2, project: nil, group: group)

          expect { show_request }.not_to exceed_all_query_limit(control)
        end
      end

      context 'when the feature group protected branches enabled' do
        before do
          stub_licensed_features(group_protected_branches: true)
        end

        it 'does not perform N+1 sql queries' do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { show_request }

          create_list(:protected_branch, 2, project: project)
          create_list(:protected_branch, 2, project: nil, group: group)

          expect { show_request }.not_to exceed_all_query_limit(control)
        end
      end
    end

    describe 'set protected_branches_from_deletion' do
      subject(:show_request) { get :show, params: { namespace_id: project.namespace, project_id: project } }

      let(:protected_branch_from_deletion) { create(:protected_branch, project: project) }

      let(:protected_branches) { [protected_branch_from_deletion, create(:protected_branch, project: project)] }

      before do
        allow(project).to receive(:protected_branches).and_return(protected_branches)

        allow_next_instance_of(
          ::Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService,
          project: project, current_user: user) do |instance|
          allow(instance).to receive(:execute).and_return([protected_branch_from_deletion])
        end
      end

      it 'sets protected_branches_from_deletion' do
        show_request

        assigned_protected_branches = assigns(:protected_branches)

        expect(assigned_protected_branches.size).to eq(2)

        expect(assigned_protected_branches.select(&:protected_from_deletion))
          .to contain_exactly(protected_branch_from_deletion)
      end
    end

    context 'when accessing through custom ability' do
      let_it_be(:another_user) { create(:user) }
      let_it_be(:role) { create(:member_role, :guest, :admin_protected_branch, namespace: group) }
      let_it_be(:membership) do
        create(:group_member, :guest, member_role: role, user: another_user, group: group)
      end

      before do
        sign_in(another_user)
      end

      context 'with custom_roles feature enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'allows access' do
          get :show, params: { namespace_id: group, project_id: project }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with custom_roles feature disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'does not allow access' do
          get :show, params: { namespace_id: group, project_id: project }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
