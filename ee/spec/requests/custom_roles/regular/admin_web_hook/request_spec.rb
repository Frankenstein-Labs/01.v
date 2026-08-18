# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_web_hook custom role', feature_category: :webhooks do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let(:can_admin_web_hook) { true }
  let(:role) { create(:member_role, :guest, admin_web_hook: can_admin_web_hook, namespace: group) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(user)
  end

  shared_examples 'HooksController' do
    describe '#index' do
      it 'allows access' do
        get index_path

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#edit' do
      it 'allows access' do
        get edit_hook_path

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#create' do
      it 'allows access' do
        post create_path, params: { hook: { url: 'http://example.test/' } }

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    describe '#update' do
      it 'allows access' do
        patch update_path, params: { hook: { name: 'Test' } }

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    describe '#destroy' do
      it 'allows access' do
        delete destroy_path

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    describe '#test' do
      it 'allows access' do
        stub_request(:post, 'http://example.test/')

        post test_path

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end
  end

  shared_examples 'HookLogsController' do
    describe '#show' do
      it 'allows access' do
        get show_path

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'without admin_web_hook permission' do
        let(:can_admin_web_hook) { false }

        it 'does not allow access' do
          get show_path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe '#retry' do
      it 'allows access' do
        stub_request(:post, hook.interpolated_url)

        post retry_path

        expect(response).to have_gitlab_http_status(:redirect)
        expect(response).to redirect_to(edit_hook_path)
      end
    end
  end

  context 'in a project' do
    let_it_be(:project_hook) { create(:project_hook, project: project, url: 'http://example.test/') }

    let(:hook) { create(:project_hook, project: project) }
    let(:edit_hook_path) { edit_project_hook_path(project, hook) }

    before do
      create(:project_member, :guest, member_role: role, user: user, project: project)
    end

    describe Projects::HooksController do
      let(:index_path) { project_hooks_path(project) }
      let(:create_path) { project_hooks_path(project) }
      let(:update_path) { project_hook_path(project, project_hook) }
      let(:destroy_path) { project_hook_path(project, project_hook) }
      let(:test_path) { test_project_hook_path(project, project_hook) }

      it_behaves_like 'HooksController'
    end

    describe Projects::HookLogsController do
      let(:hook_log) { create(:web_hook_log, web_hook: hook, internal_error_message: 'get error') }

      let(:show_path) { hook_log.present.details_path }
      let(:retry_path) { hook_log.present.retry_path }

      it_behaves_like 'HookLogsController'
    end
  end

  context 'in a group' do
    let_it_be(:group_hook) { create(:group_hook, group: group, url: 'http://example.test/') }

    let(:hook) { create(:group_hook, group: group) }
    let(:edit_hook_path) { edit_group_hook_path(group, hook) }

    before do
      create(:group_member, :guest, member_role: role, user: user, group: group)
    end

    describe Groups::HooksController do
      let(:index_path) { group_hooks_path(group) }
      let(:create_path) { group_hooks_path(group) }
      let(:update_path) { group_hook_path(group, group_hook) }
      let(:destroy_path) { group_hook_path(group, hook) }
      let(:test_path) { test_group_hook_path(group, group_hook) }

      it_behaves_like 'HooksController'
    end

    describe Groups::HookLogsController do
      let(:hook_log) { create(:web_hook_log, web_hook: hook, internal_error_message: 'get error') }

      let(:show_path) { hook_log.present.details_path }
      let(:retry_path) { hook_log.present.retry_path }

      it_behaves_like 'HookLogsController'
    end
  end
end
