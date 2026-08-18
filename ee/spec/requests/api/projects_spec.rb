# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Projects, :aggregate_failures, feature_category: :groups_and_projects do
  include ExternalAuthorizationServiceHelpers
  include StubRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:another_user) { create(:user) }

  let(:project) { create(:project, namespace: user.namespace) }

  shared_examples 'inaccessable by reporter role and lower' do
    context 'for reporter' do
      before do
        reporter = create(:user)
        project.add_reporter(reporter)

        get api(path, reporter)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'for guest' do
      before do
        guest = create(:user)
        project.add_guest(guest)

        get api(path, guest)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'for anonymous' do
      before do
        anonymous = create(:user)

        get api(path, anonymous)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /projects' do
    it 'does not break on license checks' do
      enable_namespace_license_check!

      create(:project, :private, namespace: user.namespace)
      create(:project, :public, namespace: user.namespace)

      get api('/projects', user)

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when there are several projects owned by groups' do
      let_it_be(:admin) { create(:admin) }

      before do
        # Stub to prevent cascading settings queries from auto_duo_code_review_settings_available?
        # These queries are unrelated to what this N+1 spec is testing.
        # Added in https://gitlab.com/gitlab-org/gitlab/-/merge_requests/216006
        # TODO: Remove this workaround once https://gitlab.com/gitlab-org/gitlab/-/issues/442164 is addressed
        allow_any_instance_of(EE::Project).to receive(:auto_duo_code_review_settings_available?).and_return(false)
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        create(:project, :public, namespace: create(:group))

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get api('/projects', admin)
        end

        create_list(:project, 2, :public, namespace: create(:group))

        expect do
          get api('/projects', admin)
        end.not_to exceed_all_query_limit(control)
      end
    end

    context 'when checking namespace plans (SaaS)' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
        stub_ee_application_setting(should_check_namespace_plan: true)
        # custom_roles is read by the member-roles preloader, group_ip_restriction during serialization; license both.
        stub_licensed_features(group_ip_restriction: true, custom_roles: true)

        # Silence unrelated cascading settings queries (auto_duo_code_review); see gitlab-org/gitlab#442164.
        allow_next_found_instance_of(Project) do |project|
          allow(project).to receive(:auto_duo_code_review_settings_available?).and_return(false)
        end
      end

      def create_group_project
        group = create(:group)
        create(:gitlab_subscription, :ultimate, namespace: group)
        create(:project, :public, namespace: group)
      end

      it 'preloads group plans instead of loading a subscription per group', :use_sql_query_cache do
        create_group_project

        # Warm up caches so the control reflects steady-state, not first-request lazy loading.
        get api('/projects', user)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get api('/projects', user)
        end

        create_group_project
        create_group_project

        expect do
          get api('/projects', user)
        end.not_to exceed_all_query_limit(control).for_query(/FROM "gitlab_subscriptions"/)
      end
    end

    context 'when user requests hidden projects' do
      let_it_be(:hidden) { create(:project, :public, :hidden) }
      let(:filter_params) { { include_hidden: true } }

      context 'when user is not admin' do
        before do
          project.add_owner(user)
        end

        it 'does not return hidden projects' do
          get api('/projects', user), params: filter_params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.map { |p| p['id'] }).not_to include(hidden.id)
        end
      end

      context 'when user is an admin' do
        let_it_be(:admin) { create(:admin) }

        it 'also returns hidden projects' do
          get api("/projects", admin, admin_mode: true), params: filter_params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.map { |p| p['id'] }).to include(hidden.id)
        end

        context 'when include_hidden option is off' do
          let(:filter_params) { { include_hidden: nil } }

          it 'does not return hidden projects' do
            get api("/projects", admin, admin_mode: true), params: filter_params

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to be_an Array
            expect(json_response.map { |p| p['id'] }).not_to include(hidden.id)
          end
        end
      end
    end

    context 'when custom roles are enabled' do
      let_it_be(:admin) { create(:admin) }

      before do
        stub_licensed_features(custom_roles: true)

        # Stub to prevent cascading settings queries from auto_duo_code_review_settings_available?
        # These queries are unrelated to what this N+1 spec is testing.
        # Added in https://gitlab.com/gitlab-org/gitlab/-/merge_requests/216006
        # TODO: Remove this workaround once https://gitlab.com/gitlab-org/gitlab/-/issues/442164 is addressed
        allow_any_instance_of(EE::Project).to receive(:auto_duo_code_review_settings_available?).and_return(false)
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        create(:project, :public, namespace: create(:group))

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get api('/projects', admin)
        end

        create_list(:project, 2, :public, namespace: create(:group))

        expect do
          get api('/projects', admin)
        end.not_to exceed_all_query_limit(control)
      end
    end
  end

  describe 'GET /projects/:id' do
    subject { get api("/projects/#{project.id}", user) }

    context 'with external authorization' do
      let(:project) do
        create(:project,
          namespace: user.namespace,
          external_authorization_classification_label: 'the-label')
      end

      before do
        stub_licensed_features(external_authorization_service_api_management: true)
      end

      context 'when the user has access to the project' do
        before do
          external_service_allow_access(user, project)
        end

        it 'includes the label in the response' do
          get api("/projects/#{project.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['external_authorization_classification_label']).to eq('the-label')
        end

        context 'when authenticated with a token that has the ai_workflows scope' do
          let(:oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

          it 'is successful' do
            get api("/projects/#{project.id}", oauth_access_token: oauth_token)

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end

      context 'when the external service denies access' do
        before do
          external_service_deny_access(user, project)
        end

        it 'returns a 404' do
          get api("/projects/#{project.id}", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'it does not return the label when the feature is not available' do
        before do
          stub_licensed_features(external_authorization_service_api_management: false)
        end

        it 'does not include the label in the response' do
          get api("/projects/#{project.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['external_authorization_classification_label']).to be_nil
        end
      end

      context 'with ip restriction' do
        let(:group) { create :group, :private }

        before do
          create(:ip_restriction, group: group)
          group.add_maintainer(user)
          project.update!(namespace: group)
        end

        context 'when the group_ip_restriction feature is not available' do
          before do
            stub_licensed_features(group_ip_restriction: false)
          end

          it 'returns 200' do
            get api("/projects/#{project.id}", user)

            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context 'when the group_ip_restriction feature is available' do
          before do
            stub_licensed_features(group_ip_restriction: true)
          end

          it 'returns 404 for request from ip not in the range' do
            get api("/projects/#{project.id}", user)

            expect(response).to have_gitlab_http_status(:not_found)
          end

          it 'returns 200 for request from ip in the range' do
            get api("/projects/#{project.id}", user), headers: { 'REMOTE_ADDR' => '192.168.0.0' }

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end

    describe 'compliance_frameworks attribute' do
      context 'when compliance_framework feature is available' do
        context 'when project has a compliance framework' do
          before do
            create(:compliance_framework_project_setting, :sox, project: project)
            get api("/projects/#{project.id}", user)
          end

          it 'exposes framework names as array of strings' do
            expect(json_response['compliance_frameworks']).to contain_exactly(project.compliance_framework_settings.first.compliance_management_framework.name)
          end
        end

        context 'when project has no compliance framework' do
          before do
            get api("/projects/#{project.id}", user)
          end

          it 'returns an empty array' do
            expect(json_response['compliance_frameworks']).to eq([])
          end
        end
      end
    end

    describe 'ci_restrict_pipeline_cancellation_role' do
      before do
        project.add_maintainer(user)
      end

      context 'when unavailable' do
        it 'does not include ci_restrict_pipeline_cancellation_role' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'ci_restrict_pipeline_cancellation_role'
        end
      end

      context 'when available' do
        before do
          allow_next_instance_of(Ci::ProjectCancellationRestriction) do |cr|
            allow(cr).to receive(:feature_available?).and_return(true)
          end
        end

        it 'includes ci_restrict_pipeline_cancellation_role' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to have_key 'ci_restrict_pipeline_cancellation_role'
        end
      end
    end

    context 'issuable default templates' do
      let(:project) { create(:project, :public) }

      context 'when feature is available' do
        before do
          stub_licensed_features(issuable_default_templates: true)
        end

        it 'returns issuable default templates' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to have_key 'issues_template'
          expect(json_response).to have_key 'merge_requests_template'
        end

        context 'when user does not have permission to see issues' do
          let(:project) { create(:project, :public, :issues_private) }

          it 'does not return issue default templates' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).not_to have_key 'issues_template'
            expect(json_response).to have_key 'merge_requests_template'
          end
        end

        context 'when user does not have permission to see merge requests' do
          let(:project) { create(:project, :public, :merge_requests_private) }

          it 'does not return merge request default templates' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to have_key 'issues_template'
            expect(json_response).not_to have_key 'merge_requests_template'
          end
        end
      end

      context 'issuable default templates feature not available' do
        before do
          stub_licensed_features(issuable_default_templates: false)
        end

        it 'does not return issuable default templates' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'issues_template'
          expect(json_response).not_to have_key 'merge_requests_template'
        end
      end
    end

    context 'merge pipelines feature is available through license' do
      before do
        stub_licensed_features(merge_pipelines: true)
      end

      it 'returns merge pipelines enabled flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to have_key 'merge_pipelines_enabled'
      end
    end

    context 'merge pipelines feature is available through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it 'returns merge pipelines enabled flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to have_key 'merge_pipelines_enabled'
      end
    end

    context 'when usage ping is disabled on free license' do
      before do
        stub_usage_ping_features(false)
      end

      it 'does not return merge pipelines enabled flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'merge_pipelines_enabled'
      end
    end

    context 'merge pipelines feature not available' do
      before do
        stub_licensed_features(merge_pipelines: false)
      end

      it 'does not return merge pipelines enabled flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'merge_pipelines_enabled'
      end
    end

    context 'when external_status_checks is available' do
      before do
        stub_licensed_features(external_status_checks: true)
      end

      it 'returns only_allow_merge_if_all_status_checks_passed flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to have_key 'only_allow_merge_if_all_status_checks_passed'
      end
    end

    context 'when external_status_checks not available' do
      before do
        stub_licensed_features(external_status_checks: false)
      end

      it 'does not return only_allow_merge_if_all_status_checks_passed enabled flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'only_allow_merge_if_all_status_checks_passed'
      end
    end

    context 'when security_orchestration_policies is available and security_policy_pipeline_check flag is enabled' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'returns security_policy_pipeline_must_succeed flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to have_key 'security_policy_pipeline_must_succeed'
      end
    end

    context 'when security_orchestration_policies is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'does not return security_policy_pipeline_must_succeed flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'security_policy_pipeline_must_succeed'
      end
    end

    context 'when security_policy_pipeline_check feature flag is disabled' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
        stub_feature_flags(security_policy_pipeline_check: false)
      end

      it 'does not return security_policy_pipeline_must_succeed flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'security_policy_pipeline_must_succeed'
      end
    end

    context 'merge trains feature is available' do
      before do
        stub_licensed_features(merge_pipelines: true, merge_trains: true)
        project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true)
      end

      it 'returns merge trains enabled flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to have_key 'merge_trains_enabled'
      end
    end

    context 'merge trains feature not available' do
      before do
        stub_licensed_features(merge_trains: false)
      end

      it 'does not return merge trains enabled flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'merge_trains_enabled'
      end
    end

    context 'when protected_environments is available' do
      before do
        stub_licensed_features(protected_environments: true)
      end

      it 'returns allow_pipeline_trigger_approve_deployment flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to have_key 'allow_pipeline_trigger_approve_deployment'
      end
    end

    context 'when protected_environments is not available' do
      before do
        stub_licensed_features(protected_environments: false)
      end

      it 'does not returns allow_pipeline_trigger_approve_deployment flag' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'allow_pipeline_trigger_approve_deployment'
      end
    end
  end

  # Assumes the following variables are defined:
  # group
  # project
  # new_project_name
  # api_call
  shared_examples 'creates projects with templates' do
    before do
      group.add_maintainer(user)
      stub_licensed_features(custom_project_templates: true)
      stub_ee_application_setting(custom_project_templates_group_id: group.id)
    end

    it 'creates a project using a template' do
      expect(ProjectExportWorker).to receive(:perform_async).and_call_original

      Sidekiq::Testing.fake! do
        expect { api_call }.to change { Project.count }.by(1)
      end

      expect(response).to have_gitlab_http_status(:created)

      project = Project.find(json_response['id'])
      expect(project.name).to eq(new_project_name)
    end

    it 'returns a 400 error for an invalid template name' do
      project_params.delete(:template_project_id)
      project_params[:template_name] = 'bogus-template'

      expect { api_call }.not_to change { Project.count }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']['template_name']).to eq(["'bogus-template' is unknown or invalid"])
    end

    it 'returns a 400 error for an invalid template ID' do
      project_params.delete(:template_name)
      new_project = create(:project)
      project_params[:template_project_id] = new_project.id

      expect { api_call }.not_to change { Project.count }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']['template_project_id']).to eq(["#{new_project.id} is unknown or invalid"])
    end

    context 'When template_name and template_project_id both are missing while use_custom_template is true' do
      let(:project_params) { super().merge(use_custom_template: true).except(:template_name, :template_project_id) }

      it 'return 400 error with missing template_name and template_project_id error' do
        expect { api_call }.not_to change { Project.count }
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']['use_custom_template']).to eq(["must be used with template_name or template_project_id"])
      end
    end
  end

  shared_context 'base instance template models' do
    let(:group) { create(:group) }
    let!(:project) { create(:project, :public, namespace: group) }
    let(:new_project_name) { "project-#{SecureRandom.hex}" }
  end

  shared_context 'instance template name' do
    include_context 'base instance template models'

    let(:project_params) do
      {
        template_name: project.name,
        name: new_project_name,
        path: new_project_name,
        use_custom_template: true,
        namespace_id: group.id
      }
    end
  end

  shared_context 'instance template ID' do
    include_context 'base instance template models'

    let(:project_params) do
      {
        template_project_id: project.id,
        name: new_project_name,
        path: new_project_name,
        use_custom_template: true,
        namespace_id: group.id
      }
    end
  end

  shared_context 'base group template models' do
    let(:parent_group) { create(:group) }
    let(:subgroup) { create(:group, :public, parent: parent_group) }
    let(:group) { subgroup }
    let!(:project) { create(:project, :public, namespace: subgroup) }
    let(:new_project_name) { "project-#{SecureRandom.hex}" }
  end

  shared_context 'group template name' do
    include_context 'base group template models'

    let(:project_params) do
      {
        template_name: project.name,
        name: new_project_name,
        path: new_project_name,
        use_custom_template: true,
        group_with_project_templates_id: subgroup.id,
        namespace_id: subgroup.id
      }
    end
  end

  shared_context 'group template ID' do
    include_context 'base group template models'

    let(:project_params) do
      {
        template_project_id: project.id,
        name: new_project_name,
        path: new_project_name,
        use_custom_template: true,
        group_with_project_templates_id: subgroup.id,
        namespace_id: subgroup.id
      }
    end
  end

  describe 'GET /projects/:id/users' do
    shared_examples_for 'project users response' do
      it 'returns the project users' do
        get api("/projects/#{project.id}/users", current_user)

        user = project.namespace.owner

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)

        first_user = json_response.first
        expect(first_user['username']).to eq(user.username)
        expect(first_user['name']).to eq(user.name)
      end
    end

    context 'when unauthenticated' do
      it_behaves_like 'project users response' do
        let(:project) { create(:project, :public) }
        let(:current_user) { nil }
      end
    end

    context 'when authenticated' do
      context 'valid request' do
        it_behaves_like 'project users response' do
          let(:current_user) { user }
        end
      end
    end
  end

  describe 'POST /projects/user/:id' do
    let(:admin) { create(:admin) }
    let(:api_call) { post api("/projects/user/#{user.id}", admin, admin_mode: true), params: project_params }

    context 'with templates' do
      include_context 'instance template name' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'instance template ID' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'group template name' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'group template ID' do
        it_behaves_like 'creates projects with templates'
      end
    end
  end

  describe 'POST /projects' do
    let(:api_call) { post api('/projects', user), params: project_params }

    context 'with templates' do
      include_context 'instance template name' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'instance template ID' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'group template name' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'group template ID' do
        it_behaves_like 'creates projects with templates'
      end
    end

    context 'when importing with mirror attributes' do
      let(:import_url) { generate(:url) }
      let(:mirror_params) do
        {
          name: "Foo",
          mirror: true,
          import_url: import_url,
          mirror_trigger_builds: true
        }
      end

      before do
        allow(Gitlab::GitalyClient::RemoteService).to receive(:exists?).with(import_url).and_return(true)
        stub_application_setting(import_sources: ['git'])
      end

      it 'creates new project with pull mirroring set up' do
        post api('/projects', user), params: mirror_params

        expect(response).to have_gitlab_http_status(:created)
        expect(Project.find(json_response['id'])).to have_attributes(
          mirror: true,
          import_url: import_url,
          mirror_user_id: user.id,
          mirror_trigger_builds: true
        )
      end

      it 'creates project without mirror settings when repository mirroring feature is disabled' do
        stub_licensed_features(repository_mirrors: false)

        expect { post api('/projects', user), params: mirror_params }
          .to change { Project.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(Project.find(json_response['id'])).to have_attributes(
          mirror: false,
          import_url: import_url,
          mirror_user_id: nil,
          mirror_trigger_builds: false
        )
      end

      context 'when pull mirroring is not available' do
        before do
          stub_ee_application_setting(mirror_available: false)
        end

        it 'ignores the mirroring options' do
          post api('/projects', user), params: mirror_params

          expect(response).to have_gitlab_http_status(:created)
          expect(Project.find(json_response['id']).mirror?).to be false
        end

        it 'creates project with mirror settings' do
          admin = create(:admin)

          post api('/projects', admin, admin_mode: true), params: mirror_params

          expect(response).to have_gitlab_http_status(:created)
          expect(Project.find(json_response['id'])).to have_attributes(
            mirror: true,
            import_url: import_url,
            mirror_user_id: admin.id,
            mirror_trigger_builds: true
          )
        end
      end
    end

    context 'with requirements_access_level' do
      let(:project_params) { { name: 'bar', requirements_access_level: 'disabled' } }

      before do
        stub_licensed_features(requirements: true)
      end

      it 'updates project with given value' do
        post api('/projects', user), params: project_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['requirements_access_level']).to eq(project_params[:requirements_access_level])
      end
    end

    context 'when creating project with auto_duo_code_review_enabled' do
      let(:project_params) { { name: 'test-project', auto_duo_code_review_enabled: true } }

      context 'when license is available' do
        before do
          stub_licensed_features(review_merge_request: true)
        end

        it 'accepts the parameter and creates project' do
          post api('/projects', user), params: project_params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when license is not available' do
        before do
          stub_licensed_features(review_merge_request: false)
        end

        it 'creates project without auto_duo_code_review_enabled' do
          post api('/projects', user), params: project_params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['auto_duo_code_review_enabled']).to be_nil
        end
      end
    end

    context 'when creating project with reviewer_assignment_strategy' do
      let(:project_params) { { name: 'test-project', reviewer_assignment_strategy: 'code_owners' } }

      before do
        stub_licensed_features(code_owners: true)
      end

      it 'ignores the edit-only parameter and leaves the default strategy' do
        post api('/projects', user), params: project_params

        expect(response).to have_gitlab_http_status(:created)
        expect(Project.find(json_response['id']).reviewer_assignment_strategy).to eq('disabled')
      end
    end

    context 'when creating project with duo vulnerability attributes' do
      context 'when creating with duo_sast_fp_detection_enabled' do
        let(:project_params) { { name: 'test-project', duo_sast_fp_detection_enabled: true } }

        it 'ignores the parameter and creates project with default value' do
          stub_licensed_features(ai_features: true)

          post api('/projects', user), params: project_params

          expect(response).to have_gitlab_http_status(:created)
          expect(Project.find(json_response['id']).duo_sast_fp_detection_enabled).to be(false)
        end
      end

      context 'when creating with duo_secret_detection_fp_enabled' do
        let(:project_params) { { name: 'test-project', duo_secret_detection_fp_enabled: true } }

        it 'ignores the parameter and creates project with default value' do
          stub_licensed_features(ai_features: true)
          stub_feature_flags(duo_secret_detection_false_positive: true)

          post api('/projects', user), params: project_params

          expect(response).to have_gitlab_http_status(:created)
          expect(Project.find(json_response['id']).duo_secret_detection_fp_enabled).to be(false)
        end
      end

      context 'when creating with duo_dependency_bump_breaking_changes_enabled' do
        let(:project_params) { { name: 'test-project', duo_dependency_bump_breaking_changes_enabled: true } }

        it 'ignores the parameter and creates project with default value' do
          stub_licensed_features(ai_features: true)
          stub_feature_flags(enable_dependency_bump_breaking_changes: true)

          post api('/projects', user), params: project_params

          expect(response).to have_gitlab_http_status(:created)
          expect(Project.find(json_response['id']).duo_dependency_bump_breaking_changes_enabled).to be(false)
        end
      end

      context 'when creating with duo_sast_vr_workflow_enabled' do
        let(:project_params) { { name: 'test-project', duo_sast_vr_workflow_enabled: true } }

        it 'ignores the parameter and creates project with default value' do
          stub_licensed_features(ai_features: true)

          post api('/projects', user), params: project_params

          expect(response).to have_gitlab_http_status(:created)
          expect(Project.find(json_response['id']).duo_sast_vr_workflow_enabled).to be(false)
        end
      end
    end

    context 'when security_orchestration_policies license is available and security_policy_pipeline_check flag is enabled' do
      let(:project_params) { { name: 'test-project' } }

      before do
        stub_licensed_features(security_orchestration_policies: true)
        stub_feature_flags(security_policy_pipeline_check: true)
      end

      it 'creates the project successfully without raising 404' do
        post api('/projects', user), params: project_params

        expect(response).to have_gitlab_http_status(:created)
      end
    end
  end

  describe 'GET projects/:id/audit_events' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :public, namespace: user.namespace) }

    let(:path) { "/projects/#{project.id}/audit_events" }

    it_behaves_like 'inaccessable by reporter role and lower'

    context 'when authenticated, as a member' do
      let_it_be(:developer) { create(:user) }

      before do
        stub_licensed_features(audit_events: true)
        project.add_developer(developer)
      end

      it_behaves_like 'authorizing granular token permissions', :read_audit_event do
        let(:boundary_object) { project }
        let(:user) { developer }
        let(:request) { get api(path, personal_access_token: pat) }
      end

      it 'returns only events authored by current user' do
        project_audit_event_1 = create(:audit_events_project_audit_event, project_id: project.id, author_id: developer.id)
        create(:audit_events_project_audit_event, project_id: project.id, author_id: 666)

        get api(path, developer)

        expect_response_contain_exactly(project_audit_event_1.id.to_i)
      end
    end

    context 'when authenticated, as a security manager' do
      let_it_be(:security_manager) { create(:user) }
      let_it_be(:other_user) { create(:user) }

      before do
        stub_licensed_features(audit_events: true)
        project.add_security_manager(security_manager)
      end

      it 'returns events from all members' do
        sm_event = create(:audit_events_project_audit_event, project_id: project.id, author_id: security_manager.id)
        other_event = create(:audit_events_project_audit_event, project_id: project.id, author_id: other_user.id)

        get api(path, security_manager)

        event_ids = json_response.map { |e| e['id'] }
        expect(event_ids).to include(sm_event.id, other_event.id)
      end
    end

    context 'when authenticated, as a project owner' do
      before do
        project.add_maintainer(user)
      end

      context 'audit events feature is not available' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it_behaves_like '403 response' do
          let(:request) { get api(path, user) }
        end
      end

      context 'audit events feature is available' do
        before do
          stub_licensed_features(audit_events: true)
        end

        let_it_be(:project_audit_event_1) { create(:audit_events_project_audit_event, created_at: Date.new(2000, 1, 10), project_id: project.id) }
        let_it_be(:project_audit_event_2) { create(:audit_events_project_audit_event, created_at: Date.new(2000, 1, 15), project_id: project.id) }
        let_it_be(:project_audit_event_3) { create(:audit_events_project_audit_event, created_at: Date.new(2000, 1, 20), project_id: project.id) }

        it 'returns 200 response' do
          get api(path, user)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'includes the correct pagination headers' do
          audit_events_counts = 3

          get api(path, user)

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(audit_events_counts.to_s)
          expect(response.headers['X-Page']).to eq('1')
        end

        it 'does not include audit events of a different project' do
          project = create(:project)
          audit_event = create(:audit_events_project_audit_event, created_at: Date.new(2000, 1, 20), project_id: project.id)

          get api(path, user)

          audit_event_ids = json_response.map { |audit_event| audit_event['id'] }

          expect(audit_event_ids).not_to include(audit_event.id)
        end

        context 'parameters' do
          it_behaves_like 'an endpoint with keyset pagination' do
            let_it_be(:admin) { create(:admin) }
            let!(:audit_event_1) { create(:audit_events_project_audit_event, project_id: project.id) }
            let!(:audit_event_2) { create(:audit_events_project_audit_event, project_id: project.id) }

            let(:first_record) { audit_event_2 }
            let(:second_record) { audit_event_1 }
            let(:url) { "/projects/#{project.id}/audit_events" }
            let(:api_call) { api(url, admin, admin_mode: true) }
          end

          context 'created_before parameter' do
            it "returns audit events created before the given parameter" do
              created_before = '2000-01-20T00:00:00.060Z'

              get api(path, user), params: { created_before: created_before }

              expect(json_response.size).to eq 3
              expect(json_response.first["id"]).to eq(project_audit_event_3.id)
              expect(json_response.last["id"]).to eq(project_audit_event_1.id)
            end
          end

          context 'created_after parameter' do
            it "returns audit events created after the given parameter" do
              created_after = '2000-01-12T00:00:00.060Z'

              get api(path, user), params: { created_after: created_after }

              expect(json_response.size).to eq 2
              expect(json_response.first["id"]).to eq(project_audit_event_3.id)
              expect(json_response.last["id"]).to eq(project_audit_event_2.id)
            end
          end
        end

        context 'response schema' do
          it 'matches the response schema' do
            get api(path, user)

            expect(response).to match_response_schema('public_api/v4/audit_events', dir: 'ee')
          end
        end

        context 'Snowplow event tracking' do
          it_behaves_like 'Snowplow event tracking with RedisHLL context' do
            subject(:api_request) { get api(path, user) }

            let(:category) { 'EE::API::Projects' }
            let(:action) { 'project_audit_event_request' }
            let(:namespace) { project.namespace }
            let(:context) { [::Gitlab::Tracking::ServicePingContext.new(data_source: :redis_hll, event: 'a_compliance_audit_events_api').to_context] }
          end
        end
      end
    end
  end

  describe 'GET projects/:id/audit_events/:audit_event_id' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :public, namespace: user.namespace) }
    let_it_be(:project_audit_event) { create(:audit_events_project_audit_event, created_at: Date.new(2000, 1, 10), project_id: project.id) }

    let(:path) { "/projects/#{project.id}/audit_events/#{project_audit_event.id}" }

    it_behaves_like 'inaccessable by reporter role and lower'

    context 'when authenticated, as a guest' do
      let_it_be(:guest) { create(:user) }

      before do
        stub_licensed_features(audit_events: true)
        project.add_guest(guest)
      end

      it_behaves_like '403 response' do
        let(:request) { get api(path, guest) }
      end
    end

    context 'when authenticated, as a member' do
      let_it_be(:developer) { create(:user) }

      before do
        stub_licensed_features(audit_events: true)
        project.add_developer(developer)
      end

      it_behaves_like 'authorizing granular token permissions', :read_audit_event do
        let(:boundary_object) { project }
        let(:user) { developer }
        let(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id, author_id: developer.id) }
        let(:request) do
          get api("/projects/#{project.id}/audit_events/#{audit_event.id}", personal_access_token: pat)
        end
      end

      it 'returns 200 response' do
        audit_event = create(:audit_events_project_audit_event, project_id: project.id, author_id: developer.id)
        path = "/projects/#{project.id}/audit_events/#{audit_event.id}"

        get api(path, developer)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'existing audit event of a different user' do
        let_it_be(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id, author_id: another_user.id) }

        let(:path) { "/projects/#{project.id}/audit_events/#{audit_event.id}" }

        it_behaves_like '404 response' do
          let(:request) { get api(path, developer) }
        end
      end
    end

    context 'when authenticated, as a project owner' do
      context 'audit events feature is not available' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it_behaves_like '403 response' do
          let(:request) { get api(path, user) }
        end
      end

      context 'audit events feature is available' do
        before do
          stub_licensed_features(audit_events: true)
        end

        context 'existent audit event' do
          it 'returns 200 response' do
            get api(path, user)

            expect(response).to have_gitlab_http_status(:ok)
          end

          context 'response schema' do
            it 'matches the response schema' do
              get api(path, user)

              expect(response).to match_response_schema('public_api/v4/audit_event', dir: 'ee')
            end
          end

          context 'invalid audit_event_id' do
            let(:path) { "/projects/#{project.id}/audit_events/an-invalid-id" }

            it_behaves_like '400 response' do
              let(:request) { get api(path, user) }
            end
          end

          context 'non existent audit event' do
            context 'non existent audit event of a project' do
              let(:path) { "/projects/#{project.id}/audit_events/666777" }

              it_behaves_like '404 response' do
                let(:request) { get api(path, user) }
              end
            end

            context 'existing audit event of a different project' do
              let(:new_project) { create(:project) }
              let(:audit_event) { create(:audit_events_project_audit_event, created_at: Date.new(2000, 1, 10), project_id: new_project.id) }

              let(:path) { "/projects/#{project.id}/audit_events/#{audit_event.id}" }

              it_behaves_like '404 response' do
                let(:request) { get api(path, user) }
              end
            end
          end
        end
      end
    end
  end

  describe 'PUT /projects/:id' do
    let(:project) { create(:project, namespace: user.namespace) }
    let(:project_params) { {} }

    subject { put api("/projects/#{project.id}", user), params: project_params }

    context 'issuable default templates feature is available' do
      before do
        stub_licensed_features(issuable_default_templates: true)
      end

      context 'when updating issues_template' do
        let(:project_params) { { issues_template: '## New Issue Template' } }

        it 'updates the content' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['issues_template']).to eq(project_params[:issues_template])
        end
      end

      context 'when updating merge_requests_template' do
        let(:project_params) { { merge_requests_template: '## New Merge Request Template' } }

        it 'updates the content' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_requests_template']).to eq(project_params[:merge_requests_template])
        end
      end

      context 'when updating requirements_access_level' do
        let(:project_params) { { requirements_access_level: 'disabled' } }

        before do
          stub_licensed_features(requirements: true)
        end

        it 'updates project with given value' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['requirements_access_level']).to eq(project_params[:requirements_access_level])
        end
      end
    end

    context 'issuable default templates feature not available' do
      before do
        stub_licensed_features(issuable_default_templates: false)
      end

      context 'when updating issues_template' do
        let(:project_params) { { issues_template: '## New Issue Template' } }

        it 'does not update the content' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'issues_template'
        end
      end

      context 'when updating merge_requests_template' do
        let(:project_params) { { merge_requests_template: '## New Merge Request Template' } }

        it 'does not update the content' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'merge_requests_template'
        end
      end
    end

    context 'merge pipelines feature is available' do
      before do
        stub_licensed_features(merge_pipelines: true)
      end

      let(:project_params) { { merge_pipelines_enabled: true } }

      it 'updates the content' do
        expect { subject }.to change { project.reload.merge_pipelines_enabled }

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.merge_pipelines_enabled).to eq(project_params[:merge_pipelines_enabled])
        expect(json_response['merge_pipelines_enabled']).to eq(project_params[:merge_pipelines_enabled])
      end

      context 'when user does not have permission' do
        let(:developer_user) { create(:user) }

        before do
          project.add_developer(developer_user)
        end

        it 'does not update the content' do
          expect do
            put api("/projects/#{project.id}", developer_user), params: project_params
          end.not_to change { project.reload.merge_pipelines_enabled }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'merge pipelines feature feature not available' do
      before do
        stub_licensed_features(merge_pipelines: false)
      end

      let(:project_params) { { merge_pipelines_enabled: true } }

      it 'does not update the content' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'merge_pipelines_enabled'
      end
    end

    context 'when external_status_checks is available' do
      before do
        stub_licensed_features(external_status_checks: true)
      end

      let(:project_params) { { only_allow_merge_if_all_status_checks_passed: true } }

      it 'updates the content' do
        expect { subject }.to change { project.reload.only_allow_merge_if_all_status_checks_passed }.from(false).to(true)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['only_allow_merge_if_all_status_checks_passed']).to eq(project_params[:only_allow_merge_if_all_status_checks_passed])
      end

      context 'when user does not have permission' do
        let(:developer_user) { create(:user) }

        before do
          project.add_developer(developer_user)
        end

        it 'does not update the content' do
          expect do
            put api("/projects/#{project.id}", developer_user), params: project_params
          end.not_to change { project.reload.only_allow_merge_if_all_status_checks_passed }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when approvals_before_merge is nil' do
      let(:project_params) { { approvals_before_merge: nil } }

      it_behaves_like '400 response' do
        let(:request) { subject }
      end
    end

    context 'when external_status_checks not available' do
      before do
        stub_licensed_features(external_status_checks: false)
      end

      let(:project_params) { { only_allow_merge_if_all_status_checks_passed: true } }

      it 'does not update the content' do
        expect { subject }.to not_change { project.reload.only_allow_merge_if_all_status_checks_passed }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'only_allow_merge_if_all_status_checks_passed'
      end
    end

    context 'merge trains feature is available' do
      before do
        stub_licensed_features(merge_pipelines: true, merge_trains: true)
        project.update!(merge_pipelines_enabled: true, merge_trains_enabled: false)
      end

      let(:project_params) { { merge_trains_enabled: true } }

      it 'updates the content' do
        expect { subject }.to change { project.reload.merge_trains_enabled }

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.merge_trains_enabled).to eq(project_params[:merge_trains_enabled])
        expect(json_response['merge_trains_enabled']).to eq(project_params[:merge_trains_enabled])
      end

      context 'when user does not have permission' do
        let(:developer_user) { create(:user) }

        before do
          project.add_developer(developer_user)
        end

        it 'does not update the content' do
          expect do
            put api("/projects/#{project.id}", developer_user), params: project_params
          end.not_to change { project.reload.merge_trains_enabled }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'merge trains feature feature not available' do
      before do
        stub_licensed_features(merge_trains: false)
      end

      let(:project_params) { { merge_trains_enabled: true } }

      it 'does not update the content' do
        expect { subject }.not_to change { project.merge_trains_enabled }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'merge_trains_enabled'
      end
    end

    context 'license validation for merge pipeline settings' do
      context 'when merge_pipelines feature is not available' do
        before do
          stub_licensed_features(merge_pipelines: false)
        end

        let(:project_params) { { merge_pipelines_enabled: true } }

        it 'does not update merge_pipelines_enabled even with admin permissions' do
          expect { subject }.not_to change { project.reload.merge_pipelines_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'merge_pipelines_enabled'
        end
      end

      context 'when merge_trains feature is not available' do
        before do
          stub_licensed_features(merge_trains: false)
        end

        let(:project_params) { { merge_trains_enabled: true } }

        it 'does not update merge_trains_enabled even with admin permissions' do
          expect { subject }.not_to change { project.reload.merge_trains_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'merge_trains_enabled'
        end
      end

      context 'when merge_trains feature is not available for merge_trains_skip_train_allowed' do
        before do
          stub_licensed_features(merge_trains: false)
        end

        let(:project_params) { { merge_trains_skip_train_allowed: true } }

        it 'does not update merge_trains_skip_train_allowed even with admin permissions' do
          expect { subject }.not_to change { project.reload.merge_trains_skip_train_allowed }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'merge_trains_skip_train_allowed'
        end
      end

      context 'when both merge_pipelines and merge_trains features are not available' do
        before do
          stub_licensed_features(merge_pipelines: false, merge_trains: false)
        end

        let(:project_params) do
          {
            merge_pipelines_enabled: true,
            merge_trains_enabled: true,
            merge_trains_skip_train_allowed: true
          }
        end

        it 'does not update any merge pipeline/train settings even with admin permissions' do
          expect { subject }
          .to not_change { project.reload.merge_pipelines_enabled }
          .and not_change { project.reload.merge_trains_enabled }
          .and not_change { project.reload.merge_trains_skip_train_allowed }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'merge_pipelines_enabled'
          expect(json_response).not_to have_key 'merge_trains_enabled'
          expect(json_response).not_to have_key 'merge_trains_skip_train_allowed'
        end
      end

      context 'when features are available' do
        before do
          stub_licensed_features(merge_pipelines: true, merge_trains: true)
        end

        let(:project_params) do
          {
            merge_pipelines_enabled: true,
            merge_trains_enabled: true,
            merge_trains_skip_train_allowed: true
          }
        end

        it 'updates all merge pipeline/train settings with admin permissions' do
          expect { subject }.to change { project.reload.merge_pipelines_enabled }.to(true)
          .and change { project.reload.merge_trains_enabled }.to(true)
          .and change { project.reload.merge_trains_skip_train_allowed }.to(true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_pipelines_enabled']).to be(true)
          expect(json_response['merge_trains_enabled']).to be(true)
          expect(json_response['merge_trains_skip_train_allowed']).to be(true)
        end
      end

      context 'for merge_train_enforcement' do
        let(:project_params) { { merge_train_enforcement: 'enforce_for_all_users' } }

        context 'when merge_trains feature is available' do
          before do
            stub_licensed_features(merge_pipelines: true, merge_trains: true)
          end

          it 'updates merge_train_enforcement with admin permissions' do
            expect { subject }
              .to change { project.reload.merge_train_enforcement }.from('allow_bypass').to('enforce_for_all_users')

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['merge_train_enforcement']).to eq('enforce_for_all_users')
          end
        end

        context 'when merge_trains feature is not available' do
          before do
            stub_licensed_features(merge_trains: false)
          end

          it 'does not update merge_train_enforcement even with admin permissions' do
            expect { subject }.not_to change { project.reload.merge_train_enforcement }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).not_to have_key 'merge_train_enforcement'
          end
        end
      end
    end

    context 'when setting ci_restrict_pipeline_cancellation_role' do
      let(:new_role) { 'maintainer' }
      let(:project_params) { { ci_restrict_pipeline_cancellation_role: new_role } }

      context 'when licence is available' do
        before do
          stub_licensed_features(ci_pipeline_cancellation_restrictions: true)
        end

        it 'updates the value' do
          expect { subject }.to change { project.reload.ci_cancellation_restriction.role }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['ci_restrict_pipeline_cancellation_role']).to eq new_role
        end
      end

      context 'when licence is not available' do
        it 'does not update the value' do
          expect { subject }.not_to change { project.reload.ci_cancellation_restriction.role }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key 'ci_restrict_pipeline_cancellation_role'
        end
      end
    end

    context 'when updating ci_id_token_sub_claim_components' do
      let(:project_params) { { ci_id_token_sub_claim_components: sub_claim_components } }
      let(:sub_claim_components) { ['project_path'] }

      it 'updates the project setting and returns its new value' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['ci_id_token_sub_claim_components']).to eq(sub_claim_components)
        expect(project.reload.ci_id_token_sub_claim_components).to eq(sub_claim_components)
      end

      context 'when value is invalid' do
        let(:sub_claim_components) { ['invalid-component'] }

        it 'fails with errors' do
          subject

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']['ci_cd_settings.id_token_sub_claim_components']).to include(
            "invalid-component is not an allowed sub claim component",
            "project_path or project_id must be the first element of the sub claim")
        end
      end

      context 'when using ref_protected component' do
        let(:sub_claim_components) { %w[project_path ref_protected] }

        it 'updates the project setting and returns its new value' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['ci_id_token_sub_claim_components']).to eq(sub_claim_components)
          expect(project.reload.ci_id_token_sub_claim_components).to eq(sub_claim_components)
        end
      end
    end

    context 'when updating external classification' do
      before do
        enable_external_authorization_service_check
        stub_licensed_features(external_authorization_service_api_management: true)
      end

      let(:project_params) { { external_authorization_classification_label: 'new label' } }

      it 'updates the classification label' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.reload.external_authorization_classification_label).to eq('new label')
      end
    end

    context 'when updating mirror related attributes' do
      let(:import_url) { generate(:url) }
      let(:project_params) do
        {
          mirror: true,
          import_url: import_url,
          mirror_trigger_builds: true,
          only_mirror_protected_branches: true,
          mirror_overwrites_diverged_branches: true
        }
      end

      before do
        allow(Gitlab::GitalyClient::RemoteService).to receive(:exists?).with(import_url).and_return(true)
      end

      context 'when pull mirroring is not available' do
        before do
          stub_ee_application_setting(mirror_available: false)
        end

        it 'does not update mirror related attributes' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload.mirror).to be false
        end

        it 'updates mirror related attributes when user is admin' do
          admin = create(:admin)
          unrelated_user = create(:user)

          project_params[:mirror_user_id] = unrelated_user.id
          project.add_maintainer(admin)

          expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

          put(api("/projects/#{project.id}", admin, admin_mode: true), params: project_params)

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload).to have_attributes(
            mirror: true,
            import_url: import_url,
            mirror_user_id: unrelated_user.id,
            mirror_trigger_builds: true,
            only_mirror_protected_branches: true,
            mirror_overwrites_diverged_branches: true
          )
        end
      end

      context 'when import_url is not a valid git endpoint' do
        it 'disallows creating a project with an import_url that is not reachable' do
          allow(Gitlab::GitalyClient::RemoteService).to receive(:exists?).with(import_url).and_return(false)

          subject

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Unable to access repository with the URL and credentials provided')
        end
      end

      it 'updates mirror related attributes' do
        expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.reload).to have_attributes(
          mirror: true,
          import_url: import_url,
          mirror_user_id: user.id,
          mirror_trigger_builds: true,
          only_mirror_protected_branches: true,
          mirror_overwrites_diverged_branches: true
        )
      end

      context 'when only disabling pull mirror' do
        let(:project) { create(:project, mirror: true, import_url: import_url, mirror_user: user, namespace: user.namespace) }
        let(:project_params) do
          { mirror: false }
        end

        it 'updates mirror to false' do
          expect { subject }.to change { project.reload.mirror }.from(true).to(false)
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when updating mirror_trigger_builds in isolation' do
        before do
          project.update!(mirror: true, mirror_user_id: user.id, import_url: import_url)
        end

        let(:project_params) { { mirror_trigger_builds: true } }

        it 'updates mirror_trigger_builds without requiring other parameters' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['mirror_trigger_builds']).to be(true)
        end
      end

      it 'updates project without mirror attributes when the project is unable to set up repository mirroring' do
        stub_licensed_features(repository_mirrors: false)

        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.reload.mirror).to be false
      end

      it 'renders an API error when mirror user is invalid' do
        invalid_mirror_user = create(:user)
        project.add_developer(invalid_mirror_user)
        project_params[:mirror_user_id] = invalid_mirror_user.id

        subject

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response["message"]["mirror_user_id"].first).to eq("is invalid")
      end

      it 'returns 403 when the user does not have access to mirror settings' do
        developer = create(:user)
        project.add_developer(developer)

        put(api("/projects/#{project.id}", developer), params: project_params)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      context 'with mirror_branch_regex and only_mirror_protected_branches' do
        let(:project_params) do
          {
            mirror: true,
            import_url: import_url,
            only_mirror_protected_branches: false,
            mirror_branch_regex: 'text'
          }
        end

        it 'fails' do
          subject

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'with only_mirror_protected_branches' do
        context 'when enabling only_mirror_protected_branches' do
          let(:project_params) do
            {
              mirror: true,
              import_url: import_url,
              only_mirror_protected_branches: true
            }
          end

          before do
            project.update!(mirror_branch_regex: 'text')
          end

          it 'removes mirror_branch_regex' do
            expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(project.reload).to have_attributes(
              only_mirror_protected_branches: true,
              mirror_branch_regex: nil
            )
          end
        end

        context 'when disabling only_mirror_protected_branches' do
          let(:project_params) do
            {
              mirror: true,
              import_url: import_url,
              only_mirror_protected_branches: false
            }
          end

          before do
            project.update!(mirror_branch_regex: 'text')
          end

          it 'keeps mirror_branch_regex' do
            expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(project.reload).to have_attributes(
              only_mirror_protected_branches: false,
              mirror_branch_regex: 'text'
            )
          end
        end
      end

      context 'when removing mirror_branch_regex' do
        let(:project_params) do
          { mirror: true,
            import_url: import_url,
            mirror_branch_regex: nil }
        end

        context 'with mirror_branch_regex present' do
          before do
            project.update!(mirror_branch_regex: 'text')
          end

          it 'removes mirror_branch_regex' do
            expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(project.reload.mirror_branch_regex).to be_nil
          end
        end

        context 'with mirror_branch_regex nil and only_mirror_protected_branches is truthy' do
          before do
            project.update!(mirror_branch_regex: nil, only_mirror_protected_branches: true)
          end

          it 'does not change only_mirror_protected_branches value' do
            expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(project.reload.mirror_branch_regex).to be_nil
            expect(project.reload.only_mirror_protected_branches).to be_truthy
          end
        end

        context 'with mirror_branch_regex nil and only_mirror_protected_branches is false' do
          before do
            project.update!(mirror_branch_regex: nil, only_mirror_protected_branches: false)
          end

          it 'does not change only_mirror_protected_branches value' do
            expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(project.reload.mirror_branch_regex).to be_nil
            expect(project.reload.only_mirror_protected_branches).to be_falsey
          end
        end
      end

      context 'with mirror_branch_regex' do
        let(:project_params) do
          { mirror: true,
            import_url: import_url,
            mirror_branch_regex: 'text' }
        end

        before do
          project.update!(only_mirror_protected_branches: true)
        end

        it 'succeeds' do
          expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload).to have_attributes(
            only_mirror_protected_branches: false,
            mirror_branch_regex: 'text'
          )
        end
      end
    end

    describe 'updating approvals_before_merge attribute' do
      context 'when authenticated as project owner' do
        let(:project_params) { { approvals_before_merge: 3 } }

        it 'updates approvals_before_merge' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['approvals_before_merge']).to eq(3)
        end
      end
    end

    context 'when protected_environments is available' do
      before do
        stub_licensed_features(protected_environments: true)
      end

      let(:project_params) { { allow_pipeline_trigger_approve_deployment: true } }

      it 'updates the content' do
        expect { subject }.to change { project.reload.allow_pipeline_trigger_approve_deployment }.from(false).to(true)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['allow_pipeline_trigger_approve_deployment']).to eq(project_params[:allow_pipeline_trigger_approve_deployment])
      end
    end

    context 'when protected_environments not available' do
      before do
        stub_licensed_features(protected_environments: false)
      end

      let(:project_params) { { allow_pipeline_trigger_approve_deployment: true } }

      it 'does not update the content' do
        expect { subject }.to not_change { project.reload.allow_pipeline_trigger_approve_deployment }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key 'allow_pipeline_trigger_approve_deployment'
      end
    end

    context 'when jira_issue_association_enforcement is available' do
      before do
        stub_licensed_features(jira_issue_association_enforcement: true)
      end

      let(:project_params) { { prevent_merge_without_jira_issue: true } }

      it 'updates prevent_merge_without_jira_issue' do
        expect { subject }.to change { project.reload.prevent_merge_without_jira_issue }.from(false).to(true)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['prevent_merge_without_jira_issue']).to eq(project_params[:prevent_merge_without_jira_issue])
      end
    end

    context 'when jira_issue_association_enforcement is not available' do
      before do
        stub_licensed_features(jira_issue_association_enforcement: false)
      end

      let(:project_params) { { prevent_merge_without_jira_issue: true } }

      it 'does not update prevent_merge_without_jira_issue' do
        expect { subject }.to not_change { project.reload.prevent_merge_without_jira_issue }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['prevent_merge_without_jira_issue']).to be_nil
      end
    end

    describe 'updating of spp_repository_pipeline_access' do
      let(:project_params) { { spp_repository_pipeline_access: false } }

      context 'when security_orchestration_policies is available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        it 'updates spp_repository_pipeline_access' do
          expect { subject }.to change { project.reload.spp_repository_pipeline_access }.from(true).to(false)
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['spp_repository_pipeline_access']).to eq(project_params[:spp_repository_pipeline_access])
        end
      end

      context 'when security_orchestration_policies is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'does not update spp_repository_pipeline_access' do
          expect { subject }.to not_change { project.reload.spp_repository_pipeline_access }.from(true)
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['spp_repository_pipeline_access']).to be_nil
        end
      end
    end

    describe 'updating of security_policy_pipeline_must_succeed' do
      let(:project_params) { { security_policy_pipeline_must_succeed: true } }

      context 'when security_orchestration_policies is available and feature flag is enabled' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        it 'updates security_policy_pipeline_must_succeed' do
          expect { subject }.to change { project.reload.security_policy_pipeline_must_succeed }.from(false).to(true)
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['security_policy_pipeline_must_succeed']).to be(true)
        end
      end

      context 'when security_orchestration_policies is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'does not update security_policy_pipeline_must_succeed' do
          expect { subject }.to not_change { project.reload.security_policy_pipeline_must_succeed }.from(false)
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['security_policy_pipeline_must_succeed']).to be_nil
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
          stub_feature_flags(security_policy_pipeline_check: false)
        end

        it 'does not update security_policy_pipeline_must_succeed' do
          expect { subject }.to not_change { project.reload.security_policy_pipeline_must_succeed }.from(false)
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when setting auto_duo_code_review_enabled' do
      let(:project_params) { { auto_duo_code_review_enabled: true } }

      context 'when project has auto_duo_code_review_settings available' do
        before do
          stub_licensed_features(review_merge_request: true)
          project.project_setting.update!(duo_features_enabled: true)

          allow_next_found_instance_of(Project) do |project|
            allow(project).to receive(:auto_duo_code_review_settings_available?).and_return(true)
          end
        end

        it 'updates the value' do
          expect { subject }.to change { project.reload.auto_duo_code_review_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['auto_duo_code_review_enabled']).to be true
        end
      end

      context 'when project does not have auto_duo_code_review_settings available' do
        before do
          allow_next_found_instance_of(Project) do |project|
            allow(project).to receive(:auto_duo_code_review_settings_available?).and_return(false)
          end
        end

        it 'does not update the value' do
          expect { subject }.not_to change { project.reload.auto_duo_code_review_enabled }
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['auto_duo_code_review_enabled']).to be_nil
        end
      end
    end

    context 'when setting reviewer_assignment_strategy' do
      let(:project_params) { { reviewer_assignment_strategy: 'code_owners' } }

      context 'when the licensed feature is available' do
        before do
          stub_licensed_features(code_owners: true)
        end

        it 'updates the value and exposes it' do
          expect { subject }.to change { project.reload.reviewer_assignment_strategy }.to('code_owners')

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['reviewer_assignment_strategy']).to eq('code_owners')
        end

        it 'rejects an invalid strategy' do
          put api("/projects/#{project.id}", user), params: { reviewer_assignment_strategy: 'bogus' }

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when the licensed feature is unavailable' do
        before do
          stub_licensed_features(code_owners: false)
        end

        it 'does not update the value or expose it' do
          expect { subject }.not_to change { project.reload.reviewer_assignment_strategy }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key('reviewer_assignment_strategy')
        end
      end
    end

    context 'when setting duo_remote_flows_enabled' do
      let(:project_params) { { duo_remote_flows_enabled: false } }

      context 'when licence is available' do
        before do
          stub_licensed_features(ai_workflows: true)
        end

        it 'updates the value' do
          expect { subject }.to change { project.reload.duo_remote_flows_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_remote_flows_enabled']).to be false
        end
      end

      context 'when licence is not available' do
        it 'does not update the value' do
          expect { subject }.not_to change { project.reload.duo_remote_flows_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_remote_flows_enabled']).to be_nil
        end
      end
    end

    context 'when setting duo_sast_fp_detection_enabled' do
      let(:project_params) { { duo_sast_fp_detection_enabled: true } }

      context 'when licence is available' do
        before do
          stub_licensed_features(ai_features: true)
        end

        it 'updates the value' do
          expect { subject }.to change { project.reload.duo_sast_fp_detection_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_sast_fp_detection_enabled']).to be true
        end
      end

      context 'when licence is not available' do
        it 'does not update the value and does not expose it in response' do
          expect { subject }.not_to change { project.reload.duo_sast_fp_detection_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_sast_fp_detection_enabled']).to be_nil
        end
      end
    end

    context 'when setting duo_secret_detection_fp_enabled' do
      let(:project_params) { { duo_secret_detection_fp_enabled: true } }

      context 'when licence is available and feature flag is enabled' do
        before do
          stub_licensed_features(ai_features: true)
          stub_feature_flags(duo_secret_detection_false_positive: true)
          project.update!(duo_secret_detection_fp_enabled: false)
        end

        it 'updates the value' do
          expect { subject }.to change { project.reload.duo_secret_detection_fp_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_secret_detection_fp_enabled']).to be true
        end
      end

      context 'when licence is available but feature flag is disabled' do
        before do
          stub_licensed_features(ai_features: true)
          stub_feature_flags(duo_secret_detection_false_positive: false)
        end

        it 'does not update the value and does not expose it in response' do
          expect { subject }.not_to change { project.reload.duo_secret_detection_fp_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_secret_detection_fp_enabled']).to be_nil
        end
      end

      context 'when licence is not available' do
        before do
          stub_feature_flags(duo_secret_detection_false_positive: true)
        end

        it 'does not update the value and does not expose it in response' do
          expect { subject }.not_to change { project.reload.duo_secret_detection_fp_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_secret_detection_fp_enabled']).to be_nil
        end
      end
    end

    context 'when setting duo_dependency_bump_breaking_changes_enabled' do
      let(:project_params) { { duo_dependency_bump_breaking_changes_enabled: true } }

      context 'when licence is available and feature flag is enabled' do
        before do
          stub_licensed_features(ai_features: true)
          stub_feature_flags(enable_dependency_bump_breaking_changes: true)
          project.update!(duo_dependency_bump_breaking_changes_enabled: false)
        end

        it 'updates the value' do
          expect { subject }.to change { project.reload.duo_dependency_bump_breaking_changes_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_dependency_bump_breaking_changes_enabled']).to be true
        end
      end

      context 'when licence is available but feature flag is disabled' do
        before do
          stub_licensed_features(ai_features: true)
          stub_feature_flags(enable_dependency_bump_breaking_changes: false)
        end

        it 'does not update the value and does not expose it in response' do
          expect { subject }.not_to change { project.reload.duo_dependency_bump_breaking_changes_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_dependency_bump_breaking_changes_enabled']).to be_nil
        end
      end

      context 'when licence is not available' do
        before do
          stub_feature_flags(enable_dependency_bump_breaking_changes: true)
        end

        it 'does not update the value and does not expose it in response' do
          expect { subject }.not_to change { project.reload.duo_dependency_bump_breaking_changes_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_dependency_bump_breaking_changes_enabled']).to be_nil
        end
      end
    end

    context 'when setting duo_sast_vr_workflow_enabled' do
      let(:project_params) { { duo_sast_vr_workflow_enabled: true } }

      context 'when licence is available' do
        before do
          stub_licensed_features(ai_features: true)
        end

        it 'updates the value' do
          expect { subject }.to change { project.reload.duo_sast_vr_workflow_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_sast_vr_workflow_enabled']).to be true
        end
      end

      context 'when licence is not available' do
        it 'does not update the value and does not expose it in response' do
          expect { subject }.not_to change { project.reload.duo_sast_vr_workflow_enabled }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_sast_vr_workflow_enabled']).to be_nil
        end
      end
    end

    context 'when the user is a security manager without admin_project' do
      let_it_be_with_reload(:project) { create(:project) }
      let_it_be(:security_manager) { create(:user, security_manager_of: project) }

      subject { put api("/projects/#{project.id}", security_manager), params: project_params }

      before do
        stub_licensed_features(ai_features: true)
        project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
      end

      context 'with only duo_sast_vr_workflow_enabled' do
        let(:project_params) { { duo_sast_vr_workflow_enabled: true } }

        it 'updates the value' do
          expect { subject }.to change { project.reload.duo_sast_vr_workflow_enabled }.from(false).to(true)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with non-sast_vr attributes that have no per-attribute authorization' do
        let(:project_params) { { description: 'new description', duo_sast_vr_workflow_enabled: true } }

        it 'updates only duo_sast_vr_workflow_enabled and silently drops the rest' do
          original_description = project.description

          expect { subject }.to change { project.reload.duo_sast_vr_workflow_enabled }.from(false).to(true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload.description).to eq(original_description)
        end
      end

      context 'with only duo_secret_detection_fp_enabled' do
        let(:project_params) { { duo_secret_detection_fp_enabled: true } }

        before do
          stub_feature_flags(duo_secret_detection_false_positive: true)
          project.project_setting.update!(duo_secret_detection_fp_enabled: false)
        end

        it 'updates the value' do
          expect { subject }.to change { project.reload.duo_secret_detection_fp_enabled }.from(false).to(true)

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when update_false_positive_detection_setting_permission FF is off' do
          before do
            stub_feature_flags(update_false_positive_detection_setting_permission: false)
          end

          it 'silently drops the attribute' do
            expect { subject }.not_to change { project.reload.duo_secret_detection_fp_enabled }

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end

      context 'when all sec AI workflow permission FFs are off' do
        let(:project_params) { { duo_sast_vr_workflow_enabled: true } }

        before do
          stub_feature_flags(
            update_sast_vr_setting_permission: false,
            update_false_positive_detection_setting_permission: false
          )
        end

        it 'returns 403' do
          expect { subject }.not_to change { project.reload.duo_sast_vr_workflow_enabled }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when the user has neither admin_project nor the sast_vr ability' do
      let_it_be_with_reload(:project) { create(:project) }
      let_it_be(:developer) { create(:user, developer_of: project) }

      let(:project_params) { { duo_sast_vr_workflow_enabled: true } }

      subject { put api("/projects/#{project.id}", developer), params: project_params }

      before do
        stub_licensed_features(ai_features: true)
        project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
      end

      it 'returns 403' do
        expect { subject }.not_to change { project.reload.duo_sast_vr_workflow_enabled }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when updating merge_request_title_regex' do
      let(:project_params) { { merge_request_title_regex: '/aaa/', merge_request_title_regex_description: 'Description of regex' } }

      context 'when merge_request_title_regex is available' do
        before do
          stub_licensed_features(merge_request_title_regex_check: true)
        end

        it 'updates the merge_request_title_regex and description' do
          project.update!(merge_request_title_regex: nil)

          expect { subject }
            .to change { [project.reload.merge_request_title_regex, project.merge_request_title_regex_description] }
            .from([nil, nil])
            .to(['/aaa/', 'Description of regex'])

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_request_title_regex']).to eq('/aaa/')
          expect(json_response['merge_request_title_regex_description']).to eq('Description of regex')
        end
      end

      context 'when merge_request_title_regex is not available' do
        before do
          stub_licensed_features(merge_request_title_regex_check: false)
        end

        it 'does not update the merge_request_title_regex and description' do
          project.update!(merge_request_title_regex: nil)

          expect { subject }.to not_change { project.reload.merge_request_title_regex }
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_request_title_regex']).to be_nil
          expect(json_response['merge_request_title_regex_description']).to be_nil
        end
      end
    end

    context 'updating web_based_commit_signing_enabled' do
      using RSpec::Parameterized::TableSyntax

      let(:project_params) { { web_based_commit_signing_enabled: true } }

      shared_examples_for 'does not update the value' do
        it { expect { subject }.not_to change { project.reload.web_based_commit_signing_enabled }.from(false) }
      end

      context 'when authenticated as maintainer' do
        before do
          project.add_maintainer(user)
        end

        context 'and the feature is not available' do
          it 'does not render the value' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.keys).not_to include('web_based_commit_signing_enabled')
          end

          it_behaves_like 'does not update the value'
        end

        context 'and the feature is available' do
          before do
            stub_saas_features(repositories_web_based_commit_signing: true)
          end

          context 'and the feature is enabled' do
            it 'updates the attribute as expected' do
              expect { subject }.to change { project.reload.web_based_commit_signing_enabled }.from(false).to(true)
              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response['web_based_commit_signing_enabled']).to be(true)
            end
          end
        end
      end
    end
  end

  describe 'DELETE /projects/:id' do
    let(:group) { create(:group, owners: user) }
    let(:project) { create(:project, group: group) }
    let(:params) { {} }

    context 'when attempting to delete security policy project' do
      before do
        stub_licensed_features(security_orchestration_policies: true)

        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
      end

      it 'returns error' do
        delete api("/projects/#{project.id}", user)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response["message"]).to eq('Project cannot be deleted because it is linked as a security policy project')
      end
    end
  end

  describe 'POST /projects/:id/fork' do
    subject(:fork_call) { post api("/projects/#{group_project.id}/fork", user), params: { namespace: target_namespace.id } }

    let!(:target_namespace) do
      create(:group, owners: user)
    end

    let!(:group_project) { create(:project, namespace: group) }
    let(:group) { create(:group) }

    before do
      group.add_reporter(user)
    end

    context 'when project namespace has prohibit_outer_forks enabled' do
      let(:group) do
        create(:saml_provider, :enforced_group_managed_accounts, prohibited_outer_forks: true).group
      end

      let(:user) do
        create(:user, managing_group: group).tap do |u|
          create(:group_saml_identity, user: u, saml_provider: group.saml_provider)
        end
      end

      before do
        stub_licensed_features(group_saml: true, group_forking_protection: true)
      end

      context 'and target namespace is outer' do
        it 'renders 404' do
          expect { fork_call }.not_to change { ::Project.count }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq "404 Target Namespace Not Found"
        end
      end

      context 'and target namespace is inner to project namespace' do
        let!(:target_namespace) { create(:group, parent: group) }

        it 'forks the project' do
          target_namespace.add_owner(user)

          expect { fork_call }.to change { ::Project.count }.by(1)
        end
      end
    end
  end

  describe 'POST /projects/:id/fork/:forked_from_id' do
    let_it_be_with_reload(:source_group) { create(:group) }
    let_it_be_with_reload(:project_fork_source) { create(:project, :public, namespace: source_group) }

    let(:path) { "/projects/#{project_fork_target.id}/fork/#{project_fork_source.id}" }

    before do
      project_fork_target.add_owner(user)
      stub_licensed_features(group_forking_protection: true)
    end

    shared_examples 'forks the project' do
      it 'forks the project' do
        post api(path, user)
        expect(response).to have_gitlab_http_status(:created)
        expect(project_fork_target.forked_from_project.id).to eq(project_fork_source.id)
        expect(project_fork_target.fork_network_member).to be_present
      end
    end

    shared_context 'same namespace' do
      let_it_be_with_reload(:target_namespace) do
        create(:group, parent: source_group, project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS)
      end

      let_it_be_with_reload(:project_fork_target) { create(:project, :public, namespace: target_namespace) }
      before do
        source_group.add_maintainer(user)
      end
    end

    shared_context 'different namespace' do
      let_it_be_with_reload(:target_namespace) do
        create(:group, project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS)
      end

      let_it_be_with_reload(:project_fork_target) { create(:project, :public, namespace: target_namespace) }
      before do
        target_namespace.add_maintainer(user)
      end
    end

    context 'when project namespace has prevent_forking_outside_group enabled' do
      before do
        source_group.namespace_settings.update!(prevent_forking_outside_group: true)
      end

      context 'and target namespace is inside the source group' do
        include_context 'same namespace'
        before do
          target_namespace.add_maintainer(user)
        end

        it_behaves_like 'forks the project'
      end

      context "and target namespace is outside the source group" do
        include_context 'different namespace'

        before do
          target_namespace.add_maintainer(user)
        end

        it 'renders 401' do
          post api(path, user)
          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(json_response['message']).to eq "401 Unauthorized - Target Namespace"
        end
      end
    end

    context 'when project namespace has prevent_forking_outside_group disabled' do
      before do
        source_group.namespace_settings.update!(prevent_forking_outside_group: false)
      end

      context 'and target namespace is inside the source group' do
        include_context 'same namespace'
        it_behaves_like 'forks the project'
      end

      context 'and target namespace is outside the source group' do
        include_context 'different namespace'
        it_behaves_like 'forks the project'
      end
    end
  end

  describe 'POST /projects/:id/import_project_members/:project_id' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:project) { create(:project) }
    let_it_be(:target_project) { create(:project, group: group) }

    before_all do
      project.add_maintainer(another_user)
      target_project.add_maintainer(another_user)
    end

    context 'when the target project has locked their membership' do
      context 'via the parent group' do
        before do
          group.update!(membership_lock: true)
        end

        it 'returns 403' do
          expect do
            post api("/projects/#{target_project.id}/import_project_members/#{project.id}", another_user)
          end.not_to change { target_project.members.count }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Forbidden')
          expect(json_response['reason']).to eq('import_project_team_forbidden_error')
        end
      end

      context 'via LDAP' do
        before do
          stub_application_setting(lock_memberships_to_ldap: true)
        end

        it 'returns 403' do
          expect do
            post api("/projects/#{target_project.id}/import_project_members/#{project.id}", another_user)
          end.not_to change { target_project.members.count }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Forbidden')
          expect(json_response['reason']).to eq('import_project_team_forbidden_error')
        end
      end
    end

    context 'block seat overages', :saas do
      let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group, seats: 1) }

      context 'when block seat overages is enabled' do
        before do
          group.namespace_settings.update!(seat_control: :block_overages)
        end

        it 'rejects adding more members than there are available seats' do
          post api("/projects/#{target_project.id}/import_project_members/#{project.id}", another_user)

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to eq({
            'message' => 'There are not enough available seats to invite this many users. ' \
                         'Ask a user with the Owner role to purchase more seats.',
            'reason' => 'seat_limit_exceeded_error'
          })
        end
      end

      context 'when block seat overages is disabled' do
        before do
          group.namespace_settings.update!(seat_control: :off)
        end

        it 'accepts adding more members than there are available seats' do
          post api("/projects/#{target_project.id}/import_project_members/#{project.id}", another_user)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to eq({ 'status' => 'success' })
        end
      end
    end
  end

  describe 'POST /projects/:id/share', :saas do
    let_it_be_with_reload(:group) { create(:group, :private) }
    let_it_be(:project) { create(:project) }
    let_it_be(:member_role) { create(:member_role, namespace: project.namespace, base_access_level: Gitlab::Access::DEVELOPER) }
    let(:path) { "/projects/#{project.id}/share" }

    let(:params) do
      { group_id: group.id, group_access: member_role.base_access_level, member_role_id: member_role.id }
    end

    subject(:request) { post api(path, user), params: params }

    before do
      group.add_developer(user)
      project.add_owner(user)
    end

    context 'feature is available' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'shares the project with the group with member role' do
        expect { request }.to change { ProjectGroupLink.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['member_role_id']).to eq(member_role.id)
      end

      context 'but assign_custom_roles_to_project_links_saas feature flag is disabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_project_links_saas: false)
        end

        it 'shares the project with the group without member role' do
          expect { request }.to change { ProjectGroupLink.count }.by(1)
          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['member_role_id']).to be_nil
        end
      end
    end

    context 'feature is not available' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'shares the project with the group without member role' do
        expect { request }.to change { ProjectGroupLink.count }.by(1)
        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['member_role_id']).to be_nil
      end
    end
  end

  describe 'POST /projects/:id/archive' do
    let(:path) { "/projects/#{project.id}/archive" }

    context 'when project archiving fails' do
      it 'does not log an audit event' do
        expect { post api(path, another_user) }.not_to change { AuditEventReader.count }
      end
    end

    context 'when project archiving succeeds' do
      it 'logs an audit event' do
        expect { post api(path, user) }.to change { AuditEventReader.count }.by(1)
      end
    end
  end

  describe 'POST /projects/:id/unarchive' do
    let(:path) { "/projects/#{project.id}/unarchive" }

    before do
      project.project_namespace.archive!
    end

    context 'when project unarchiving fails' do
      it 'does not log an audit event' do
        expect { post api(path, another_user) }.not_to change { AuditEventReader.count }
      end
    end

    context 'when project unarchiving succeeds' do
      it 'logs an audit event' do
        expect { post api(path, user) }.to change { AuditEventReader.count }.by(1)
      end
    end
  end
end
