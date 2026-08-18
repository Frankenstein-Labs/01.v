# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdateService, '#execute', feature_category: :groups_and_projects do
  include EE::GeoHelpers

  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- specs mutate instance AI settings stored on the default organization
  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }
  let(:project) { create(:project, :repository, creator: user, namespace: user.namespace) }

  context 'shared runners', :saas do
    let(:opts) { { shared_runners_enabled: enabled } }
    let(:enabled) { true }

    let_it_be_with_reload(:user) { create(:user, :with_sign_ins) }
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :free_plan, trial_ends_on: Date.today + 1.day) }
    let_it_be_with_reload(:project) { create(:project, :repository, creator: user, group: group) }

    before do
      allow(::Gitlab).to receive(:com?).and_return(true)
    end

    context 'when shared runners are on' do
      let(:enabled) { false }

      before do
        project.update!(shared_runners_enabled: true)
      end

      it 'disables shared runners', :aggregate_failures do
        result = update_project(project, user, opts)

        expect(result).to eq(status: :success)
        expect(project).to have_attributes(opts)
      end

      context 'when user has valid credit card' do
        before do
          create(:credit_card_validation, user: user)
        end

        it 'disables shared runners', :aggregate_failures do
          result = update_project(project, user, opts)

          expect(result).to eq(status: :success)
          expect(project).to have_attributes(opts)
        end
      end
    end

    context 'when shared runners are off' do
      before do
        project.update!(shared_runners_enabled: false)
      end

      context 'when user has valid credit card' do
        before do
          create(:credit_card_validation, user: user)
        end

        it 'enables shared runners', :aggregate_failures do
          result = update_project(project, user, opts)

          expect(result).to eq(status: :success)
          expect(project).to have_attributes(opts)
        end
      end

      context 'when user has not completed identity verification' do
        before do
          allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
            allow(instance).to receive(:user_can_enable_shared_runners?).and_return(false)
          end
        end

        it 'does not enable shared runners', :aggregate_failures do
          result = update_project(project, user, opts)

          project.reload

          expect(result).to eq(
            status: :error,
            message: 'Shared runners enabled cannot be enabled until identity verification is completed'
          )
          expect(project.shared_runners_enabled).to be(false)
        end
      end
    end
  end

  context 'repository mirror' do
    let(:opts) { { mirror: true, import_url: 'http://foo.com' } }

    before do
      stub_licensed_features(repository_mirrors: true)
      stub_ee_application_setting(elasticsearch_indexing?: true)
    end

    it 'sets mirror attributes' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(project).once
      result = update_project(project, user, opts)

      expect(result).to eq(status: :success)
      expect(project).to have_attributes(opts)
      expect(project.mirror_user).to eq(user)
    end

    it 'does not touch mirror_user_id for non-mirror changes' do
      result = update_project(project, user, description: 'anything')

      expect(result).to eq(status: :success)
      expect(project.mirror_user).to be_nil
    end

    it 'forbids non-admins from setting mirror_user_id explicitly' do
      project.team.add_maintainer(admin)
      result = update_project(project, user, opts.merge(mirror_user_id: admin.id))

      expect(result).to eq(status: :error, message: 'Mirror user is invalid')
      expect(project.mirror_user).to be_nil
    end

    it 'allows admins to set mirror_user_id' do
      project.team.add_maintainer(admin)
      result = update_project(project, admin, opts.merge(mirror_user_id: user.id))

      expect(result).to eq(status: :success)
      expect(project.mirror_user).to eq(user)
    end

    it 'forces an import job' do
      expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

      update_project(project, user, opts)
    end

    context 'when update mirror branch setting' do
      before do
        project.team.add_maintainer(admin)
      end

      it 'allow mirror_branch_regex to be updated' do
        result = update_project(project, admin, opts.merge(mirror_branch_regex: :test))

        expect(result).to eq(status: :success)
        expect(project.mirror_branch_regex).to match('test')
      end

      it 'enable only_mirror_protected_branches would clean mirror_branch_regex' do
        project.mirror_branch_regex = 'test'
        result = update_project(project, admin, opts.merge(only_mirror_protected_branches: true))

        expect(result).to eq(status: :success)
        expect(project.mirror_branch_regex).to be_nil
      end

      it 'fill mirror_branch_regex would disable only_mirror_protected_branches' do
        project.only_mirror_protected_branches = true
        result = update_project(project, admin, opts.merge(mirror_branch_regex: 'text'))

        expect(result).to eq(status: :success)
        expect(project.only_mirror_protected_branches).to be_falsey
      end
    end
  end

  context 'audit events' do
    let_it_be(:user) { create(:user) }

    let(:audit_event_params) do
      {
        author_id: user.id,
        entity_id: project.id,
        entity_type: 'Project',
        details: {
          author_name: user.name,
          author_class: user.class.name,
          target_id: project.id,
          target_type: 'Project',
          target_details: project.full_path
        }
      }
    end

    context 'topics' do
      let(:topics) { %w[foo bar] }

      # A method rather than a `let`: the reader returns an Array, so a
      # memoized value would never change inside `change {}`.
      def topic_changed_audits
        AuditEventReader.where(%q("details" LIKE '%:event_name: project_topics_updated%'))
      end

      it 'audits when topics change' do
        expect { update_project(project, user, topics: topics) }.to change { topic_changed_audits.count }.by(1)
        expect(topic_changed_audits.last.details[:to]).to match_array(topics)
      end

      it 'does not audit when topics are unchanged' do
        # with unrleated field change
        expect { update_project(project, user, name: 'foo') }.not_to change { topic_changed_audits.count }

        update_project(project, user, topics: topics)
        # with change where topic list is stable across update
        expect { update_project(project, user, topics: topics) }.not_to change { topic_changed_audits.count }
      end
    end

    describe '#name' do
      include_examples 'audit event logging' do
        let!(:old_name) { project.full_name }
        let(:fail_condition!) do
          allow_any_instance_of(Project).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        end

        def operation
          update_project(project, user, name: 'foobar')
        end

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              change: 'name',
              event_name: 'project_name_updated',
              from: old_name,
              to: project.full_name,
              custom_message: "Changed name from #{old_name} to #{project.full_name}"
            )
          end
        end
      end
    end

    describe '#path' do
      include_examples 'audit event logging' do
        let(:fail_condition!) do
          allow_any_instance_of(Project).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        end

        def operation
          update_project(project, user, path: 'foobar1')
        end

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              change: 'path',
              event_name: 'project_path_updated',
              from: project.old_path_with_namespace,
              to: project.full_path,
              custom_message: "Changed path from #{project.old_path_with_namespace} to #{project.full_path}"
            )
          end
        end
      end
    end

    describe '#default_branch' do
      include_examples 'audit event logging' do
        let(:fail_condition!) do
          allow_next_instance_of(Project) do |project|
            allow(project).to receive(:change_head).and_return(false)
          end
        end

        def operation
          update_project(project, user, default_branch: 'feature')
        end

        let_it_be(:event_type) { Projects::UpdateService::DEFAULT_BRANCH_CHANGE_AUDIT_TYPE }

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              event_name: 'project_default_branch_updated',
              from: project.previous_default_branch,
              to: project.default_branch,
              custom_message: format(Projects::UpdateService::DEFAULT_BRANCH_CHANGE_AUDIT_MESSAGE, project.previous_default_branch, project.default_branch)
            )
          end
        end
      end
    end

    describe '#visibility' do
      include_examples 'audit event logging' do
        let(:fail_condition!) do
          allow_any_instance_of(Project).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        end

        def operation
          update_project(project, user, visibility_level: Gitlab::VisibilityLevel::INTERNAL)
        end

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              change: 'visibility_level',
              event_name: 'project_visibility_level_updated',
              from: 'Private',
              to: 'Internal',
              custom_message: "Changed visibility_level from Private to Internal"
            )
          end
        end
      end
    end
  end

  context 'when updating a default branch' do
    let_it_be_with_reload(:project) { create(:project, :repository) }

    before do
      update_default_branch('master')
    end

    context 'when default_branch is not changed' do
      it 'does not update the default branch' do
        expect { update_default_branch(project.default_branch) }.not_to change { project.default_branch }
      end
    end

    context 'when block_branch_modification is enabled' do
      it 'returns error with message' do
        expect_next_instance_of(::Security::SecurityOrchestrationPolicies::DefaultBranchUpdationCheckService) do |service|
          expect(service).to receive(:execute).and_return(true)
        end

        expect(update_default_branch).to eq(status: :error, message: 'Updating default branch is blocked by security policy')
      end
    end

    context 'when block_branch_modification is not enabled' do
      it 'changes the default branch' do
        expect_next_instance_of(::Security::SecurityOrchestrationPolicies::DefaultBranchUpdationCheckService) do |service|
          expect(service).to receive(:execute).and_return(false)
        end

        update_default_branch

        expect(project.reload.default_branch).to eq('feature')
      end
    end

    def update_default_branch(branch = 'feature')
      update_project(project, user, default_branch: branch)
    end
  end

  context 'triggering wiki Geo syncs', :geo, feature_category: :geo_replication do
    let_it_be(:primary) { create(:geo_node, :primary) }
    let_it_be(:secondary) { create(:geo_node) }

    before do
      create(:project_wiki_repository, project: project)
    end

    context 'with geo_project_wiki_repository_replication feature flag disabled' do
      before do
        stub_feature_flags(geo_project_wiki_repository_replication: false)
      end

      context 'when on a Geo primary site' do
        before do
          stub_current_geo_node(primary)
        end

        context 'when enabling a wiki' do
          it 'does not log an event to the Geo event log' do
            project.project_feature.update_column(:wiki_access_level, ProjectFeature::DISABLED)
            project.reload

            expect { update_project(project, user, project_feature_attributes: { wiki_access_level: ProjectFeature::ENABLED }) }
              .not_to change {
                Geo::Event.where(replicable_name: :project_wiki_repository, event_name: :updated).count
              }

            expect(project.wiki_enabled?).to be true
          end
        end
      end

      context 'when not on a Geo primary site' do
        before do
          stub_current_geo_node(secondary)
        end

        context 'when enabling a wiki' do
          it 'does not log an event to the Geo event log' do
            project.project_feature.update_column(:wiki_access_level, ProjectFeature::DISABLED)
            project.reload

            expect { update_project(project, user, project_feature_attributes: { wiki_access_level: ProjectFeature::ENABLED }) }
              .not_to change {
                Geo::Event.where(replicable_name: :project_wiki_repository, event_name: :updated).count
              }

            expect(project.wiki_enabled?).to be true
          end
        end
      end
    end

    context 'with geo_project_wiki_repository_replication feature flag enabled' do
      before do
        stub_feature_flags(geo_project_wiki_repository_replication: true)
      end

      context 'when on a Geo primary site' do
        before do
          stub_current_geo_node(primary)
        end

        context 'when enabling a wiki' do
          before do
            project.project_feature.update_column(:wiki_access_level, ProjectFeature::DISABLED)
            project.reload
          end

          it 'calls replicator to update Geo' do
            expect_next_instance_of(Geo::ProjectWikiRepositoryReplicator) do |instance|
              expect(instance).to receive(:geo_handle_after_update)
            end

            result = update_project(project, user, project_feature_attributes: { wiki_access_level: ProjectFeature::ENABLED })

            expect(result).to eq({ status: :success })
            expect(project.wiki_enabled?).to be true
          end

          it 'logs an event to the Geo event log' do
            expect { update_project(project, user, project_feature_attributes: { wiki_access_level: ProjectFeature::ENABLED }) }
              .to change {
                Geo::Event.where(replicable_name: :project_wiki_repository, event_name: :updated).count
              }.by(1)
          end

          context 'with PRIVATE access level' do
            it 'logs an event to the Geo event log' do
              expect { update_project(project, user, project_feature_attributes: { wiki_access_level: ProjectFeature::PRIVATE }) }
                .to change {
                  Geo::Event.where(replicable_name: :project_wiki_repository, event_name: :updated).count
                }.by(1)

              expect(project.wiki_enabled?).to be true
            end
          end
        end

        context 'when we update project but not enabling a wiki' do
          context 'when the wiki is disabled' do
            before do
              project.project_feature.update_column(:wiki_access_level, ProjectFeature::DISABLED)
            end

            it 'does not call replicator to update Geo' do
              expect_next_instance_of(Geo::ProjectWikiRepositoryReplicator).never

              result = update_project(project, user, { name: 'test1' })

              expect(result).to eq({ status: :success })
              expect(project.wiki_enabled?).to be false
            end
          end

          context 'when the wiki was already enabled' do
            before do
              project.project_feature.update_column(:wiki_access_level, ProjectFeature::ENABLED)
            end

            it 'does not call replicator to update Geo' do
              expect_next_instance_of(Geo::ProjectWikiRepositoryReplicator).never

              result = update_project(project, user, { name: 'test1' })

              expect(result).to eq({ status: :success })
              expect(project.wiki_enabled?).to be true
            end
          end
        end
      end

      context 'when not on a Geo primary site' do
        before do
          stub_current_geo_node(secondary)
        end

        context 'when enabling a wiki' do
          before do
            project.project_feature.update_column(:wiki_access_level, ProjectFeature::DISABLED)
            project.reload
          end

          it 'does not log an event to the Geo event log' do
            expect { update_project(project, user, project_feature_attributes: { wiki_access_level: ProjectFeature::ENABLED }) }
              .not_to change {
                Geo::Event.where(replicable_name: :project_wiki_repository, event_name: :updated).count
              }

            expect(project.wiki_enabled?).to be true
          end
        end
      end
    end
  end

  context 'repository_size_limit assignment as Bytes' do
    let_it_be_with_reload(:project) { create(:project, repository_size_limit: 0) }
    let_it_be(:admin_user) { create(:admin) }

    context 'when the user is an admin and admin mode is enabled', :enable_admin_mode do
      context 'when the param is present' do
        let(:opts) { { repository_size_limit: '100' } }

        it 'converts from MiB to Bytes' do
          update_project(project, admin_user, opts)

          expect(project.reload.repository_size_limit).to eql(100 * 1024 * 1024)
        end
      end

      context 'when the param is an empty string' do
        let(:opts) { { repository_size_limit: '' } }

        it 'assigns a nil value' do
          update_project(project, admin_user, opts)

          expect(project.reload.repository_size_limit).to be_nil
        end
      end
    end

    context 'when the user is an admin and admin mode is disabled' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'does not update the limit' do
        update_project(project, admin_user, opts)

        expect(project.reload.repository_size_limit).to eq(0)
      end
    end

    context 'when user is not an admin' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'does not persist the repository_size_limit' do
        update_project(project, user, opts)

        expect(project.reload.repository_size_limit).to eq(0)
      end
    end
  end

  context 'when there are merge requests in merge train' do
    before do
      stub_licensed_features(merge_pipelines: true, merge_trains: true)
      project.update!(merge_pipelines_enabled: true)
    end

    let!(:first_merge_request) do
      create(:merge_request, :on_train, target_project: project, source_project: project)
    end

    let!(:second_merge_request) do
      create(:merge_request, :on_train, target_project: project, source_project: project, source_branch: 'feature-1')
    end

    context 'when merge pipelines option is disabled' do
      it 'drops all merge request in the train', :sidekiq_might_not_need_inline do
        expect do
          update_project(project, user, merge_pipelines_enabled: false)
        end.to change { MergeTrains::Car.count }.from(2).to(0)
      end
    end

    context 'when merge pipelines option stays enabled' do
      it 'does not drop all merge request in the train' do
        expect do
          update_project(project, user, merge_pipelines_enabled: true)
        end.not_to change { MergeTrains::Car.count }
      end
    end
  end

  it 'returns an error result when record cannot be updated' do
    admin = create(:admin)

    result = update_project(project, admin, { name: 'foo&bar' })

    expect(result).to eq({ status: :error, message: "Name can contain only letters, digits, emoji, '_', '.', '+', dashes, or spaces. It must start with a letter, digit, emoji, or '_'." })
  end

  it 'calls remove_import_data if mirror was disabled in previous change' do
    update_project(project, user, { mirror: false })

    expect(project.import_data).to be_nil
    expect(project).not_to be_mirror
  end

  context 'updating analytics_dashboards_pointer_attributes.target_project_id param' do
    let_it_be(:user) { create :user }
    let_it_be_with_reload(:group) { create(:group) { |g| g.add_owner(user) } }

    let(:project) { create :project, namespace: group }
    let(:sibling_project) { create :project, namespace: group }

    let(:attrs) { { analytics_dashboards_pointer_attributes: { target_project_id: sibling_project.id } } }

    it 'updates the Analytics Dashboards pointer project' do
      update_project(project, user, attrs)

      expect(project.analytics_dashboards_pointer.target_project).to eq(sibling_project)
    end

    context 'when passing a bogus target project' do
      let(:attrs) { { analytics_dashboards_pointer_attributes: { target_project_id: create(:project).id } } }

      it 'fails' do
        result = update_project(project, user, attrs)

        expect(result[:status]).to eq(:error)
        expect(project).to be_invalid
      end
    end

    context 'when pointer project is empty' do
      let(:existing_pointer) do
        create(:analytics_dashboards_pointer, project: project, namespace: nil, target_project: sibling_project)
      end

      let(:attrs) { { analytics_dashboards_pointer_attributes: { id: existing_pointer.id, target_project_id: '' } } }

      it 'removes pointer project' do
        update_project(project, user, attrs)

        expect(project.reload.analytics_dashboards_pointer).to be_nil
      end
    end
  end

  describe 'when updating duo_features_enabled' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:service_account) { create(:user) }
    let_it_be_with_reload(:integration) { create(:amazon_q_integration, instance: false, project: project, auto_review_enabled: true) }
    let(:add_instance) { Ai::ServiceAccountMemberAddService.new(project, service_account) }
    let(:remove_instance) { Ai::ServiceAccountMemberRemoveService.new(user, project, service_account) }

    using RSpec::Parameterized::TableSyntax

    before do
      allow(Ai::ServiceAccountMemberAddService).to receive(:new).with(project, service_account).and_return(add_instance)
      allow(Ai::ServiceAccountMemberRemoveService).to receive(:new).with(user, project, service_account).and_return(remove_instance)
      Ai::Setting.for_organization(project.organization).update!(amazon_q_service_account_user_id: service_account.id)
      allow(add_instance).to receive(:execute).and_call_original
      allow(remove_instance).to receive(:execute).and_call_original
    end

    where(:attrs, :amazon_q_connected, :auto_review_enabled, :expected_service, :expected_integration_params) do
      { duo_features_enabled: 'true' }  | true  | true  | Ai::ServiceAccountMemberAddService    | ['default_on', true]
      { duo_features_enabled: 'true' }  | true  | nil   | Ai::ServiceAccountMemberAddService    | ['default_on', true]
      { duo_features_enabled: 'true' }  | true  | false | Ai::ServiceAccountMemberAddService    | ['default_on', false]
      { duo_features_enabled: 'false' } | true  | false | Ai::ServiceAccountMemberRemoveService | ['never_on', false]
      { duo_features_enabled: 'false' } | true  | true  | Ai::ServiceAccountMemberRemoveService | ['never_on', false]
      { duo_features_enabled: 'true' }  | false | false | nil                                            | ['default_on', true]
      { duo_features_enabled: 'false' } | false | false | nil                                            | ['default_on', true]
      {}                                | true  | false | nil                                            | ['default_on', true]
      {}                                | false | false | nil                                            | ['default_on', true]
    end

    with_them do
      def expect_on_service(service, instance)
        if service == expected_service
          expect(service).to have_received(:new)
          expect(instance).to have_received(:execute)
        else
          expect(service).not_to have_received(:new)
        end
      end

      it 'triggers the expected service' do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_connected)
        integration.update!(auto_review_enabled: false) if auto_review_enabled

        params = { amazon_q_auto_review_enabled: auto_review_enabled, project_setting_attributes: attrs }
        update_project(project, user, params)

        expect_on_service(Ai::ServiceAccountMemberAddService, add_instance)
        expect_on_service(Ai::ServiceAccountMemberRemoveService, remove_instance)

        expect(integration.reload.values_at(:availability, :auto_review_enabled)).to eq(expected_integration_params)
      end
    end

    context 'for duo workflow project authorization' do
      let(:add_service) { instance_double(Ai::ServiceAccountMemberAddService) }
      let(:remove_service) { instance_double(Ai::ServiceAccountMemberRemoveService) }

      before do
        Ai::Setting.for_organization(project.organization).update!(duo_workflow_service_account_user_id: service_account.id)
        allow(Ai::ServiceAccountMemberAddService).to receive(:new).with(project, service_account).and_return(add_service)
        allow(Ai::ServiceAccountMemberRemoveService).to receive(:new).with(user, project, service_account).and_return(remove_service)
        allow(add_service).to receive(:execute)
        allow(remove_service).to receive(:execute)
        allow(::Ai::DuoWorkflow).to receive(:connected?).and_return(duo_workflow_connected)

        params = { project_setting_attributes: { duo_features_enabled: duo_features_enabled } }
        update_project(project, user, params)
      end

      where(:duo_features_enabled, :duo_workflow_connected, :calls_add_service, :calls_remove_service) do
        'true'  | true  | true  | false
        'false' | true  | false | true
        'true'  | false | false | false
        'false' | false | false | false
        nil     | true  | false | false
      end

      with_them do
        it 'calls the expected service based on configuration' do
          if calls_add_service
            expect(Ai::ServiceAccountMemberAddService).to have_received(:new).with(project, service_account)
            expect(add_service).to have_received(:execute)
          else
            expect(Ai::ServiceAccountMemberAddService).not_to have_received(:new)
          end

          if calls_remove_service
            expect(Ai::ServiceAccountMemberRemoveService).to have_received(:new).with(user, project, service_account)
            expect(remove_service).to have_received(:execute)
          else
            expect(Ai::ServiceAccountMemberRemoveService).not_to have_received(:new)
          end
        end
      end
    end
  end

  shared_examples 'ignores web_based_commit_signing_enabled param' do |param:, expected:|
    it 'does not update web_based_commit_signing_enabled param' do
      result = update_project(project, user, param)

      expect(result).to eq(status: :success)
      expect(project.web_based_commit_signing_enabled).to eq(expected)
    end
  end

  context 'with web_based_commit_signing_enabled param' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :repository, creator: user, group: group) }

    context 'when the repositories_web_based_commit_signing feature is not available' do
      before do
        stub_saas_features(repositories_web_based_commit_signing: false)
      end

      it_behaves_like 'ignores web_based_commit_signing_enabled param',
        param: { web_based_commit_signing_enabled: true },
        expected: false
    end

    context 'when the repositories_web_based_commit_signing feature is available' do
      before do
        stub_saas_features(repositories_web_based_commit_signing: true)
      end

      context 'when web_based_commit_signing_enabled is not present' do
        it_behaves_like 'ignores web_based_commit_signing_enabled param',
          param: {},
          expected: false
      end

      context 'when group setting web_based_commit_signing_enabled is enabled' do
        before_all do
          group.namespace_settings.update!(web_based_commit_signing_enabled: true)
          project.project_setting.update!(web_based_commit_signing_enabled: true)
        end

        it_behaves_like 'ignores web_based_commit_signing_enabled param',
          param: { web_based_commit_signing_enabled: false },
          expected: true
      end

      context 'when group setting web_based_commit_signing_enabled is not enabled' do
        it 'updates web_based_commit_signing_enabled to the project' do
          params = { web_based_commit_signing_enabled: true }
          result = update_project(project, user, params)

          expect(result).to eq(status: :success)

          expect(project.web_based_commit_signing_enabled).to be(true)
        end
      end

      context 'when project does not belong to a group' do
        let_it_be_with_reload(:project) { create(:project, :repository, creator: user, namespace: user.namespace) }

        it 'updates web_based_commit_signing_enabled to the project' do
          params = { web_based_commit_signing_enabled: true }
          result = update_project(project, user, params)

          expect(result).to eq(status: :success)

          expect(project.web_based_commit_signing_enabled).to be(true)
        end
      end
    end
  end

  shared_examples 'updating a sec AI workflow setting via update service' do |setting_attribute, feature_flag|
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:developer) { create(:user, developer_of: project) }
    let_it_be(:security_manager) { create(:user, security_manager_of: project) }

    let(:opts) { { project_setting_attributes: { setting_attribute => true } } }

    before do
      project.project_setting.update!(setting_attribute => false)
    end

    context 'when the user has update_duo_settings' do
      it 'updates the value' do
        update_project(project, maintainer, opts)

        expect(project.reload.project_setting.public_send(setting_attribute)).to be(true)
      end
    end

    context 'when the user is a security manager' do
      it 'updates the value' do
        update_project(project, security_manager, opts)

        expect(project.reload.project_setting.public_send(setting_attribute)).to be(true)
      end

      context "when #{feature_flag} FF is disabled" do
        before do
          stub_feature_flags(feature_flag => false)
        end

        it 'silently drops the attribute' do
          update_project(project, security_manager, opts)

          expect(project.reload.project_setting.public_send(setting_attribute)).to be(false)
        end
      end
    end

    context 'when the user has neither update_duo_settings nor the ability' do
      it 'silently drops the attribute' do
        update_project(project, developer, opts)

        expect(project.reload.project_setting.public_send(setting_attribute)).to be(false)
      end
    end
  end

  describe 'when updating duo_sast_vr_workflow_enabled' do
    it_behaves_like 'updating a sec AI workflow setting via update service',
      :duo_sast_vr_workflow_enabled, :update_sast_vr_setting_permission
  end

  describe 'when updating duo_sast_fp_detection_enabled' do
    it_behaves_like 'updating a sec AI workflow setting via update service',
      :duo_sast_fp_detection_enabled, :update_false_positive_detection_setting_permission
  end

  describe 'when updating duo_secret_detection_fp_enabled' do
    it_behaves_like 'updating a sec AI workflow setting via update service',
      :duo_secret_detection_fp_enabled, :update_false_positive_detection_setting_permission
  end

  describe 'when updating duo_vulnerability_context_analysis_enabled' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:developer) { create(:user, developer_of: project) }
    let_it_be(:security_manager) { create(:user, security_manager_of: project) }

    let(:opts) { { project_setting_attributes: { duo_vulnerability_context_analysis_enabled: true } } }

    before do
      project.project_setting.update!(duo_vulnerability_context_analysis_enabled: false)
    end

    context 'when the user has update_duo_settings' do
      it 'updates the value' do
        update_project(project, maintainer, opts)

        expect(project.reload.project_setting.duo_vulnerability_context_analysis_enabled).to be(true)
      end
    end

    context 'when the user is a security manager' do
      it 'updates the value' do
        update_project(project, security_manager, opts)

        expect(project.reload.project_setting.duo_vulnerability_context_analysis_enabled).to be(true)
      end
    end

    context 'when the user has neither update_duo_settings nor the ability' do
      it 'silently drops the attribute' do
        update_project(project, developer, opts)

        expect(project.reload.project_setting.duo_vulnerability_context_analysis_enabled).to be(false)
      end
    end
  end

  describe 'tracking who enabled the Duo dependency-bump breaking-changes setting' do
    let_it_be(:other_user) { create(:user) }

    let(:project_setting) { project.project_setting }

    before do
      project_setting.save!
    end

    context 'when the setting is enabled' do
      let(:opts) { { project_setting_attributes: { duo_dependency_bump_breaking_changes_enabled: true } } }

      it 'stamps the current user as the enabler' do
        expect { update_project(project, user, opts) }
          .to change { project_setting.reload.duo_dependency_bump_breaking_changes_enabled_by_id }
          .from(nil).to(user.id)
      end

      context 'when the setting is already enabled' do
        before do
          project_setting.update!(
            duo_dependency_bump_breaking_changes_enabled: true,
            duo_dependency_bump_breaking_changes_enabled_by_id: other_user.id
          )
        end

        it 'preserves the original enabler' do
          expect { update_project(project, user, opts) }
            .not_to change { project_setting.reload.duo_dependency_bump_breaking_changes_enabled_by_id }
            .from(other_user.id)
        end
      end
    end

    context 'when the setting is disabled' do
      let(:opts) { { project_setting_attributes: { duo_dependency_bump_breaking_changes_enabled: false } } }

      before do
        project_setting.update!(
          duo_dependency_bump_breaking_changes_enabled: true,
          duo_dependency_bump_breaking_changes_enabled_by_id: other_user.id
        )
      end

      it 'clears the enabler' do
        expect { update_project(project, user, opts) }
          .to change { project_setting.reload.duo_dependency_bump_breaking_changes_enabled_by_id }
          .from(other_user.id).to(nil)
      end
    end

    context 'when the setting is passed as a top-level attribute (REST API)' do
      context 'when enabling' do
        let(:opts) { { duo_dependency_bump_breaking_changes_enabled: true } }

        it 'stamps the current user as the enabler' do
          expect { update_project(project, user, opts) }
            .to change { project_setting.reload.duo_dependency_bump_breaking_changes_enabled_by_id }
            .from(nil).to(user.id)
        end
      end

      context 'when disabling' do
        let(:opts) { { duo_dependency_bump_breaking_changes_enabled: false } }

        before do
          project_setting.update!(
            duo_dependency_bump_breaking_changes_enabled: true,
            duo_dependency_bump_breaking_changes_enabled_by_id: other_user.id
          )
        end

        it 'clears the enabler' do
          expect { update_project(project, user, opts) }
            .to change { project_setting.reload.duo_dependency_bump_breaking_changes_enabled_by_id }
            .from(other_user.id).to(nil)
        end
      end
    end

    context 'when the setting is not part of the update' do
      let(:opts) { { description: 'unrelated change' } }

      before do
        project_setting.update!(
          duo_dependency_bump_breaking_changes_enabled: true,
          duo_dependency_bump_breaking_changes_enabled_by_id: other_user.id
        )
      end

      it 'leaves the enabler untouched' do
        expect { update_project(project, user, opts) }
          .not_to change { project_setting.reload.duo_dependency_bump_breaking_changes_enabled_by_id }
          .from(other_user.id)
      end
    end
  end

  describe 'when updating ai_audit_events_storage_enabled' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:security_manager) { create(:user, security_manager_of: project) }

    let(:opts) { { project_setting_attributes: { ai_audit_events_storage_enabled: true } } }

    context 'when the user has update_storage_ai_audit_events' do
      it 'updates the value' do
        update_project(project, security_manager, opts)

        expect(project.reload.project_setting.ai_audit_events_storage_enabled).to be(true)
      end
    end

    context 'when the user does not have update_storage_ai_audit_events' do
      it 'silently drops the attribute' do
        update_project(project, maintainer, opts)

        expect(project.reload.project_setting.ai_audit_events_storage_enabled).to be(false)
      end
    end
  end

  def update_project(project, user, opts)
    Projects::UpdateService.new(project, user, opts).execute
  end
end
