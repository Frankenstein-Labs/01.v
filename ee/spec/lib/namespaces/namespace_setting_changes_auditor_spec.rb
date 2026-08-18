# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::NamespaceSettingChangesAuditor, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

    subject(:auditor) { described_class.new(user, group.namespace_settings, group) }

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
    end

    shared_examples 'audited setting' do
      before do
        group.namespace_settings.update!(column_name => prev_value)
      end

      it 'creates an audit event' do
        group.namespace_settings.update!(column_name => new_value)

        expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
        audit_details = {
          change: column_name,
          from: prev_value,
          to: new_value,
          target_details: group.full_path
        }
        expect(AuditEventReader.last.details).to include(audit_details)
      end

      it 'streams correct audit event stream' do
        group.namespace_settings.update!(column_name => new_value)

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
          described_class::EVENT_NAME_PER_COLUMN[column_name], anything, anything)

        auditor.execute
      end

      context 'when attribute is not changed' do
        it 'does not create an audit event' do
          group.namespace_settings.update!(column_name => prev_value)

          expect { auditor.execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'for experiment_features_enabled' do
      # When experiment_features_enabled changes with duo_features_enabled true (the default),
      # mcp_server_enabled also changes via sync_mcp_server_enabled, producing two audit events.
      before do
        group.namespace_settings.update!(experiment_features_enabled: false)
      end

      it 'creates audit events for experiment_features_enabled and mcp_server_enabled' do
        group.namespace_settings.update!(experiment_features_enabled: true)

        expect { auditor.execute }.to change { AuditEventReader.count }.by(2)
        expect(AuditEventReader.last(2).map { |e| e.details[:change] })
          .to contain_exactly(:experiment_features_enabled, :mcp_server_enabled)
      end

      it 'streams audit events for experiment_features_enabled and mcp_server_enabled' do
        group.namespace_settings.update!(experiment_features_enabled: true)

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
          described_class::EVENT_NAME_PER_COLUMN[:experiment_features_enabled], anything, anything)
        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
          described_class::EVENT_NAME_PER_COLUMN[:mcp_server_enabled], anything, anything)

        auditor.execute
      end

      context 'when attribute is not changed' do
        it 'does not create an audit event' do
          group.namespace_settings.update!(experiment_features_enabled: false)

          expect { auditor.execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'for all columns' do
      where(:column_name, :prev_value, :new_value) do
        :duo_features_enabled | true | false
        :prevent_forking_outside_group | false | true
        :allow_mfa_for_subgroups | false | true
        :default_branch_name | "branch1" | "branch2"
        :resource_access_token_creation_allowed | true | false
        :show_diff_preview_in_email | false | true
        :enabled_git_access_protocol | "all" | "ssh"
        :runner_registration_enabled | false | true
        :allow_runner_registration_token | false | true
        :emails_enabled | false | true
        :service_access_tokens_expiration_enforced | false | true
        :enforce_ssh_certificates | false | true
        :disable_personal_access_tokens | false | true
        :disable_ssh_keys | false | true
        :remove_dormant_members | false | true
        :remove_dormant_members_period | 90 | 100
        :prevent_sharing_groups_outside_hierarchy | false | true
        :duo_remote_flows_enabled | false | true
        :auto_duo_code_review_enabled | false | true
        :force_pages_access_control | false | true
        :duo_foundational_flows_enabled | false | true
        :lock_duo_features_enabled | false | true
        :hide_email_on_profile | false | true
        :enterprise_users_extensions_marketplace_opt_in_status | "disabled" | "enabled"
        :allow_personal_snippets | false | true
      end

      with_them do
        context 'when settings are changed for saas', :saas do
          let_it_be_with_reload(:group) do
            create(:group_with_plan, plan: :ultimate_plan, trial_ends_on: Date.tomorrow)
          end

          let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

          before do
            stub_licensed_features(
              ai_features: true,
              experimental_features: true,
              extended_audit_events: true,
              external_audit_events: true)
            stub_ee_application_setting(should_check_namespace_plan: true)
          end

          it_behaves_like 'audited setting'
        end

        context 'when settings are changed for self-managed' do
          it_behaves_like 'audited setting'
        end
      end
    end

    context 'when attribute is new_user_signup_cap' do
      let(:prev_value) { 0 }
      let(:new_value) { 1 }
      let(:column_name) { :new_user_signups_cap }

      before do
        allow(group).to receive(:user_cap_available?).and_return true
        group.namespace_settings.update!(seat_control: :user_cap, new_user_signups_cap: 0)
      end

      it_behaves_like 'audited setting'
    end

    it 'audits all the columns except the ones denylisted' do
      columns_not_to_audit = %w[
        admin_locked_duo_features_enabled
        allow_enterprise_bypass_placeholder_confirmation
        allow_merge_on_skipped_pipeline
        allow_merge_without_pipeline
        archived
        auto_ban_user_on_excessive_projects_download
        built_in_project_templates_enabled
        created_at
        default_branch_protection_defaults
        default_compliance_framework_id
        disable_invite_members
        duo_nano_features_enabled
        enterprise_bypass_expires_at
        extended_grat_expiry_webhooks_execute
        jobs_to_be_done
        jwt_ci_cd_job_token_enabled
        jwt_ci_cd_job_token_opted_out
        last_dormant_member_review_at
        lock_ai_audit_events_storage_enabled
        lock_auto_duo_code_review_enabled
        lock_built_in_project_templates_enabled
        lock_duo_custom_agents_enabled
        lock_duo_custom_flows_enabled
        lock_duo_external_agents_enabled
        lock_duo_foundational_flows_enabled
        lock_duo_remote_flows_enabled
        lock_math_rendering_limits_enabled
        lock_model_prompt_cache_enabled
        lock_require_sha_for_merge
        lock_resource_access_token_notify_inherited
        lock_spp_repository_pipeline_access
        lock_tool_approval_for_session_enabled
        lock_web_based_commit_signing_enabled
        math_rendering_limits_enabled
        model_prompt_cache_enabled
        namespace_id
        only_allow_merge_if_all_discussions_are_resolved
        only_allow_merge_if_pipeline_succeeds
        pipeline_variables_default_role
        policy_store_experiment_enabled
        product_analytics_enabled
        project_runner_token_expiration_interval
        repository_read_only
        require_dpop_for_manage_api_endpoints
        resource_access_token_notify_inherited
        runner_token_expiration_interval
        security_policies
        setup_for_company
        spp_repository_pipeline_access
        subgroup_runner_token_expiration_interval
        tool_approval_for_session_enabled
        unique_project_download_limit
        unique_project_download_limit_alertlist
        unique_project_download_limit_allowlist
        unique_project_download_limit_interval_in_seconds
        updated_at
        web_based_commit_signing_enabled
        enable_duo_code_review_by_default
        dependency_firewall_enabled
        enterprise_user_settings
      ]

      columns_to_audit = Namespaces::NamespaceSettingChangesAuditor::EVENT_NAME_PER_COLUMN.keys.map(&:to_s)

      expect(NamespaceSetting.columns.map(&:name) - columns_not_to_audit).to match_array(columns_to_audit)
    end
  end
end
