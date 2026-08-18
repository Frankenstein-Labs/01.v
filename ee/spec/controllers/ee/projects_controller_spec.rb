# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsController, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let_it_be_with_reload(:project) { create(:project, namespace: group) }

  let_it_be(:public_project) { create(:project, :public, :repository, namespace: group) }

  # rubocop:disable RSpec/BeforeAllRoleAssignment -- sign_in requires before, not before_all
  before do
    project.add_maintainer(user)
    sign_in(user)
  end
  # rubocop:enable RSpec/BeforeAllRoleAssignment

  shared_examples 'audit events with event type' do
    it 'logs the audit event' do
      # Stub .audit here so that only relevant audit events are received below
      allow(::Gitlab::Audit::Auditor).to receive(:audit)

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: audit_name)
      ).and_call_original

      expect { request }.to change { AuditEventReader.count }.by(1)
      expect(AuditEventReader.last.details[:custom_message]).to eq(custom_message)
    end
  end

  describe 'GET new' do
    let_it_be(:params) { { namespace_id: user.namespace.id } }

    context 'when user does not have `:create_projects` permissions' do
      before do
        allow(controller).to receive(:can?).with(user, :create_projects, user.namespace).and_return(false)
      end

      it 'returns a 404' do
        get :new, params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user does have `:create_projects` permissions' do
      before do
        allow(controller).to receive(:can?).with(user, :create_projects, user.namespace).and_return(true)
      end

      it 'renders `new` template' do
        get :new, params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET edit' do
    render_views

    subject(:get_edit) { get :edit, params: { namespace_id: project.namespace.path, id: project.path } }

    it_behaves_like 'pushes saas feature', :group_project_permanent_deletion_confirmation
    it_behaves_like 'pushes dedicated feature', :group_project_permanent_deletion_confirmation

    it 'pushes :secrets_manager_paid_experience with the root ancestor as actor',
      feature_category: :secrets_management do
      allow(controller).to receive(:push_frontend_feature_flag)

      get_edit

      expect(controller).to have_received(:push_frontend_feature_flag)
        .with(:secrets_manager_paid_experience, group)
    end

    it 'pushes :agent_artifacts_page with the root ancestor as actor',
      feature_category: :compliance_management do
      allow(controller).to receive(:push_frontend_feature_flag)

      get_edit

      expect(controller).to have_received(:push_frontend_feature_flag)
        .with(:agent_artifacts_page, group, type: :beta)
    end
  end

  describe 'GET show', feature_category: :groups_and_projects do
    render_views

    subject { get :show, params: { namespace_id: public_project.namespace.path, id: public_project.path } }

    context 'additional repo storage by namespace', :saas, feature_category: :consumables_cost_management do
      before do
        stub_saas_features(namespaces_storage_limit: true)
        stub_feature_flags(namespace_storage_limit: false)

        allow_next_instance_of(ProjectPresenter) do |presenter|
          allow(presenter).to receive(:repository_size_excess).and_return(1)
          allow(presenter.namespace).to receive(:additional_purchased_storage_size).and_return(1)
        end

        public_project.namespace.add_owner(user)
      end

      context 'when automatic_purchased_storage_allocation setting is enabled' do
        before do
          stub_ee_application_setting(automatic_purchased_storage_allocation: true)
        end

        context 'when usage_ratio < 0.75' do
          before do
            allow_next_instance_of(Namespaces::Storage::RepositoryLimit::Enforcement) do |root_storage|
              allow(root_storage).to receive(:usage_ratio).and_return(0.5)
              allow(root_storage).to receive(:above_size_limit?).and_return(true)
            end
          end

          it 'does not include the CTA for additional purchased storage' do
            subject

            expect(response.body).not_to match(/purchase more storage/)
          end
        end

        context 'when usage_ratio >= 0.75' do
          before do
            allow_next_instance_of(Namespaces::Storage::RepositoryLimit::Enforcement) do |root_storage|
              allow(root_storage).to receive(:usage_ratio).and_return(0.75)
              allow(root_storage).to receive(:above_size_limit?).and_return(true)
            end
          end

          it 'includes the CTA for additional purchased storage' do
            subject

            expect(response.body).to match(/purchase more storage/)
          end
        end
      end

      context 'when automatic_purchased_storage_allocation setting is disabled' do
        before do
          stub_ee_application_setting(automatic_purchased_storage_allocation: false)
        end

        it 'does not include the CTA for additional purchased storage' do
          subject

          expect(response.body).not_to match(/purchase more storage/)
        end

        context 'for namespace storage limit' do
          let(:namespace) { public_project.namespace }

          it_behaves_like 'namespace storage limit alert'
        end
      end
    end

    context 'with automatic_purchased_storage_allocation set to true', feature_category: :consumables_cost_management do
      before do
        stub_ee_application_setting(automatic_purchased_storage_allocation: true)
      end

      it 'does not show over size limit warning when above_size_limit' do
        allow_next_instance_of(Gitlab::RepositorySizeChecker) do |checker|
          expect(checker).to receive(:above_size_limit?).and_return(true)
        end

        subject

        expect(response.body).not_to match(/The size of this repository.+exceeds the limit/)
      end
    end

    context 'with automatic_purchased_storage_allocation set to false', feature_category: :consumables_cost_management do
      before do
        stub_ee_application_setting(automatic_purchased_storage_allocation: false)
      end

      it 'shows the over size limit warning message if above_size_limit' do
        allow_next_instance_of(Gitlab::RepositorySizeChecker) do |checker|
          expect(checker).to receive(:above_size_limit?).and_return(true)
        end

        subject

        expect(response.body).to match(/The size of this repository.+exceeds the limit/)
      end

      it 'does not show an over size warning if not above_size_limit' do
        subject

        expect(response.body).not_to match(/The size of this repository.+exceeds the limit/)
      end
    end

    it_behaves_like 'pushes saas feature', :group_project_permanent_deletion_confirmation
    it_behaves_like 'pushes dedicated feature', :group_project_permanent_deletion_confirmation
  end

  describe 'POST create', feature_category: :groups_and_projects do
    let!(:params) do
      {
        path: 'foo',
        description: 'bar',
        import_url: project.http_url_to_repo,
        namespace_id: user.namespace.id,
        visibility_level: Gitlab::VisibilityLevel::PUBLIC,
        mirror: true,
        mirror_trigger_builds: true
      }
    end

    context 'with licensed repository mirrors' do
      before do
        stub_licensed_features(repository_mirrors: true)
        stub_application_setting(import_sources: ['git'])
      end

      it 'has mirror enabled in new project' do
        post :create, params: { project: params }

        created_project = Project.find_by_path('foo')
        expect(created_project.reload.mirror).to be true
        expect(created_project.reload.mirror_user.id).to eq(user.id)
      end
    end

    context 'with unlicensed repository mirrors' do
      before do
        stub_licensed_features(repository_mirrors: false)
        stub_application_setting(import_sources: ['git'])
      end

      it 'has mirror disabled in new project' do
        post :create, params: { project: params }

        created_project = Project.find_by_path('foo')
        expect(created_project.reload.mirror).to be false
        expect(created_project.reload.mirror_user).to be_nil
      end
    end

    context 'built in project templates' do
      let(:templates_params) do
        {
          path: 'foo',
          description: 'bar',
          namespace_id: user.namespace.id,
          template_name: 'rails'
        }
      end

      it 'creates one audit event' do
        expect { post :create, params: { project: templates_params } }.to change { AuditEventReader.count }.by(1)
      end
    end

    context 'custom project templates' do
      let(:project_template) { create(:project, :repository, :public, :metrics_dashboard_enabled, namespace: group) }
      let(:templates_params) do
        {
          path: 'foo',
          description: 'bar',
          namespace_id: user.namespace.id,
          use_custom_template: true,
          template_name: project_template.name
        }
      end

      context 'when licensed' do
        before do
          stub_licensed_features(custom_project_templates: true)
          stub_ee_application_setting(custom_project_templates_group_id: group.id)
        end

        context 'object storage' do
          before do
            stub_uploads_object_storage(FileUploader)
            # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/474656
            allow(Gitlab::QueryLimiting).to receive(:threshold).and_return(215)
          end

          it 'creates the project from project template', :sidekiq_might_not_need_inline do
            post :create, params: { project: templates_params }

            created_project = Project.find_by_path('foo')
            expect(flash[:notice]).to eq "Project &#39;foo&#39; was successfully created."
            expect(created_project.repository.empty?).to be false
          end
        end
      end

      context 'when unlicensed' do
        render_views

        before do
          stub_licensed_features(custom_project_templates: false)
          project
          project_template
        end

        it 'does not create the project from project template' do
          expect_next_instance_of(Project) do |project|
            expect(project).not_to receive(:save)
          end

          post :create, params: { project: templates_params }

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to match(/Template name .* is unknown or invalid/)
        end
      end
    end
  end

  describe 'PUT #update', feature_category: :groups_and_projects do
    it 'updates Issuable Default Templates attributes' do
      params = {
        issues_template: 'You got issues?',
        merge_requests_template: 'I got tissues'
      }

      put :update, params: {
        namespace_id: project.namespace,
        id: project,
        project: params
      }
      project.reload

      expect(response).to have_gitlab_http_status(:found)
      params.each do |param, value|
        expect(project.public_send(param)).to eq(value)
      end
    end

    it 'updates merge_request_title_regex via project_setting_attributes' do
      put :update,
        params: {
          namespace_id: project.namespace,
          id: project,
          project: {
            project_setting_attributes: {
              merge_request_title_regex: 'aaa',
              merge_request_title_regex_description: 'Test description'
            }
          }
        }

      project.reload

      expect(project.merge_request_title_regex).to eq('aaa')
      expect(project.merge_request_title_regex_description).to eq('Test description')
    end

    it 'updates cve_id_request_enabled' do
      project.project_setting.cve_id_request_enabled = false
      project.project_setting.save!

      params = {
        project_setting_attributes: {
          cve_id_request_enabled: true
        }
      }
      put :update,
        params: {
          namespace_id: project.namespace,
          id: project,
          project: params
        }
      project.reload

      expect(project.project_setting.cve_id_request_enabled).to be(true)
    end

    context 'when enabling duo features' do
      let(:params) { { project_setting_attributes: { duo_features_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      it 'updates duo_features_enabled' do
        project.project_setting.duo_features_enabled = false
        project.project_setting.save!

        request

        expect(project.reload.project_setting.duo_features_enabled).to be(true)
      end

      context 'when duo features are locked by the ancestor' do
        before do
          project.project_setting.duo_features_enabled = false
          project.project_setting.save!

          project.namespace.namespace_settings.lock_duo_features_enabled = true
          project.namespace.namespace_settings.duo_features_enabled = false
          project.namespace.namespace_settings.save!
        end

        it 'does not update duo feature' do
          expect { request }.not_to change { project.reload.project_setting.duo_features_enabled }.from(false)
        end

        context 'with more params passed' do
          let(:params) do
            { project_setting_attributes: { duo_features_enabled: true }, description: 'Settings test' }
          end

          it 'does not update duo feature, but updates other attributes' do
            expect { request }.not_to change { project.reload.project_setting.duo_features_enabled }.from(false)
            expect(project.description).to eq('Settings test')
          end
        end
      end
    end

    context 'when merge_pipelines_enabled param is specified' do
      let(:params) { { merge_pipelines_enabled: true } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      context 'when feature is available through license' do
        before do
          stub_licensed_features(merge_pipelines: true)
        end

        it 'updates the attribute' do
          request

          expect(project.reload.merge_pipelines_enabled).to be_truthy
        end
      end

      context 'when feature is available through usage ping features' do
        before do
          stub_usage_ping_features(true)
        end

        it 'updates the attribute' do
          request

          expect(project.reload.merge_pipelines_enabled).to be_truthy
        end
      end

      context 'when usage ping is disabled on free license' do
        before do
          stub_usage_ping_features(false)
        end

        it 'does not update the attribute' do
          request

          expect(project.reload.merge_pipelines_enabled).to be_falsy
        end
      end

      context 'when license is not sufficient' do
        before do
          stub_licensed_features(merge_pipelines: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.reload.merge_pipelines_enabled).to be_falsy
        end
      end
    end

    context 'when only_allow_merge_if_all_status_checks_passed param is specified' do
      let(:params) { { project_setting_attributes: { only_allow_merge_if_all_status_checks_passed: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      it_behaves_like 'update only allow merge if all status checks passed'
    end

    context 'when merge_trains_enabled param is specified' do
      let(:params) { { merge_trains_enabled: true } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      before do
        stub_licensed_features(merge_pipelines: true, merge_trains: true)
      end

      it 'updates the attribute' do
        request

        expect(project.merge_trains_enabled).to be_truthy
      end

      context 'when license is not sufficient' do
        before do
          stub_licensed_features(merge_trains: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.merge_trains_enabled).to be_falsy
        end
      end
    end

    context 'when merge_trains_skip_train_allowed param is specified' do
      let(:params) { { merge_trains_skip_train_allowed: true } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      before do
        stub_licensed_features(merge_pipelines: true, merge_trains: true)
      end

      it 'updates the attribute' do
        request

        expect(project.merge_trains_skip_train_allowed).to be_truthy
      end

      context 'when license is not sufficient' do
        before do
          stub_licensed_features(merge_trains: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.merge_trains_skip_train_allowed).to be_falsy
        end
      end
    end

    context 'when auto_rollback_enabled param is specified' do
      let(:params) { { auto_rollback_enabled: true } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      before do
        stub_licensed_features(auto_rollback: true)
      end

      it 'updates the attribute' do
        request

        expect(project.reload.auto_rollback_enabled).to be_truthy
      end

      context 'when license is not sufficient' do
        before do
          stub_licensed_features(auto_rollback: false)
        end

        it 'does not update the attribute' do
          request

          expect(project.reload.auto_rollback_enabled).to be_falsy
        end
      end
    end

    context 'repository mirrors' do
      let(:params) do
        {
          mirror: true,
          mirror_trigger_builds: true,
          import_url: 'https://example.com'
        }
      end

      context 'when licensed' do
        before do
          stub_licensed_features(repository_mirrors: true)
        end

        it 'updates repository mirror attributes' do
          expect(UpdateAllMirrorsWorker).to receive(:perform_async)

          put :update,
            params: {
              namespace_id: project.namespace,
              id: project,
              project: params
            }
          project.reload

          expect(project.mirror).to be(true)
          expect(project.mirror_trigger_builds).to be(true)
          expect(project.mirror_user).to eq(user)
          expect(project.unsafe_import_url).to eq('https://example.com')
        end

        it 'ignores mirror_user_id' do
          other_user = create(:user)

          put :update,
            params: {
              namespace_id: project.namespace,
              id: project,
              project: params.merge(mirror_user_id: other_user.id)
            }
          project.reload

          expect(project.mirror_user).to eq(user)
        end
      end

      context 'when unlicensed' do
        before do
          stub_licensed_features(repository_mirrors: false)
        end

        it 'does not update repository mirror attributes' do
          params.each do |param, _value|
            expect do
              put :update,
                params: {
                  namespace_id: project.namespace,
                  id: project,
                  project: params
                }
              project.reload
            end.not_to change(project, param)
          end
        end
      end
    end

    context 'merge request approvers settings' do
      shared_examples 'merge request approvers rules' do
        using RSpec::Parameterized::TableSyntax

        where(:can_modify, :param_value, :final_value) do
          true  | true  | true
          true  | false | false
          false | true  | nil
          false | false | nil
        end

        with_them do
          before do
            allow(controller).to receive(:can?).and_call_original
            allow(controller).to receive(:can?).with(user, rule_name, project).and_return(can_modify)
          end

          it 'updates project if needed' do
            put :update,
              params: {
                namespace_id: project.namespace,
                id: project,
                project: { setting => param_value }
              }

            project.reload

            expect(project[setting]).to eq(final_value.nil? ? setting_default_value : final_value)
          end
        end
      end

      describe ':disable_overriding_approvers_per_merge_request' do
        it_behaves_like 'merge request approvers rules' do
          let(:rule_name) { :modify_approvers_rules }
          let(:setting) { :disable_overriding_approvers_per_merge_request }
          let(:setting_default_value) { nil }
        end
      end

      describe ':merge_requests_author_approval' do
        it_behaves_like 'merge request approvers rules' do
          let(:rule_name) { :modify_merge_request_author_setting }
          let(:setting) { :merge_requests_author_approval }
          let(:setting_default_value) { false }
        end
      end

      describe ':merge_requests_disable_committers_approval' do
        it_behaves_like 'merge request approvers rules' do
          let(:rule_name) { :modify_merge_request_committer_setting }
          let(:setting) { :merge_requests_disable_committers_approval }
          let(:setting_default_value) { nil }
        end
      end
    end

    context 'analytics dashboards pointer setting' do
      let_it_be(:another_project) do
        create(:project, namespace: group, maintainers: user)
      end

      let(:params) do
        {
          id: project,
          namespace_id: project.namespace,
          project: {
            analytics_dashboards_pointer_attributes: { target_project_id: another_project.id }
          }
        }
      end

      context 'without correct license' do
        before do
          stub_licensed_features(project_level_analytics_dashboard: false)

          put :update, params: params
        end

        it 'ignores input' do
          expect(project.analytics_dashboards_configuration_project).to be_nil
        end
      end

      context 'with correct license' do
        before do
          stub_licensed_features(project_level_analytics_dashboard: true)

          put :update, params: params
        end

        it 'updates analytics dashboards configuration project' do
          expect(project.analytics_dashboards_configuration_project).to eq another_project
        end
      end
    end

    context 'when spp_repository_pipeline_access is specified' do
      subject(:request) { put :update, params: params }

      let(:params) do
        {
          id: project,
          namespace_id: project.namespace,
          project: {
            project_setting_attributes: {
              spp_repository_pipeline_access: false
            }
          }
        }
      end

      it 'does not update the setting' do
        expect { request }.not_to change { project.reload.project_setting.spp_repository_pipeline_access }.from(true)
      end

      context 'with licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        it 'sets spp_repository_pipeline_access' do
          expect { request }
            .to change { project.reload.project_setting.spp_repository_pipeline_access }.from(true).to(false)
        end
      end
    end

    context 'when pipeline_execution_policy_bot_access_enabled is specified' do
      subject(:request) { put :update, params: params }

      let(:params) do
        {
          id: project,
          namespace_id: project.namespace,
          project: {
            project_setting_attributes: {
              pipeline_execution_policy_bot_access_enabled: true,
              pipeline_execution_policy_bot_access_file_patterns: ['ci/**/*.yml']
            }
          }
        }
      end

      it 'does not update the setting without license' do
        expect { request }.not_to change { project.reload.project_setting.pipeline_execution_policy_bot_access_enabled }
      end

      context 'with licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        it 'sets pipeline_execution_policy_bot_access_enabled' do
          expect { request }
            .to change { project.reload.project_setting.pipeline_execution_policy_bot_access_enabled }.from(false).to(true)
        end

        it 'sets pipeline_execution_policy_bot_access_file_patterns' do
          expect { request }
            .to change { project.reload.project_setting.pipeline_execution_policy_bot_access_file_patterns }.from([]).to(['ci/**/*.yml'])
        end

        it 'sets pipeline_execution_policy_bot_access_group_id' do
          params[:project][:project_setting_attributes][:pipeline_execution_policy_bot_access_group_id] = group.id

          expect { request }
            .to change { project.reload.project_setting.pipeline_execution_policy_bot_access_group_id }.from(nil).to(group.id)
        end

        it 'rejects group outside project hierarchy' do
          external_group = create(:group)
          params[:project][:project_setting_attributes][:pipeline_execution_policy_bot_access_group_id] = external_group.id

          expect { request }
            .not_to change { project.reload.project_setting.pipeline_execution_policy_bot_access_group_id }
        end

        it 'clears pipeline_execution_policy_bot_access_file_patterns when the UI submits an empty value' do
          project.project_setting.update!(
            pipeline_execution_policy_bot_access_enabled: true,
            pipeline_execution_policy_bot_access_file_patterns: ['ci/**/*.yml']
          )
          params[:project][:project_setting_attributes].delete(:pipeline_execution_policy_bot_access_file_patterns)

          expect(::Security::PolicyAvailability).to receive(:available?).with(project, :security_orchestration_policies)
            .and_call_original

          expect { request }
            .to change { project.reload.project_setting.pipeline_execution_policy_bot_access_file_patterns }
            .from(['ci/**/*.yml']).to([])
        end

        context 'when enabled is false and patterns are omitted' do
          before do
            project.project_setting.update!(
              pipeline_execution_policy_bot_access_enabled: true,
              pipeline_execution_policy_bot_access_file_patterns: ['ci/**/*.yml']
            )
            params[:project][:project_setting_attributes][:pipeline_execution_policy_bot_access_enabled] = false
            params[:project][:project_setting_attributes].delete(:pipeline_execution_policy_bot_access_file_patterns)
          end

          it 'disables bot access' do
            expect { request }
              .to change { project.reload.project_setting.pipeline_execution_policy_bot_access_enabled }
              .to(false)
          end
        end
      end
    end

    context 'when duo_context_exclusion_settings are specified' do
      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      let(:exclusion_settings) { { exclusion_rules: ['*.log', 'node_modules/', 'tmp/'] } }
      let(:params) do
        {
          project_setting_attributes: {
            duo_context_exclusion_settings: exclusion_settings
          }
        }
      end

      context 'updating duo_context_exclusion_settings' do
        before do
          project.project_setting.update!(duo_context_exclusion_settings: { exclusion_rules: [] })
        end

        context 'with experiment features enabled' do
          before do
            project.root_ancestor.namespace_settings.update!(experiment_features_enabled: true)
            stub_application_setting(instance_level_ai_beta_features_enabled: false)
          end

          it 'updates duo_context_exclusion_settings' do
            expect { request }
              .to change { project.reload.project_setting.duo_context_exclusion_settings }
              .from({ "exclusion_rules" => [] })
              .to(exclusion_settings.stringify_keys)
          end
        end

        context 'with instance-level beta features enabled' do
          before do
            allow(project.root_ancestor).to receive(:experiment_features_enabled).and_return(false)
            stub_application_setting(instance_level_ai_beta_features_enabled: true)
          end

          it 'updates duo_context_exclusion_settings' do
            expect { request }
              .to change { project.reload.project_setting.duo_context_exclusion_settings }
              .from({ "exclusion_rules" => [] })
              .to(exclusion_settings.stringify_keys)
          end
        end

        context 'with existing exclusion settings' do
          let(:initial_settings) { { exclusion_rules: ['*.txt'] } }

          before do
            allow(project.root_ancestor).to receive(:experiment_features_enabled).and_return(true)
            project.project_setting.update!(duo_context_exclusion_settings: initial_settings)
          end

          it 'updates the existing settings' do
            expect { request }
              .to change { project.reload.project_setting.duo_context_exclusion_settings }
              .from(initial_settings.stringify_keys)
              .to(exclusion_settings.stringify_keys)
          end
        end

        context 'with empty exclusion rules' do
          # we can't use empty array due to strong params deep_munge
          let(:exclusion_settings) { { exclusion_rules: nil } }

          before do
            allow(project.root_ancestor).to receive(:experiment_features_enabled).and_return(true)
            project.project_setting.update!(duo_context_exclusion_settings: { exclusion_rules: ['*.log'] })
          end

          it 'clears the exclusion rules' do
            expect { request }
              .to change { project.reload.project_setting.duo_context_exclusion_settings }
              .to({})
          end
        end
      end
    end

    context 'when duo_remote_flows_enabled param is specified' do
      let(:params) { { project_setting_attributes: { duo_remote_flows_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      context 'without licensed AI workflows feature' do
        before do
          stub_licensed_features(ai_workflows: false)
        end

        it 'does not update the setting' do
          expect { request }.not_to change { project.reload.project_setting.duo_remote_flows_enabled }
        end
      end

      context 'with licensed AI workflows feature' do
        before do
          stub_licensed_features(ai_workflows: true)
          project.project_setting.update!(duo_remote_flows_enabled: false)
        end

        context 'without permissions' do
          before do
            allow(controller).to receive(:can?).with(user, :read_project, project).and_return(false)
          end

          it 'does not update the setting' do
            expect { request }.not_to change { project.reload.project_setting.duo_remote_flows_enabled }
          end
        end

        it 'updates duo_remote_flows_enabled' do
          expect { request }
            .to change { project.reload.project_setting.duo_remote_flows_enabled }
            .from(false).to(true)
        end
      end
    end

    context 'when duo_foundational_flows_enabled param is specified' do
      let(:params) { { project_setting_attributes: { duo_foundational_flows_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      context 'without licensed AI workflows feature' do
        before do
          stub_licensed_features(ai_workflows: false)
        end

        it 'does not update the setting' do
          expect { request }.not_to change { project.reload.project_setting.duo_foundational_flows_enabled }
        end
      end

      context 'with licensed AI workflows feature' do
        before do
          stub_licensed_features(ai_workflows: true)
          project.project_setting.update!(duo_foundational_flows_enabled: false)
        end

        context 'when duo_remote_flows_enabled is false' do
          before do
            project.project_setting.update!(duo_remote_flows_enabled: false)
          end

          it 'does not update the setting' do
            expect { request }.not_to change { project.reload.project_setting.duo_foundational_flows_enabled }
          end
        end

        context 'when duo_remote_flows_enabled is true' do
          before do
            project.project_setting.update!(duo_remote_flows_enabled: true)
          end

          context 'without permissions' do
            before do
              allow(controller).to receive(:can?).with(user, :read_project, project).and_return(false)
            end

            it 'does not update the setting' do
              expect { request }.not_to change { project.reload.project_setting.duo_foundational_flows_enabled }
            end
          end

          it 'updates duo_foundational_flows_enabled' do
            expect { request }
              .to change { project.reload.project_setting.duo_foundational_flows_enabled }
              .from(false).to(true)
          end
        end
      end
    end

    context 'when duo_sast_fp_detection_enabled param is specified' do
      let(:params) { { project_setting_attributes: { duo_sast_fp_detection_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      it 'updates duo_sast_fp_detection_enabled' do
        project.project_setting.duo_sast_fp_detection_enabled = false
        project.project_setting.save!

        request

        expect(project.reload.project_setting.duo_sast_fp_detection_enabled).to be(true)
      end
    end

    context 'when duo_vulnerability_context_analysis_enabled param is specified' do
      let(:params) { { project_setting_attributes: { duo_vulnerability_context_analysis_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      it 'updates duo_vulnerability_context_analysis_enabled' do
        project.project_setting.duo_vulnerability_context_analysis_enabled = false
        project.project_setting.save!

        request

        expect(project.reload.project_setting.duo_vulnerability_context_analysis_enabled).to be(true)
      end
    end

    context 'when duo_secret_detection_fp_enabled param is specified' do
      let(:params) { { project_setting_attributes: { duo_secret_detection_fp_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      context 'when feature flag is enabled' do
        before do
          stub_feature_flags(duo_secret_detection_false_positive: true)
        end

        it 'updates duo_secret_detection_fp_enabled' do
          project.project_setting.duo_secret_detection_fp_enabled = false
          project.project_setting.save!

          request

          expect(project.reload.project_setting.duo_secret_detection_fp_enabled).to be(true)
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(duo_secret_detection_false_positive: false)
          project.project_setting.duo_secret_detection_fp_enabled = false
          project.project_setting.save!
        end

        it 'does not update duo_secret_detection_fp_enabled' do
          expect { request }.not_to change { project.reload.project_setting.duo_secret_detection_fp_enabled }.from(false)
        end
      end
    end

    context 'when duo_dependency_bump_breaking_changes_enabled param is specified' do
      let(:params) { { project_setting_attributes: { duo_dependency_bump_breaking_changes_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      context 'when feature flag is enabled' do
        before do
          stub_feature_flags(enable_dependency_bump_breaking_changes: true)
        end

        it 'updates duo_dependency_bump_breaking_changes_enabled' do
          project.project_setting.duo_dependency_bump_breaking_changes_enabled = false
          project.project_setting.save!

          request

          expect(project.reload.project_setting.duo_dependency_bump_breaking_changes_enabled).to be(true)
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(enable_dependency_bump_breaking_changes: false)
          project.project_setting.duo_dependency_bump_breaking_changes_enabled = false
          project.project_setting.save!
        end

        it 'does not update duo_dependency_bump_breaking_changes_enabled' do
          expect { request }.not_to change {
            project.reload.project_setting.duo_dependency_bump_breaking_changes_enabled
          }.from(false)
        end
      end
    end

    context 'when duo_sast_vr_workflow_enabled param is specified' do
      let(:params) { { project_setting_attributes: { duo_sast_vr_workflow_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      it 'updates duo_sast_vr_workflow_enabled' do
        project.project_setting.duo_sast_vr_workflow_enabled = false
        project.project_setting.save!

        request

        expect(project.reload.project_setting.duo_sast_vr_workflow_enabled).to be(true)
      end
    end

    shared_examples 'security manager updating a sec AI workflow setting' do |setting_attribute, feature_flag|
      let_it_be(:security_manager) { create(:user, security_manager_of: project) }

      let(:params) { { project_setting_attributes: { setting_attribute => true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      before do
        sign_in(security_manager)
        project.project_setting.update!(setting_attribute => false)
      end

      it "updates #{setting_attribute}" do
        request

        expect(project.reload.project_setting.public_send(setting_attribute)).to be(true)
      end

      context "when #{feature_flag} FF is disabled" do
        before do
          stub_feature_flags(feature_flag => false)
        end

        it "does not update #{setting_attribute}" do
          request

          expect(project.reload.project_setting.public_send(setting_attribute)).to be(false)
        end
      end
    end

    context 'when the user is a security manager without update_duo_settings' do
      it_behaves_like 'security manager updating a sec AI workflow setting',
        :duo_sast_vr_workflow_enabled, :update_sast_vr_setting_permission

      it_behaves_like 'security manager updating a sec AI workflow setting',
        :duo_sast_fp_detection_enabled, :update_false_positive_detection_setting_permission

      it_behaves_like 'security manager updating a sec AI workflow setting',
        :duo_secret_detection_fp_enabled, :update_false_positive_detection_setting_permission

      context 'when updating duo_vulnerability_context_analysis_enabled' do
        let_it_be(:security_manager) { create(:user, security_manager_of: project) }

        let(:params) { { project_setting_attributes: { duo_vulnerability_context_analysis_enabled: true } } }

        let(:request) do
          put :update, params: { namespace_id: project.namespace, id: project, project: params }
        end

        before do
          sign_in(security_manager)
          project.project_setting.update!(duo_vulnerability_context_analysis_enabled: false)
        end

        it 'updates duo_vulnerability_context_analysis_enabled' do
          request

          expect(project.reload.project_setting.duo_vulnerability_context_analysis_enabled).to be(true)
        end
      end

      context 'when params include attributes outside the allowed list' do
        let_it_be(:security_manager) { create(:user, security_manager_of: project) }

        let(:request) do
          put :update, params: { namespace_id: project.namespace, id: project, project: params }
        end

        before do
          sign_in(security_manager)
          project.project_setting.update!(duo_sast_vr_workflow_enabled: false, cve_id_request_enabled: false)
        end

        it 'silently drops other project setting attributes', :aggregate_failures do
          params = { project_setting_attributes: { duo_sast_vr_workflow_enabled: true, cve_id_request_enabled: true } }

          put :update, params: { namespace_id: project.namespace, id: project, project: params }

          expect(project.reload.project_setting.duo_sast_vr_workflow_enabled).to be(true)
          expect(project.reload.project_setting.cve_id_request_enabled).to be(false)
        end

        it 'silently drops non-setting project attributes', :aggregate_failures do
          original_description = project.description
          params = { description: 'hacked', project_setting_attributes: { duo_sast_vr_workflow_enabled: true } }

          put :update, params: { namespace_id: project.namespace, id: project, project: params }

          expect(project.reload.project_setting.duo_sast_vr_workflow_enabled).to be(true)
          expect(project.reload.description).to eq(original_description)
        end
      end

      context 'when params include attributes merged outside the permitted list' do
        let_it_be(:security_manager) { create(:user, security_manager_of: project) }

        before do
          sign_in(security_manager)
          project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
        end

        it 'silently drops a smuggled import URL', :aggregate_failures do
          params = {
            import_url: 'https://example.com/attacker.git',
            project_setting_attributes: { duo_sast_vr_workflow_enabled: true }
          }

          put :update, params: { namespace_id: project.namespace, id: project, project: params }

          expect(project.reload.project_setting.duo_sast_vr_workflow_enabled).to be(true)
          expect(project.import_url).to be_nil, <<~MSG
            CVE-2026-16494 regression: CE `project_params` merges `import_url` in after `permit`,
            so the restricted path must build its params from the allowed list alone.
          MSG
          expect(project.import_type).to be_nil
        end
      end

      context 'when no sec AI workflow setting param is present' do
        let_it_be(:security_manager) { create(:user, security_manager_of: project) }

        before do
          sign_in(security_manager)
        end

        it 'denies access (CVE-2026-16494)', :aggregate_failures do
          put :update, params: {
            namespace_id: project.namespace,
            id: project,
            project: { import_url: 'https://example.com/attacker.git' }
          }

          expect(response).to have_gitlab_http_status(:not_found), <<~MSG
            CVE-2026-16494 regression: authorize_admin_project! is only skipped for a request that
            carries a sec AI workflow setting. Without one, the admin gate must still deny.
          MSG
          expect(project.reload.import_url).to be_nil
        end
      end
    end

    context 'when the user cannot administer the project' do
      %i[guest reporter developer].each do |role|
        context "as a #{role}" do
          let_it_be(:member) { create(:user) }

          before do
            project.add_member(member, role)
            sign_in(member)
          end

          it 'denies access and does not update the project (CVE-2026-16494)', :aggregate_failures do
            original_description = project.description

            put :update, params: {
              namespace_id: project.namespace,
              id: project,
              project: {
                name: 'Guest Renamed',
                description: 'hacked',
                import_url: 'https://example.com/attacker.git',
                project_feature_attributes: { issues_access_level: 0 }
              }
            }

            expect(response).to have_gitlab_http_status(:not_found), <<~MSG
              CVE-2026-16494 regression: authorize_admin_project! must run for every update.
              An `only:` option on the skip_before_action in ee/app/controllers/ee/projects_controller.rb
              is OR-ed with the `if:` condition, which skips the callback on every update.
            MSG

            project.reload
            expect(project.description).to eq(original_description)
            expect(project.import_url).to be_nil
            expect(project.project_feature.issues_access_level).not_to eq(0)
          end
        end
      end
    end

    context 'when the user has neither update_duo_settings nor the sast_vr ability' do
      let_it_be(:developer) { create(:user, developer_of: project) }

      let(:params) { { project_setting_attributes: { duo_sast_vr_workflow_enabled: true } } }

      before do
        sign_in(developer)
        project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
      end

      it 'denies access' do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(project.reload.project_setting.duo_sast_vr_workflow_enabled).to be(false)
      end
    end

    context 'when dap_session_tracking_enabled param is specified' do
      let(:params) { { project_setting_attributes: { dap_session_tracking_enabled: true } } }

      let(:request) do
        put :update, params: { namespace_id: project.namespace, id: project, project: params }
      end

      context 'when dap_session_tracking is available' do
        before do
          stub_feature_flags(dap_session_commit_tracking: project)
          stub_licensed_features(ai_workflows: true)
          project.project_setting.update!(duo_features_enabled: true)
        end

        it 'updates dap_session_tracking_enabled' do
          expect { request }
            .to change { project.reload.project_setting.dap_session_tracking_enabled }
            .from(false).to(true)
        end
      end

      context 'when dap_session_tracking is not available' do
        before do
          stub_feature_flags(dap_session_commit_tracking: false)
        end

        it 'does not update dap_session_tracking_enabled' do
          expect { request }
            .not_to change { project.reload.project_setting.dap_session_tracking_enabled }.from(false)
        end
      end
    end
  end

  describe '#download_export', feature_category: :importers do
    let(:request) { get :download_export, params: { namespace_id: project.namespace, id: project } }

    context 'when project export is enabled' do
      it_behaves_like 'audit events with event type' do
        let_it_be(:audit_name) { 'project_export_file_download_started' }
        let_it_be(:custom_message) { 'Export file download started' }
      end

      context 'when user is admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }

        it_behaves_like 'audit events with event type' do
          let_it_be(:audit_name) { 'project_export_file_download_started' }
          let_it_be(:custom_message) { 'Export file download started' }
        end

        context 'when silent exports enabled' do
          before do
            stub_application_setting(silent_admin_exports_enabled: true)
          end

          it 'does not log an audit event' do
            expect { request }.not_to change { AuditEventReader.count }
          end
        end
      end
    end

    context 'when project export is disabled' do
      before do
        stub_ee_application_setting(project_export_enabled?: false)
      end

      it 'does not log an audit event' do
        expect { request }.not_to change { AuditEventReader.count }
      end
    end
  end

  context 'Archive & Unarchive actions', feature_category: :groups_and_projects do
    let(:project) { create(:project, group: group) }
    let(:archived_project) { create(:project, :archived, group: group) }

    describe 'POST #archive' do
      let(:request) { post :archive, params: { namespace_id: project.namespace, id: project } }

      context 'for a user with the ability to archive a project' do
        # rubocop:disable RSpec/BeforeAllRoleAssignment -- uses let(:project), not let_it_be
        before do
          group.add_owner(user)
        end
        # rubocop:enable RSpec/BeforeAllRoleAssignment

        it_behaves_like 'audit events with event type' do
          let_it_be(:audit_name) { 'project_archived' }
          let_it_be(:custom_message) { 'Project archived' }
        end
      end

      context 'for a user that does not have the ability to archive a project' do
        before do
          project.add_maintainer(user)
        end

        it 'does not log the audit event' do
          expect { request }.not_to change { AuditEventReader.count }
        end
      end
    end

    describe 'POST #unarchive' do
      let(:request) { post :unarchive, params: { namespace_id: archived_project.namespace, id: archived_project } }

      context 'for a user with the ability to unarchive a project' do
        # rubocop:disable RSpec/BeforeAllRoleAssignment -- uses let(:project), not let_it_be
        before do
          group.add_owner(user)
        end
        # rubocop:enable RSpec/BeforeAllRoleAssignment

        it_behaves_like 'audit events with event type' do
          let_it_be(:audit_name) { 'project_unarchived' }
          let_it_be(:custom_message) { 'Project unarchived' }
        end
      end

      context 'for a user that does not have the ability to unarchive a project' do
        before do
          project.add_maintainer(user)
        end

        it 'does not log the audit event' do
          expect { request }.not_to change { AuditEventReader.count }
        end
      end
    end
  end

  describe 'DELETE #destroy', feature_category: :groups_and_projects, time_travel_to: '2025-02-04' do
    let(:project) { create(:project, group: group) }

    before do
      group.add_member(user, Gitlab::Access::OWNER)
      controller.instance_variable_set(:@project, project)
      sign_in(user)
    end

    context 'when project is linked as security policy project' do
      subject(:delete_project) { delete :destroy, params: { namespace_id: project.namespace, id: project } }

      before do
        stub_licensed_features(security_orchestration_policies: true)

        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
      end

      let(:error_message) { 'Project cannot be deleted because it is linked as a security policy project' }

      it 'alerts' do
        delete_project

        expect(flash[:alert]).to eq(error_message)
      end

      it "doesn't mark for deletion" do
        expect { delete_project }.not_to change { project.reload.self_deletion_scheduled? }.from(false)
      end
    end
  end
end
