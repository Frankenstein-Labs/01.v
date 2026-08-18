# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupHooks, :aggregate_failures, feature_category: :webhooks do
  let_it_be(:group_admin) { create(:user) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:group) { create(:group, owners: group_admin) }
  let_it_be_with_refind(:hook) do
    create(:group_hook,
      :all_events_enabled,
      group: group,
      url: 'http://example.com',
      enable_ssl_verification: true)
  end

  it_behaves_like 'web-hook API endpoints', '/groups/:id' do
    let(:resource) { group }
    let(:user) { group_admin }
    let(:unauthorized_user) { non_admin_user }

    def scope
      group.hooks
    end

    def collection_uri
      "/groups/#{group.id}/hooks"
    end

    def match_collection_schema
      match_response_schema('public_api/v4/group_hooks', dir: 'ee')
    end

    def hook_uri(hook_id = hook.id)
      "/groups/#{group.id}/hooks/#{hook_id}"
    end

    def match_hook_schema
      match_response_schema('public_api/v4/group_hook', dir: 'ee')
    end

    def event_names
      %i[
        push_events
        issues_events
        confidential_issues_events
        merge_requests_events
        tag_push_events
        note_events
        confidential_note_events
        job_events
        pipeline_events
        wiki_page_events
        deployment_events
        releases_events
        milestone_events
        subgroup_events
        feature_flag_events
        emoji_events
        resource_access_token_events
        member_events
        vulnerability_events
        project_events
      ]
    end

    let(:default_values) do
      { push_events: true, confidential_note_events: nil }
    end

    context 'when group does not have a project' do
      it 'returns error' do
        post api("#{hook_uri}/test/push_events", user, admin_mode: user.admin?), params: {}

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq('Ensure the group has a project with commits.')
      end
    end

    context 'when group has a project' do
      let_it_be(:user) { group_admin }
      let_it_be_with_reload(:project) { create(:project, :repository, group: group, creator_id: user.id) }

      context 'when the group is IP restricted' do
        before do
          allow_next_instance_of(::Gitlab::IpRestriction::Enforcer) do |enforcer|
            allow(enforcer).to receive(:allows_current_ip?).and_return(false)
          end
        end

        it 'returns a forbidden error', :aggregate_failures do
          post api("#{hook_uri}/test/push_events", user, admin_mode: user.admin?), params: {}

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to eq('403 Forbidden - Group access restricted by IP address.')
        end
      end

      it_behaves_like 'test web-hook endpoint'
      it_behaves_like 'resend web-hook event endpoint' do
        let(:unauthorized_user) { user2 }
      end

      it_behaves_like 'get web-hook event endpoint' do
        let(:unauthorized_user) { non_admin_user }
      end
    end

    it_behaves_like 'POST webhook API endpoints with a branch filter', '/projects/:id'
    it_behaves_like 'PUT webhook API endpoints with a branch filter', '/projects/:id'
  end

  describe 'with admin_web_hook custom role' do
    before do
      stub_licensed_features(custom_roles: true)
      sign_in(user)
    end

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:role) { create(:member_role, :guest, :admin_web_hook, namespace: group) }
    let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }
    let_it_be(:group_hook) { create(:group_hook, group: group, url: 'http://example.test/') }

    let(:hook) { create(:group_hook, group: group) }
    let(:list_url) { "/groups/#{group.id}/hooks" }
    let(:get_url) { "/groups/#{group.id}/hooks/#{group_hook.id}" }
    let(:add_url) { "/groups/#{group.id}/hooks" }
    let(:edit_url) { "/groups/#{group.id}/hooks/#{group_hook.id}" }
    let(:delete_url) { "/groups/#{group.id}/hooks/#{hook.id}" }

    it_behaves_like 'web-hook API endpoints with admin_web_hook custom role'
  end
end
