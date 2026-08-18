# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectHooks, :aggregate_failures, feature_category: :webhooks do
  describe 'with admin_web_hook custom role' do
    before do
      stub_licensed_features(custom_roles: true)
      sign_in(user)
    end

    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:role) { create(:member_role, :guest, :admin_web_hook, namespace: group) }
    let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }
    let_it_be(:project_hook) { create(:project_hook, project: project, url: 'http://example.test/') }

    let(:hook) { create(:project_hook, project: project) }

    let(:list_url) { "/projects/#{project.id}/hooks" }
    let(:get_url) { "/projects/#{project.id}/hooks/#{project_hook.id}" }
    let(:add_url) { "/projects/#{project.id}/hooks" }
    let(:edit_url) { "/projects/#{project.id}/hooks/#{project_hook.id}" }
    let(:delete_url) { "/projects/#{project.id}/hooks/#{hook.id}" }

    it_behaves_like 'web-hook API endpoints with admin_web_hook custom role'
  end
end
