# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupsController, feature_category: :groups_and_projects do
  include ExternalAuthorizationServiceHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user, organizations: [current_organization]) }
  let_it_be(:group) { create(:group, :public, organization: current_organization) }
  let_it_be(:project) { create(:project, :public, namespace: group) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }
  let_it_be(:subgroup2) { create(:group, :private, parent: subgroup) }

  describe 'GET #edit' do
    subject { get :edit, params: { id: group.to_param } }

    before_all do
      group.add_owner(user)
    end

    before do
      sign_in(user)
    end

    it_behaves_like 'pushes saas feature', :group_project_permanent_deletion_confirmation
    it_behaves_like 'pushes dedicated feature', :group_project_permanent_deletion_confirmation

    it 'pushes :secrets_manager_paid_experience with the root ancestor as actor',
      feature_category: :secrets_management do
      allow(controller).to receive(:push_frontend_feature_flag)

      get :edit, params: { id: subgroup.to_param }

      expect(controller).to have_received(:push_frontend_feature_flag)
        .with(:secrets_manager_paid_experience, group)
    end
  end

  describe 'GET #show' do
    render_views
    let(:namespace) { group }

    subject(:get_show) { get :show, params: { id: group.to_param } }

    before do
      namespace.add_owner(user)

      sign_in(user)
    end

    context 'with storage limit', :saas do
      it_behaves_like 'namespace storage limit alert'
    end

    context 'with free user cap performance concerns', :with_trial_types, :saas do
      render_views

      let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        stub_ee_application_setting(dashboard_limit_enabled: true)
        stub_ee_application_setting(dashboard_limit: 5)
      end

      it 'avoids extra user count queries', :request_store do
        recorder = ActiveRecord::QueryRecorder.new { get_show }

        # we expect 4 invocations since there are 4 queries, so if over 4, this below
        # will be non-empty. Count was 20 with strong_memoize prior to adding safe request
        # store caching on the `users_count` method.
        expected_count = ::Namespaces::BilledUsersFinder::METHOD_KEY_MAP.keys.size
        method_invocations = recorder.find_query(/.*:calculate_user_ids.*/, expected_count, first_only: true)

        expect(method_invocations).to be_empty
      end
    end

    it_behaves_like 'pushes saas feature', :group_project_permanent_deletion_confirmation
    it_behaves_like 'pushes dedicated feature', :group_project_permanent_deletion_confirmation
  end

  describe 'GET #activity' do
    render_views

    let_it_be(:event1) { create(:event, project: project) }
    let_it_be(:event2) { create(:event, :epic_create_event, group: group) }
    let_it_be(:event3) { create(:event, :epic_create_event, group: subgroup) }
    let_it_be(:event4) { create(:event, :epic_create_event, group: subgroup2) }

    context 'when authorized' do
      before_all do
        group.add_owner(user)
        subgroup.add_owner(user)
        subgroup2.add_owner(user)
      end

      before do
        sign_in(user)
      end

      context 'when group events are available' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'includes events from group and subgroups' do
          get :activity, params: { id: group.to_param }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['count']).to eq(4)
        end

        it 'includes transferred project and subgroup transferred group events', :aggregate_failures do
          create(
            :event,
            :transferred,
            project: nil,
            group: subgroup,
            target: subgroup,
            target_type: 'Group',
            author: user
          )
          create(
            :event,
            :transferred,
            project: project,
            target: project,
            target_type: 'Project',
            author: user
          )

          request.cookies[:event_filter] = EventFilter::ALL

          get :activity, params: { id: group.to_param }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['count']).to eq(6)
        end
      end

      context 'when group events are not available' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'does not include events from group and subgroups' do
          get :activity, params: { id: group.to_param }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['count']).to eq(1)
        end
      end
    end

    context 'when unauthorized' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'includes only events visible to user' do
        get :activity, params: { id: group.to_param }, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['count']).to eq(2)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:format) { :html }
    let(:params) { {} }

    subject(:destroy_group) { delete :destroy, format: format, params: { id: group.to_param, **params } }

    before_all do
      group.add_owner(user)
    end

    context 'when authenticated user can admin the group' do
      before do
        sign_in(user)
      end

      context 'when group is linked to a subscription', :saas do
        let_it_be(:group_with_plan) do
          create(:group_with_plan, plan: :ultimate_plan, owners: user, organization: current_organization)
        end

        let(:params) { { id: group_with_plan.to_param } }

        context 'for a html request' do
          it 'redirects to edit page with alert' do
            destroy_group

            expect(response).to redirect_to(edit_group_path(group_with_plan))
            expect(flash[:alert]).to eq 'This group is linked to a subscription'
          end
        end

        context 'for a json request' do
          let(:format) { :json }

          it 'returns json with message' do
            destroy_group

            expect(json_response['message']).to eq('This group is linked to a subscription')
          end
        end
      end
    end

    context 'when authenticated user cannot admin the group' do
      before do
        sign_in(create(:user))
      end

      it 'returns 404' do
        destroy_group

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:group_params) { { name: 'new_group', path: 'new_group' } }

    subject(:create_group) { post :create, params: { group: group_params } }

    context 'authorization' do
      it 'allows an auditor with "can_create_group" set to true to create a group' do
        sign_in(create(:user, :auditor, can_create_group: true, organizations: [current_organization]))

        expect { create_group }.to change { Group.count }.by(1)

        expect(response).to have_gitlab_http_status(:found)
      end
    end

    it_behaves_like GroupInviteMembers do
      before do
        sign_in(user)
      end
    end

    context 'when creating a group with `default_branch_protection` attribute' do
      subject do
        post :create, params: { group: group_params.merge(default_branch_protection: Gitlab::Access::PROTECTION_NONE) }
      end

      shared_examples_for 'creates the group with the expected `default_branch_protection` value' do
        it 'creates the group with the expected `default_branch_protection` value' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(Group.last.default_branch_protection).to eq(default_branch_protection)
        end
      end

      context 'authenticated as an admin', :enable_admin_mode do
        let_it_be_with_reload(:user) { create(:admin) }

        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          false | false | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_NONE
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            sign_in(user)

            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it_behaves_like 'creates the group with the expected `default_branch_protection` value'
        end
      end

      context 'authenticated a normal user' do
        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          false | false | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_FULL
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            sign_in(user)

            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it_behaves_like 'creates the group with the expected `default_branch_protection` value'
        end
      end
    end
  end

  describe 'PUT #update' do
    let_it_be_with_refind(:group) { create(:group) }

    context 'when max_pages_size param is specified' do
      let(:params) { { max_pages_size: 100 } }

      let(:request) do
        post :update, params: { id: group.to_param, group: params }
      end

      before_all do
        group.add_owner(user)
      end

      before do
        stub_licensed_features(pages_size_limit: true)
        sign_in(user)
      end

      context 'when user is an admin with admin mode enabled', :enable_admin_mode do
        let(:user) { create(:admin) }

        it 'updates max_pages_size' do
          request

          expect(group.reload.max_pages_size).to eq(100)
        end
      end

      context 'when user is an admin with admin mode disabled' do
        it 'does not update max_pages_size' do
          request

          expect(group.reload.max_pages_size).to be_nil
        end
      end

      context 'when user is not an admin' do
        it 'does not update max_pages_size' do
          request

          expect(group.reload.max_pages_size).to be_nil
        end
      end
    end

    context 'when `max_personal_access_token_lifetime` is specified' do
      let_it_be(:managed_group) do
        create(:group_with_managed_accounts, :private, max_personal_access_token_lifetime: 1)
      end

      let_it_be_with_reload(:user) { create(:user, :group_managed, managing_group: managed_group) }

      let(:params) { { max_personal_access_token_lifetime: max_personal_access_token_lifetime } }
      let(:max_personal_access_token_lifetime) { 10 }

      subject(:update_group) do
        put :update, params: { id: managed_group.to_param, group: params }
      end

      before_all do
        managed_group.add_owner(user)
      end

      before do
        allow_next_found_instance_of(Group) do |instance|
          allow(instance).to receive(:enforced_group_managed_accounts?).and_return(true)
        end

        sign_in(user)
      end

      context 'without `personal_access_token_expiration_policy` licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: false)
        end

        it 'does not update the attribute' do
          expect { update_group }.not_to change { managed_group.reload.max_personal_access_token_lifetime }
        end

        it "doesn't call the update lifetime service" do
          expect(::PersonalAccessTokens::Groups::UpdateLifetimeService).not_to receive(:new)

          update_group
        end
      end

      context 'with personal_access_token_expiration_policy licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: true)
        end

        context 'when `max_personal_access_token_lifetime` is updated to a non-null value' do
          it 'updates the attribute' do
            update_group

            expect(managed_group.reload.max_personal_access_token_lifetime).to eq(max_personal_access_token_lifetime)
          end

          it 'executes the update lifetime service' do
            expect_next_instance_of(::PersonalAccessTokens::Groups::UpdateLifetimeService, managed_group) do |service|
              expect(service).to receive(:execute)
            end

            update_group
          end
        end

        context 'when `max_personal_access_token_lifetime` is updated to null value' do
          let(:max_personal_access_token_lifetime) { nil }

          it 'updates the attribute' do
            update_group

            expect(managed_group.reload.max_personal_access_token_lifetime).to eq(max_personal_access_token_lifetime)
          end

          it "doesn't call the update lifetime service" do
            expect(::PersonalAccessTokens::Groups::UpdateLifetimeService).not_to receive(:new)

            update_group
          end
        end
      end
    end

    context 'when `default_branch_protection` is specified' do
      let(:params) do
        { id: group.to_param, group: { default_branch_protection: Gitlab::Access::PROTECTION_NONE } }
      end

      subject { put :update, params: params }

      shared_examples_for 'updates the attribute' do
        it 'updates the attribute' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.default_branch_protection).to eq(default_branch_protection)
        end
      end

      context 'authenticated as admin', :enable_admin_mode do
        let_it_be_with_reload(:user) { create(:admin) }

        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          false | false | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_NONE
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            sign_in(user)

            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it_behaves_like 'updates the attribute'
        end
      end

      context 'authenticated as group owner' do
        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          false | false | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_FULL
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before_all do
            group.add_owner(user)
          end

          before do
            sign_in(user)
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it_behaves_like 'updates the attribute'
        end
      end
    end

    context 'when service_access_tokens_expiration_enforced is specified' do
      subject(:update_group_request) { put :update, params: params }

      shared_examples_for 'updates the attribute if needed' do
        it 'updates the attribute' do
          update_group_request

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.service_access_tokens_expiration_enforced?).to eq(result)
        end
      end

      context 'when authenticated as group owner' do
        where(:service_access_tokens_expiration_enforced, :result) do
          false | false
          true  | true
        end

        with_them do
          let(:params) do
            { id: group.to_param, group: { service_access_tokens_expiration_enforced: service_access_tokens_expiration_enforced } }
          end

          before_all do
            group.add_owner(user)
          end

          before do
            sign_in(user)
          end

          it_behaves_like 'updates the attribute if needed'
        end
      end
    end

    context 'when `prevent_forking_outside_group` is specified' do
      subject { put :update, params: params }

      shared_examples_for 'updates the attribute if needed' do
        it 'updates the attribute' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.prevent_forking_outside_group?).to eq(result)
        end
      end

      context 'authenticated as group owner' do
        where(:feature_enabled, :prevent_forking_outside_group, :result) do
          false | false | nil
          false | true  | nil
          true  | false | false
          true  | true  | true
        end

        with_them do
          let(:params) do
            { id: group.to_param, group: { prevent_forking_outside_group: prevent_forking_outside_group } }
          end

          before_all do
            group.add_owner(user)
          end

          before do
            sign_in(user)
            stub_licensed_features(group_forking_protection: feature_enabled)
          end

          it_behaves_like 'updates the attribute if needed'
        end
      end
    end

    context 'when seat control is specified', :saas do
      context 'authenticated as group owner' do
        before_all do
          group.add_owner(user)
        end

        before do
          sign_in(user)
        end

        where(:seat_control, :new_user_signups_cap) do
          :off      | nil
          :user_cap | 10
        end

        with_them do
          it 'updates the attributes' do
            params = { id: group.to_param, group: { seat_control: seat_control, new_user_signups_cap: new_user_signups_cap } }

            put :update, params: params

            expect(response).to have_gitlab_http_status(:found)
            expect(group.reload.seat_control).to eq(seat_control.to_s)
            expect(group.reload.new_user_signups_cap).to eq(new_user_signups_cap)
          end
        end
      end
    end

    context 'when group feature setting `wiki_access_level` is specified' do
      before_all do
        group.add_owner(user)
      end

      before do
        stub_licensed_features(group_wikis: true)
        sign_in(user)
      end

      it 'updates the attribute' do
        [Featurable::PRIVATE, Featurable::DISABLED, Featurable::ENABLED].each do |visibility_level|
          request(visibility_level)

          expect(group.reload.group_feature.wiki_access_level).to eq(visibility_level)
        end
      end

      context 'when group wiki licensed feature is not enabled for the group' do
        it 'does not update the attribute' do
          stub_licensed_features(group_wikis: false)

          expect { request(Featurable::PRIVATE) }.not_to change { group.reload.group_feature.wiki_access_level }
        end
      end

      def request(visibility_level)
        put :update, params: { id: group.to_param, group: { group_feature_attributes: { wiki_access_level: visibility_level } } }
      end
    end

    context 'when updating ip_restriction_ranges is specified' do
      subject(:update_ip_ranges) do
        put :update, params: { id: group.to_param, group: { ip_restriction_ranges: ip_address } }
      end

      let(:ip_address) { '192.168.24.78' }

      before_all do
        group.add_owner(user)
      end

      before do
        sign_in(user)
      end

      context 'for users who have the usage_ping_features activated' do
        before do
          stub_application_setting(usage_ping_enabled: true)
          stub_application_setting(usage_ping_features_enabled: true)
        end

        it 'updates the attribute' do
          update_ip_ranges

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.ip_restriction_ranges).to eq(ip_address)
        end
      end

      context "for users who don't have the usage_ping_features activated" do
        before do
          stub_application_setting(usage_ping_enabled: false)
        end

        it 'does not update the attribute' do
          update_ip_ranges

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.ip_restriction_ranges).not_to eq(ip_address)
        end
      end
    end
  end

  context 'when ai settings are specified', :saas do
    let(:group) { create(:group_with_plan, plan: :ultimate_plan, trial_ends_on: Date.tomorrow) }

    before do
      group.add_owner(user)
      allow(Gitlab).to receive(:com?).and_return(true)
      stub_licensed_features(ai_features: true, experimental_features: true)
      stub_ee_application_setting(should_check_namespace_plan: true)
      sign_in(user)
    end

    it 'updates the attribute' do
      expect do
        put :update, params: { id: group.to_param, group: { experiment_features_enabled: true } }
      end.to change { group.reload.experiment_features_enabled }.from(false).to(true)
    end
  end

  describe 'PUT #update with mcp_server_enabled', :aggregate_failures, feature_category: :mcp_server do
    let_it_be_with_reload(:group) { create(:group) }

    subject(:update_mcp) do
      put :update, params: { id: group.to_param, group: { mcp_server_enabled: false } }
    end

    # rubocop:disable RSpec/BeforeAllRoleAssignment -- group is a `let`, not `let_it_be`
    before do
      group.add_owner(user)
      group.namespace_settings.update!(mcp_server_enabled: true)
      sign_in(user)
    end
    # rubocop:enable RSpec/BeforeAllRoleAssignment

    context 'when on GitLab.com', :saas do
      it 'updates mcp_server_enabled' do
        expect { update_mcp }
          .to change { group.namespace_settings.reload.mcp_server_enabled }
          .from(true).to(false)
      end

      context 'when the group is a subgroup' do
        let(:subgroup) { create(:group, parent: group) }

        subject(:update_mcp) do
          put :update, params: { id: subgroup.to_param, group: { mcp_server_enabled: false } }
        end

        before do
          subgroup.namespace_settings.update!(mcp_server_enabled: true)
          subgroup.add_owner(user)
        end

        it 'ignores the mcp_server_enabled param' do
          expect { update_mcp }
            .not_to change { subgroup.namespace_settings.reload.mcp_server_enabled }
        end
      end
    end

    context 'when self-managed' do
      it 'ignores the mcp_server_enabled param' do
        expect { update_mcp }
          .not_to change { group.namespace_settings.reload.mcp_server_enabled }
      end
    end
  end

  describe '#issues' do
    context 'with epic params' do
      let_it_be(:group) { create(:group) }
      let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }

      before_all do
        group.add_developer(user)
      end

      before do
        sign_in user
        stub_licensed_features(epics: true)
      end

      shared_examples 'epic parameter redirect' do |redirect_path|
        it 'redirects with epic_wildcard_id converted to parent_wildcard_id' do
          get :issues, params: { id: group.to_param, epic_wildcard_id: 'ANY' }

          expected_params = { parent_wildcard_id: 'ANY' }
          expected_params['not[type][]'] = 'epic' if redirect_path == :group_work_items_path

          expect(response).to redirect_to send(redirect_path, group, params: expected_params)
        end

        it 'redirects with epic_id converted to parent_id' do
          get :issues, params: { id: group.to_param, epic_id: epic.id }

          expected_params = { parent_id: epic.work_item.id }
          expected_params['not[type][]'] = 'epic' if redirect_path == :group_work_items_path

          expect(response).to redirect_to send(redirect_path, group, params: expected_params)
        end

        it 'redirects with epic_id NONE converted to parent_id NONE' do
          get :issues, params: { id: group.to_param, epic_id: 'NONE' }

          expected_params = { parent_id: 'NONE' }
          expected_params['not[type][]'] = 'epic' if redirect_path == :group_work_items_path

          expect(response).to redirect_to send(redirect_path, group, params: expected_params)
        end

        it 'redirects with not epic_id converted to not parent_id' do
          get :issues, params: { id: group.to_param, not: { epic_id: epic.id } }

          expected_params = { not: { parent_id: epic.work_item.id } }
          expected_params['not[type][]'] = 'epic' if redirect_path == :group_work_items_path

          expect(response).to redirect_to send(redirect_path, group, params: expected_params)
        end

        it 'preserves other query parameters when redirecting with epic params' do
          get :issues, params: { id: group.to_param, epic_wildcard_id: 'ANY', search: 'bug', sort: 'created_desc' }

          expected_params = {
            parent_wildcard_id: 'ANY',
            search: 'bug',
            sort: 'created_desc'
          }
          expected_params['not[type][]'] = 'epic' if redirect_path == :group_work_items_path

          expect(response).to redirect_to send(redirect_path, group, params: expected_params)
        end
      end

      it_behaves_like 'epic parameter redirect', :group_work_items_path

      it 'redirects to work items path with epic exclusion filter when epics are available' do
        get :issues, params: { id: group.to_param }

        expect(response).to redirect_to(group_work_items_path(group, params: { 'not[type][]' => 'epic' }))
      end
    end
  end
end
