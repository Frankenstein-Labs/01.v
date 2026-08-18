# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApplicationSettings::UpdateService, feature_category: :shared do
  let!(:user) { create(:user) }
  let(:setting) { ApplicationSetting.create_from_defaults }
  let(:service) { described_class.new(setting, user, opts) }
  let_it_be(:default_organization) { create(:organization) }

  before do
    allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  shared_examples 'application_setting_audit_events_from_to' do
    it 'calls auditor' do
      expect { service.execute }.to change { AuditEventReader.count }.by(1)
      service.execute

      event = AuditEventReader.last
      expect(event.details[:from]).to eq change_from
      expect(event.details[:to]).to eq change_to
      expect(event.details[:change]).to eq change_field
    end

    context 'when user is nil' do
      let(:user) { nil }

      it "does not log an event" do
        expect { service.execute }.to not_change { AuditEventReader.count }
      end
    end
  end

  describe '#execute' do
    context 'common params' do
      let(:opts) { { home_page_url: 'http://foo.bar' } }
      let(:change_field) { 'home_page_url' }
      let(:change_to) { 'http://foo.bar' }
      let(:change_from) { nil }

      before do
        stub_licensed_features(extended_audit_events: true, admin_audit_log: true, code_owner_approval_required: true)
      end

      it 'properly updates settings with given params' do
        service.execute

        expect(setting.home_page_url).to eql(opts[:home_page_url])
      end

      it_behaves_like 'application_setting_audit_events_from_to'
    end

    context 'with valid params' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'returns success params' do
        expect(service.execute).to be(true)
      end
    end

    context 'with invalid params' do
      let(:opts) { { repository_size_limit: '-100' } }

      it 'returns error params' do
        expect(service.execute).to be(false)
      end
    end

    context 'elasticsearch_indexing update', feature_category: :global_search do
      let(:helper) { Search::Elastic::Helper.new }

      before do
        allow(Search::Elastic::Helper).to receive(:new).and_return(helper)
      end

      context 'index creation' do
        let(:opts) { { elasticsearch_indexing: true } }

        context 'when index does not exist' do
          it 'creates a new index' do
            expect(helper).to receive(:create_empty_index).with(options: { skip_if_exists: true })
            expect(helper).to receive(:create_standalone_indices).with(options: { skip_if_exists: true })
            expect(helper).to receive(:migrations_index_exists?).and_return(false)
            expect(helper).to receive(:create_migrations_index)
            expect(::Elastic::DataMigrationService).to receive(:mark_all_as_completed!)

            service.execute
          end
        end

        context 'when migrations index exists' do
          before do
            allow(helper).to receive(:create_empty_index).with(options: { skip_if_exists: true })
            allow(helper).to receive(:create_standalone_indices).with(options: { skip_if_exists: true })

            allow(helper).to receive(:migrations_index_exists?).and_return(true)
          end

          it 'does not create the migration index or mark migrations as complete' do
            expect(helper).not_to receive(:create_migrations_index)
            expect(::Elastic::DataMigrationService).not_to receive(:mark_all_as_completed!)

            service.execute
          end
        end

        context 'when an AuthorizationError is raised' do
          it 'does not throw exception' do
            expect(helper).to receive(:create_empty_index)
              .and_raise(Gitlab::Search::Client::AuthorizationError.new('Unauthorized'))
            expect(helper).not_to receive(:create_standalone_indices)

            expect { service.execute }.not_to raise_error
          end
        end

        context 'when a ConnectionError is raised' do
          it 'does not throw exception' do
            expect(helper).to receive(:create_empty_index)
              .and_raise(Gitlab::Search::Client::ConnectionError.new('Search cluster unavailable'))
            expect(helper).not_to receive(:create_standalone_indices)

            expect { service.execute }.not_to raise_error
          end
        end

        context 'when Elasticsearch::Transport::Transport::Error is raised' do
          it 'does not throw exception' do
            expect(helper).to receive(:create_empty_index)
              .and_raise(Elasticsearch::Transport::Transport::Error.new('error'))
            expect(helper).not_to receive(:create_standalone_indices)

            expect { service.execute }.not_to raise_error
          end
        end

        context 'when modifying a non Advanced Search setting' do
          let(:opts) { { repository_size_limit: '100' } }

          it 'does not check index_exists' do
            expect(helper).not_to receive(:create_empty_index)

            service.execute
          end
        end
      end
    end

    context 'repository_size_limit assignment as Bytes' do
      let(:service) { described_class.new(setting, user, opts) }

      context 'when param present' do
        let(:opts) { { repository_size_limit: '100' } }

        it 'converts from MiB to Bytes' do
          service.execute

          expect(setting.reload.repository_size_limit).to eql(100 * 1024 * 1024)
        end
      end

      context 'when param not present' do
        let(:opts) { { repository_size_limit: '' } }

        it 'does not update due to invalidity' do
          service.execute

          expect(setting.reload.repository_size_limit).to be_zero
        end

        it 'assign nil value' do
          service.execute

          expect(setting.repository_size_limit).to be_nil
        end
      end

      context 'elasticsearch', feature_category: :global_search do
        context 'limiting namespaces and projects' do
          before do
            setting.update!(elasticsearch_indexing: true)
            setting.update!(elasticsearch_limit_indexing: true)
          end

          context 'namespaces' do
            let(:namespaces) { create_list(:namespace, 3) }

            it 'creates ElasticsearchIndexedNamespace objects when given elasticsearch_namespace_ids' do
              opts = { elasticsearch_namespace_ids: namespaces.map(&:id).join(',') }

              expect do
                described_class.new(setting, user, opts).execute
              end.to change { ElasticsearchIndexedNamespace.count }.by(3)
            end

            it 'deletes ElasticsearchIndexedNamespace objects not in elasticsearch_namespace_ids' do
              create :elasticsearch_indexed_namespace, namespace: namespaces.last
              opts = { elasticsearch_namespace_ids: namespaces.first(2).map(&:id).join(',') }

              expect do
                described_class.new(setting, user, opts).execute
              end.to change { ElasticsearchIndexedNamespace.count }.from(1).to(2)

              expect(ElasticsearchIndexedNamespace.where(namespace_id: namespaces.last.id)).not_to exist
            end

            it 'disregards already existing ElasticsearchIndexedNamespace in elasticsearch_namespace_ids' do
              create :elasticsearch_indexed_namespace, namespace: namespaces.first
              opts = { elasticsearch_namespace_ids: namespaces.first(2).map(&:id).join(',') }

              expect do
                described_class.new(setting, user, opts).execute
              end.to change { ElasticsearchIndexedNamespace.count }.from(1).to(2)

              expect(ElasticsearchIndexedNamespace.pluck(:namespace_id)).to match_array([namespaces.first.id,
                namespaces.second.id])
            end
          end

          context 'projects' do
            let(:projects) { create_list(:project, 3) }

            it 'creates ElasticsearchIndexedProject objects when given elasticsearch_project_ids' do
              opts = { elasticsearch_project_ids: projects.map(&:id).join(',') }

              expect do
                described_class.new(setting, user, opts).execute
              end.to change { ElasticsearchIndexedProject.count }.by(3)
            end

            it 'deletes ElasticsearchIndexedProject objects not in elasticsearch_project_ids' do
              create :elasticsearch_indexed_project, project: projects.last
              opts = { elasticsearch_project_ids: projects.first(2).map(&:id).join(',') }

              expect do
                described_class.new(setting, user, opts).execute
              end.to change { ElasticsearchIndexedProject.count }.from(1).to(2)

              expect(ElasticsearchIndexedProject.where(project_id: projects.last.id)).not_to exist
            end

            it 'disregards already existing ElasticsearchIndexedProject in elasticsearch_project_ids' do
              create :elasticsearch_indexed_project, project: projects.first
              opts = { elasticsearch_project_ids: projects.first(2).map(&:id).join(',') }

              expect do
                described_class.new(setting, user, opts).execute
              end.to change { ElasticsearchIndexedProject.count }.from(1).to(2)

              expect(ElasticsearchIndexedProject.pluck(:project_id)).to eq([projects.first.id, projects.second.id])
            end
          end
        end

        context 'setting number_of_shards and number_of_replicas' do
          let(:alias_name) { 'alias-name' }

          it 'accepts hash values' do
            opts = { elasticsearch_shards: { alias_name => 10 }, elasticsearch_replicas: { alias_name => 2 } }

            described_class.new(setting, user, opts).execute

            setting = Elastic::IndexSetting[alias_name]
            expect(setting.number_of_shards).to eq(10)
            expect(setting.number_of_replicas).to eq(2)
          end

          it 'accepts legacy (integer) values' do
            opts = { elasticsearch_shards: 32, elasticsearch_replicas: 3 }

            described_class.new(setting, user, opts).execute

            Elastic::IndexSetting.every_alias do |setting|
              expect(setting.number_of_shards).to eq(32)
              expect(setting.number_of_replicas).to eq(3)
            end
          end
        end
      end
    end

    context 'user cap setting', feature_category: :seat_cost_management do
      shared_examples 'worker is not called' do
        it 'does not call ApproveBlockedPendingApprovalUsersWorker' do
          expect(ApproveBlockedPendingApprovalUsersWorker).not_to receive(:perform_async)

          service.execute
        end
      end

      shared_examples 'worker is called' do
        it 'calls ApproveBlockedPendingApprovalUsersWorker' do
          expect(ApproveBlockedPendingApprovalUsersWorker).to receive(:perform_async)

          service.execute
        end
      end

      context 'when new user cap is set to nil' do
        context 'when changing new user cap to any number' do
          let(:opts) { { new_user_signups_cap: 10, seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP } }

          include_examples 'worker is not called'
        end

        context 'when leaving new user cap set to nil' do
          let(:opts) { { new_user_signups_cap: nil, seat_control: ::ApplicationSetting::SEAT_CONTROL_OFF } }

          include_examples 'worker is not called'
        end
      end

      context 'when new user cap is set to a number' do
        let(:setting) do
          create(:application_setting, new_user_signups_cap: 10, seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP)
        end

        context 'when decreasing new user cap' do
          let(:opts) { { new_user_signups_cap: 8, auto_approve_pending_users: 'true' } }

          include_examples 'worker is not called'
        end

        context 'when increasing new user cap' do
          let(:opts) { { new_user_signups_cap: 15 } }

          include_examples 'worker is not called'

          context 'when auto approval is enabled' do
            let(:opts) { { new_user_signups_cap: 15, auto_approve_pending_users: 'true' } }

            include_examples 'worker is called'
          end
        end

        context 'when changing user cap to nil' do
          let(:opts) { { new_user_signups_cap: nil, seat_control: ::ApplicationSetting::SEAT_CONTROL_OFF } }

          include_examples 'worker is not called'

          context 'when auto approval is enabled' do
            let(:opts) { { new_user_signups_cap: nil, seat_control: ::ApplicationSetting::SEAT_CONTROL_OFF, auto_approve_pending_users: 'true' } }

            include_examples 'worker is called'
          end
        end
      end
    end

    shared_examples 'when updating duo settings' do |setting_key, setting_val|
      let(:params) { { setting_key => setting_val } }
      let(:service) { described_class.new(setting, user, params) }

      it 'triggers the CascadeDuoSettingsWorker with correct arguments' do
        expect(AppConfig::CascadeDuoSettingsWorker).to receive(:perform_async)
          .with(params.stringify_keys)

        service.execute
      end

      it 'updates the setting' do
        result = service.execute

        expect(result).to be_truthy

        expect(setting.reload.send(setting_key)).to be(setting_val)
      end
    end

    context 'when updating duo_features_enabled' do
      before do
        setting.update!(duo_features_enabled: false)
      end

      it_behaves_like 'when updating duo settings', :duo_features_enabled, true
    end

    context 'when duo_availability is set to always_on' do
      let(:service) { described_class.new(setting, user, { duo_availability: 'always_on' }) }

      before do
        setting.update!(duo_features_enabled: false, lock_duo_features_enabled: false)
      end

      it 'enqueues AppConfig::CascadeDuoSettingsWorker with duo_features_enabled: true' do
        expect(AppConfig::CascadeDuoSettingsWorker).to receive(:perform_async)
          .with(hash_including('duo_features_enabled' => true, 'lock_duo_features_enabled' => true))

        service.execute
      end

      it 'sets duo_features_enabled to true on the application setting' do
        service.execute

        expect(setting.reload.duo_features_enabled).to be(true)
      end

      it 'sets lock_duo_features_enabled to true on the application setting' do
        service.execute

        expect(setting.reload.lock_duo_features_enabled).to be(true)
      end
    end

    context 'when updating duo_remote_flows_enabled' do
      before do
        setting.update!(duo_remote_flows_enabled: true)
      end

      it_behaves_like 'when updating duo settings', :duo_remote_flows_enabled, false
    end

    context 'when updating ai_audit_events_storage_enabled' do
      before do
        setting.update!(ai_audit_events_storage_enabled: false)
      end

      it_behaves_like 'when updating duo settings', :ai_audit_events_storage_enabled, true
    end

    context 'when updating duo_foundational_flows_enabled' do
      before do
        setting.update!(duo_foundational_flows_enabled: false)
      end

      it_behaves_like 'when updating duo settings', :duo_foundational_flows_enabled, true
    end

    context 'when updating duo_agent_platform_enabled' do
      let(:opts) { { duo_agent_platform_enabled: false } }

      before do
        setting.update!(duo_agent_platform_enabled: true)
      end

      it 'updates the setting' do
        service.execute

        expect(setting.reload.duo_agent_platform_enabled).to be false
      end
    end

    context 'when updating auto_duo_code_review_enabled' do
      let(:params) { { auto_duo_code_review_enabled: true } }
      let(:service) { described_class.new(setting, user, params) }

      context 'when setting is not available' do
        before do
          allow(setting).to receive(:auto_duo_code_review_settings_available?).and_return(false)
        end

        it 'filters out the parameter' do
          expect { service.execute }
            .not_to change { setting.reload.auto_duo_code_review_enabled }
        end
      end

      context 'when setting is available' do
        before do
          setting.update!(auto_duo_code_review_enabled: false)
          allow(setting).to receive(:auto_duo_code_review_settings_available?).and_return(true)
        end

        it_behaves_like 'when updating duo settings', :auto_duo_code_review_enabled, true
      end
    end

    context 'when updating built_in_project_templates_enabled' do
      let(:params) { { built_in_project_templates_enabled: false } }
      let(:service) { described_class.new(setting, user, params) }

      before do
        setting.update!(built_in_project_templates_enabled: true)
      end

      it 'triggers the CascadeBuiltInProjectTemplatesEnabledWorker with the new value' do
        expect(AppConfig::CascadeBuiltInProjectTemplatesEnabledWorker).to receive(:perform_async).with(false)

        service.execute
      end

      it 'updates the setting' do
        result = service.execute

        expect(result).to be_truthy
        expect(setting.reload.built_in_project_templates_enabled).to be(false)
      end

      context 'when the setting has not changed' do
        let(:params) { { built_in_project_templates_enabled: true } }

        it 'does not trigger the worker' do
          expect(AppConfig::CascadeBuiltInProjectTemplatesEnabledWorker).not_to receive(:perform_async)

          service.execute
        end
      end
    end

    context 'when updating foundational agents statuses' do
      include_context 'with mocked Foundational Chat Agents'

      let(:foundational_agents_statuses) { [] }
      let(:params) { { foundational_agents_statuses: foundational_agents_statuses } }
      let(:service) { described_class.new(setting, user, params) }

      subject(:result) { service.execute }

      before do
        default_organization.update!(foundational_agents_status_records: [])
      end

      context 'when there are errors on validation' do
        let(:foundational_agents_statuses) do
          [
            { 'reference' => foundational_chat_agent_1_ref, 'enabled' => false },
            { 'reference' => invalid_agent_reference, 'enabled' => true }
          ]
        end

        it 'adds validation errors to the setting' do
          expect(result).to be false
        end
      end

      context 'when new statuses are valid' do
        let(:foundational_agents_statuses) do
          [
            { 'reference' => foundational_chat_agent_1_ref, 'enabled' => false },
            { 'reference' => foundational_chat_agent_2_ref, 'enabled' => true }
          ]
        end

        it 'updates the setting' do
          expect(result).to be_truthy

          expect(default_organization.foundational_agents_statuses).to match_array([
            { description: "First agent", enabled: false, name: "Agent 1", reference: "agent_1" },
            { description: "Second agent", enabled: true, name: "Agent 2", reference: "agent_2" }
          ])
        end

        it 'calls FoundationalAgentStatusAuditor with instance scope' do
          expect(::Ai::FoundationalAgentStatusAuditor).to receive(:new).with(
            hash_including(
              current_user: user,
              scope: instance_of(::Gitlab::Audit::InstanceScope),
              previous_statuses: contain_exactly(
                hash_including(reference: foundational_chat_agent_1_ref, enabled: nil),
                hash_including(reference: foundational_chat_agent_2_ref, enabled: nil)
              ),
              new_statuses: foundational_agents_statuses,
              default_enabled: true
            )
          ).and_call_original

          result
        end
      end

      context 'when there are validation errors' do
        let(:foundational_agents_statuses) do
          [{ 'reference' => invalid_agent_reference, 'enabled' => true }]
        end

        it 'does not call FoundationalAgentStatusAuditor' do
          expect(::Ai::FoundationalAgentStatusAuditor).not_to receive(:new)

          result
        end
      end
    end

    context 'when updating duo namespace access rules' do
      let_it_be(:namespace_a) { create(:group) }
      let_it_be(:namespace_b) { create(:group) }

      let(:duo_namespace_access_rules) do
        [
          { through_namespace: { id: namespace_a.id }, features: %w[duo_classic duo_agent_platform] },
          { through_namespace: { id: namespace_b.id }, features: %w[duo_agent_platform] }
        ]
      end

      let(:params) { { duo_namespace_access_rules: duo_namespace_access_rules } }
      let(:service) { described_class.new(setting, user, params) }

      subject(:result) { service.execute }

      context 'when rules are valid' do
        it 'creates instance accessible entity rules' do
          expect { result }.to change { Ai::FeatureAccessRule.count }.by(3)
        end

        it 'creates rules with correct attributes' do
          result

          expect(namespace_a.accessible_ai_features_on_instance.pluck(:accessible_entity)).to match_array(%w[
            duo_classic duo_agent_platform
          ])
          expect(namespace_b.accessible_ai_features_on_instance.pluck(:accessible_entity)).to match_array(%w[duo_agent_platform])
        end

        it 'deletes existing entity rules and creates new ones' do
          create(:ai_instance_accessible_entity_rules, through_namespace: namespace_a)

          expect { result }.to change { Ai::FeatureAccessRule.count }.from(1).to(3)
        end

        context 'when features is empty' do
          let(:duo_namespace_access_rules) do
            [
              { through_namespace: { id: namespace_a.id }, features: [] }
            ]
          end

          it 'deletes existing entity rules and does not create new ones' do
            create(:ai_instance_accessible_entity_rules, through_namespace_id: namespace_a.id)

            expect { result }.to change { Ai::FeatureAccessRule.count }.from(1).to(0)
          end
        end

        context 'when clearing all rules' do
          let(:duo_namespace_access_rules) { [] }

          it 'audits the cleared rules' do
            create(:ai_instance_accessible_entity_rules, through_namespace_id: namespace_a.id)

            expect(::Ai::FeatureAccessRuleAuditor).to receive(:new).with(
              current_user: user,
              rules: duo_namespace_access_rules,
              scope: be_an_instance_of(::Gitlab::Audit::InstanceScope)
            ).and_call_original

            expect { result }.to change { Ai::FeatureAccessRule.count }.from(1).to(0)
          end
        end

        it 'audits the updated rules' do
          expect(::Ai::FeatureAccessRuleAuditor).to receive(:new).with(
            current_user: user,
            rules: duo_namespace_access_rules,
            scope: be_an_instance_of(::Gitlab::Audit::InstanceScope)
          ).and_call_original

          result
        end
      end

      context 'when rules are invalid' do
        let(:duo_namespace_access_rules) do
          [
            { through_namespace: { id: namespace_a.id }, features: %w[invalid_entity] }
          ]
        end

        it 'adds errors to the setting' do
          expect(result).to be false
          expect(Ai::FeatureAccessRule.count).to eq(0)
        end

        it 'does not audit the event' do
          expect(::Ai::FeatureAccessRuleAuditor).not_to receive(:new)

          result
        end
      end
    end

    context 'when default_project_deletion_protection changes', feature_category: :groups_and_projects do
      subject(:execute) { described_class.new(setting, user, { default_project_deletion_protection: }).execute }

      context 'when enabled' do
        let(:default_project_deletion_protection) { true }

        before do
          setting.update!(default_project_deletion_protection: false)
        end

        it 'tracks the event with label "true"' do
          expect { execute }
            .to trigger_internal_events('toggle_deletion_protection_on_admin_area')
            .with(user: user, additional_properties: { label: 'true' })
            .and increment_usage_metrics('counts.count_total_deletion_protection_enabled_on_admin_area')
        end
      end

      context 'when disabled' do
        let(:default_project_deletion_protection) { false }

        before do
          setting.update!(default_project_deletion_protection: true)
        end

        it 'tracks the event with label "false"' do
          expect { execute }
            .to trigger_internal_events('toggle_deletion_protection_on_admin_area')
            .with(user: user, additional_properties: { label: 'false' })
            .and increment_usage_metrics('counts.count_total_deletion_protection_disabled_on_admin_area')
        end
      end

      context 'when not changed' do
        let(:default_project_deletion_protection) { true }

        before do
          setting.update!(default_project_deletion_protection: true)
        end

        it 'does not track the event' do
          expect { execute }
            .not_to trigger_internal_events('toggle_deletion_protection_on_admin_area')
        end
      end
    end
  end
end
