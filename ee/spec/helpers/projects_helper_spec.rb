# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsHelper, feature_category: :shared do
  include ::EE::GeoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:project) { create(:project) }

  before do
    helper.instance_variable_set(:@project, project)
  end

  describe 'default_clone_protocol' do
    context 'when gitlab.config.kerberos is enabled and user is logged in' do
      it 'returns krb5 as default protocol' do
        allow(Gitlab.config.kerberos).to receive(:enabled).and_return(true)
        allow(helper).to receive(:current_user).and_return(double)

        expect(helper.send(:default_clone_protocol)).to eq('krb5')
      end
    end
  end

  describe '#show_no_ssh_key_message?' do
    let_it_be(:group) do
      created_group = create(:group)
      created_group.enforce_ssh_certificates = true
      created_group.save!

      created_group
    end

    let_it_be(:project) { create(:project, group: group) }

    context 'when ssh certificates are enforced' do
      it 'returns false' do
        expect(helper.show_no_ssh_key_message?(project)).to be_falsey
      end
    end
  end

  describe '#show_compliance_frameworks_info?' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: true)
      end

      it 'returns false if compliance framework setting is not present' do
        expect(helper.show_compliance_frameworks_info?(project)).to be_falsey
      end

      it 'returns true if compliance framework setting is present' do
        project = build(:project, :with_compliance_framework)

        expect(helper.show_compliance_frameworks_info?(project)).to be_truthy
      end
    end

    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: false)
      end

      it 'returns false if compliance framework setting is not present' do
        expect(helper.show_compliance_frameworks_info?(project)).to be_falsey
      end

      it 'returns false if compliance framework setting is present' do
        project = build_stubbed(:project, :with_compliance_framework)

        expect(helper.show_compliance_frameworks_info?(project)).to be_falsey
      end
    end
  end

  describe '#compliance_center_path' do
    it 'returns the path to the project security compliance dashboard' do
      expect(helper.compliance_center_path(project))
        .to eq(project_security_compliance_dashboard_path(project, vueroute: "frameworks"))
    end
  end

  describe '#membership_locked?' do
    let(:project) { build_stubbed(:project, group: group) }
    let(:group) { nil }

    context 'when project has no group' do
      let(:project) { Project.new }

      it 'is false' do
        expect(helper).not_to be_membership_locked
      end
    end

    context 'with group_membership_lock enabled' do
      let(:group) { build_stubbed(:group, membership_lock: true) }

      it 'is true' do
        expect(helper).to be_membership_locked
      end
    end

    context 'with global LDAP membership lock enabled' do
      before do
        stub_application_setting(lock_memberships_to_ldap: true)
      end

      context 'and group membership_lock disabled' do
        let(:group) { build_stubbed(:group, membership_lock: false) }

        it 'is true' do
          expect(helper).to be_membership_locked
        end
      end
    end

    context 'with SAML membership lock enabled and group membership_lock disabled' do
      before do
        stub_application_setting(lock_memberships_to_saml: true)
      end

      let(:group) { build_stubbed(:group, membership_lock: false) }

      it 'is true' do
        expect(helper).to be_membership_locked
      end
    end
  end

  describe '#group_project_templates_count' do
    let_it_be(:user) { create(:user) }
    let_it_be(:parent_group) { create(:group, name: 'parent-group') }
    let_it_be(:template_group) { create(:group, parent: parent_group, name: 'template-group') }
    let_it_be_with_reload(:template_project) { create(:project, group: template_group, name: 'template-project') }

    before_all do
      parent_group.update!(custom_project_templates_group_id: template_group.id)
      parent_group.add_owner(user)
    end

    before do
      stub_licensed_features(group_project_templates: true)
      allow(helper).to receive_messages(current_user: user)
    end

    subject(:group_project_templates_count) { helper.group_project_templates_count(parent_group.id) }

    it { is_expected.to eq 1 }

    it 'uses GroupTemplatesFinder' do
      expect(Projects::GroupTemplatesFinder).to receive(:new).with(user, parent_group.id).and_call_original

      group_project_templates_count
    end

    context 'when template project is pending deletion' do
      before do
        template_project.update!(marked_for_deletion_at: Date.current)
      end

      it { is_expected.to eq 0 }
    end

    context 'when template project is archived' do
      before do
        template_project.update!(archived: true)
      end

      it { is_expected.to eq 0 }
    end
  end

  describe '#show_built_in_project_templates_tab?' do
    subject(:show_built_in) { helper.show_built_in_project_templates_tab? }

    context 'when creating a project in a group' do
      let_it_be(:parent_group) { create(:group) }

      before do
        helper.instance_variable_set(:@parent_group, parent_group)
      end

      it 'delegates to the group predicate' do
        expect(parent_group).to receive(:allow_built_in_project_templates?).and_return(false)

        expect(show_built_in).to be false
      end

      it 'returns true when the group allows built-in templates' do
        allow(parent_group).to receive(:allow_built_in_project_templates?).and_return(true)

        expect(show_built_in).to be true
      end
    end

    context 'when creating a personal project (no parent group)' do
      before do
        helper.instance_variable_set(:@parent_group, nil)
      end

      it 'delegates to the application setting predicate' do
        expect(::Gitlab::CurrentSettings.current_application_settings)
          .to receive(:allow_instance_built_in_project_templates?).and_return(false)

        expect(show_built_in).to be false
      end

      it 'returns true when the instance allows built-in templates' do
        allow(::Gitlab::CurrentSettings.current_application_settings)
          .to receive(:allow_instance_built_in_project_templates?).and_return(true)

        expect(show_built_in).to be true
      end
    end
  end

  describe '#project_template_tab_state' do
    using RSpec::Parameterized::TableSyntax

    subject(:tab_state) { helper.project_template_tab_state }

    before do
      allow(helper).to receive_messages(
        show_built_in_project_templates_tab?: show_built_in,
        params: { tab: tab_param }
      )
      allow(::Gitlab::Saas).to receive(:feature_available?)
        .with(:hide_project_instance_tab).and_return(hide_instance)
    end

    # rubocop:disable Layout/LineLength -- Readability of the table is preferred
    where(:show_built_in, :hide_instance, :tab_param, :expected) do
      true  | false | nil     | { show_built_in: true,  show_instance: true,  activate_group: false, activate_built_in: true,  activate_instance: false }
      false | false | nil     | { show_built_in: false, show_instance: true,  activate_group: false, activate_built_in: false, activate_instance: true }
      true  | true  | nil     | { show_built_in: true,  show_instance: false, activate_group: false, activate_built_in: true,  activate_instance: false }
      false | true  | nil     | { show_built_in: false, show_instance: false, activate_group: true,  activate_built_in: false, activate_instance: false }
      true  | false | 'group' | { show_built_in: true,  show_instance: true,  activate_group: true,  activate_built_in: false, activate_instance: false }
      false | false | 'group' | { show_built_in: false, show_instance: true,  activate_group: true,  activate_built_in: false, activate_instance: false }
    end
    # rubocop:enable Layout/LineLength

    with_them do
      it { is_expected.to eq(expected) }
    end
  end

  describe '#project_security_dashboard_config' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, group: group) }
    let_it_be(:jira_integration) do
      create(:jira_integration, project: project, vulnerabilities_enabled: true,
        project_key: 'GV', vulnerabilities_issuetype: '10000')
    end

    let_it_be(:dismissal_descriptions_json) do
      Gitlab::Json.parse(fixture_file('vulnerabilities/dismissal_descriptions.json', dir: 'ee')).to_json
    end

    subject(:config) { helper.project_security_dashboard_config(project) }

    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(jira_vulnerabilities_integration: true)
      allow(helper).to receive_messages(current_user: user, can?: true)

      allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?)
        .with(project)
        .and_return(false)
    end

    context 'for project with third party offers hidden' do
      before do
        allow(::Gitlab::CurrentSettings.current_application_settings)
          .to receive(:hide_third_party_offers?).and_return(true)
      end

      it { is_expected.to include(hide_third_party_offers: 'true') }
    end

    context 'for project without vulnerabilities' do
      let(:expected_value) do
        {
          has_vulnerabilities: 'false',
          has_jira_vulnerabilities_integration_enabled: 'true',
          empty_state_svg_path: start_with('/assets/illustrations/empty-state/empty-secure-md'),
          operational_configuration_path: new_project_security_policy_path(project),
          project_security_vulnerabilities_path: helper.project_security_vulnerability_report_index_path(project),
          security_dashboard_empty_svg_path: start_with('/assets/illustrations/empty-state/empty-secure-md'),
          project: { id: project.id, name: project.name },
          project_full_path: project.full_path,
          project_public: 'false',
          no_vulnerabilities_svg_path: start_with('/assets/illustrations/empty-state/empty-search-md-'),
          security_configuration_path: end_with('/configuration'),
          can_admin_vulnerability: 'true',
          new_vulnerability_path: end_with('/security/vulnerabilities/new'),
          dismissal_descriptions: dismissal_descriptions_json,
          hide_third_party_offers: 'false',
          show_retention_alert: 'false'
        }
      end

      it { is_expected.to match(expected_value) }
    end

    context 'for project with vulnerabilities' do
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let(:scanner) { vulnerability.vulnerability_finding.scanner }

      let(:base_values) do
        vulnerabilities_export = "/api/v4/security/projects/#{project.id}/vulnerability_exports"

        {
          has_vulnerabilities: 'true',
          has_jira_vulnerabilities_integration_enabled: 'true',
          project: { id: project.id, name: project.name },
          project_full_path: project.full_path,
          project_public: 'false',
          vulnerabilities_export_endpoint: vulnerabilities_export,
          vulnerabilities_pdf_export_endpoint: "#{vulnerabilities_export}?export_format=pdf",
          no_vulnerabilities_svg_path: start_with('/assets/illustrations/empty-state/empty-search-md-'),
          empty_state_svg_path: start_with('/assets/illustrations/empty-state/empty-secure-md'),
          operational_configuration_path: new_project_security_policy_path(project),
          security_dashboard_empty_svg_path: start_with('/assets/illustrations/empty-state/empty-secure-md'),
          project_security_vulnerabilities_path: helper.project_security_vulnerability_report_index_path(project),
          new_project_pipeline_path: "/#{project.full_path}/-/pipelines/new",
          scanners: [{
            id: scanner.id,
            vendor: scanner.vendor,
            report_type: vulnerability.report_type.upcase,
            name: scanner.name,
            external_id: scanner.external_id
          }].to_json,
          can_admin_vulnerability: 'true',
          can_view_false_positive: 'false',
          security_configuration_path: kind_of(String),
          new_vulnerability_path: end_with('/security/vulnerabilities/new'),
          dismissal_descriptions: dismissal_descriptions_json,
          hide_third_party_offers: 'false',
          show_retention_alert: 'false',
          vulnerability_quota: {
            critical: 'true',
            exceeded: 'false',
            full: 'false'
          },
          validity_checks_enabled: 'false',
          manage_duo_settings_path: "/#{project.full_path}/edit#js-gitlab-duo-settings",
          experiment_features_enabled: 'false',
          duo_agent_platform_available: 'false',
          duo_sast_fp_detection_enabled: 'false'
        }
      end

      before do
        allow(project.vulnerability_quota).to receive(:critical?).and_return(true)
      end

      context 'with related_url_root set' do
        let(:relative_url) { '/gitlab' }
        let(:expected_path) { "#{relative_url}/api/v4/security/projects/#{project.id}/vulnerability_exports" }
        let(:expected_value) do
          base_values.merge(
            vulnerabilities_export_endpoint: expected_path,
            vulnerabilities_pdf_export_endpoint: "#{expected_path}?export_format=pdf"
          )
        end

        before do
          stub_config_setting(relative_url_root: relative_url)
        end

        it { is_expected.to match(expected_value) }
      end

      context 'without pipeline' do
        before do
          allow(project).to receive(:latest_ingested_security_pipeline).and_return(nil)
        end

        it { is_expected.to match(base_values) }
      end

      context 'when experiment features enabled' do
        before do
          allow(project.root_ancestor)
            .to receive(:experiment_features_enabled)
                  .and_return(true)
        end

        it 'sets the experiment_features_enabled to true' do
          expect(config[:experiment_features_enabled]).to eq('true')
        end
      end

      context 'when SAST false positive detection is enabled for the project' do
        before do
          allow(project).to receive(:duo_sast_fp_detection_enabled).and_return(true)
        end

        it 'sets duo_sast_fp_detection_enabled to true' do
          expect(config[:duo_sast_fp_detection_enabled]).to eq('true')
        end
      end

      context 'with security pipeline' do
        let(:pipeline_created_at) { '1881-05-19T00:00:00Z' }
        let(:pipeline) { build_stubbed(:ci_pipeline, project: project, created_at: pipeline_created_at) }
        let(:pipeline_values) do
          {
            pipeline: {
              id: pipeline.id,
              path: "/#{project.full_path}/-/pipelines/#{pipeline.id}",
              created_at: pipeline_created_at,
              has_warnings: 'true',
              has_errors: 'false',
              security_builds: {
                failed: {
                  count: 0,
                  path: "/#{project.full_path}/-/pipelines/#{pipeline.id}/failures"
                }
              }
            }
          }
        end

        before do
          allow(project)
            .to receive_messages(latest_ingested_security_pipeline: pipeline, latest_ingested_sbom_pipeline: nil)
          allow(pipeline).to receive_messages(
            has_security_report_ingestion_warnings?: true,
            has_security_report_ingestion_errors?: false
          )
        end

        it { is_expected.to match(base_values.merge!(pipeline_values)) }

        context 'with sbom pipeline' do
          let(:sbom_pipeline_created_at) { '1981-07-19T00:00:00Z' }
          let(:sbom_pipeline) { build_stubbed(:ci_pipeline, project: project, created_at: sbom_pipeline_created_at) }
          let(:sbom_pipeline_values) do
            {
              sbom_pipeline: {
                id: sbom_pipeline.id,
                path: "/#{project.full_path}/-/pipelines/#{sbom_pipeline.id}",
                created_at: sbom_pipeline_created_at,
                has_warnings: '',
                has_errors: 'true'
              }
            }
          end

          before do
            allow(project).to receive(:latest_ingested_sbom_pipeline).and_return(sbom_pipeline)
            allow(sbom_pipeline).to receive(:has_sbom_report_ingestion_errors?).and_return(true)
          end

          it { is_expected.to match(base_values.merge(sbom_pipeline_values, pipeline_values)) }
        end
      end

      context 'with validity checks configuration' do
        context 'when project has validity checks enabled' do
          before do
            security_setting = instance_double(ProjectSecuritySetting, validity_checks_enabled: true)
            allow(project).to receive(:security_setting).and_return(security_setting)
          end

          it { is_expected.to include(validity_checks_enabled: 'true') }
        end

        context 'when project has validity checks disabled' do
          before do
            security_setting = instance_double(ProjectSecuritySetting, validity_checks_enabled: false)
            allow(project).to receive(:security_setting).and_return(security_setting)
          end

          it { is_expected.to include(validity_checks_enabled: 'false') }
        end

        context 'when project has no security setting' do
          before do
            allow(project).to receive(:security_setting).and_return(nil)
          end

          it { is_expected.to include(validity_checks_enabled: 'false') }
        end
      end

      context 'with default branch context' do
        let_it_be(:default_branch_context) do
          create(
            :security_project_tracked_context,
            :default,
            project: project,
            context_name: project.default_branch_or_main,
            context_type: :branch
          )
        end

        it 'sets expected data for default_branch_context' do
          context_data = Gitlab::Json.parse(config[:default_branch_context])

          expect(context_data).to include(
            'id' => default_branch_context.id.to_s,
            'name' => default_branch_context.context_name,
            'ref_type' => default_branch_context.context_type
          )
        end

        context 'when vulnerabilities_across_contexts feature flag is disabled' do
          before do
            stub_feature_flags(vulnerabilities_across_contexts: false)
          end

          it { is_expected.not_to include(:default_branch_context) }
        end
      end

      context 'when root_ancestor is nil' do
        before do
          allow(project).to receive(:root_ancestor).and_return(nil)
        end

        it 'returns false for experiment_features_enabled' do
          expect(config[:experiment_features_enabled]).to eq('false')
        end
      end
    end
  end

  describe '#show_discover_project_security?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }

    where(
      gitlab_com?: [true, false],
      user?: [true, false],
      security_dashboard_feature_available?: [true, false],
      can_admin_namespace?: [true, false]
    )

    with_them do
      it 'returns the expected value' do
        allow(::Gitlab).to receive(:com?) { gitlab_com? }
        allow(helper).to receive(:current_user) { user? ? user : nil }
        allow(project).to receive(:feature_available?) { security_dashboard_feature_available? }
        allow(helper).to receive(:can?) { can_admin_namespace? }

        expected_value = user? && gitlab_com? && !security_dashboard_feature_available? && can_admin_namespace?

        expect(helper.show_discover_project_security?(project)).to eq(expected_value)
      end
    end
  end

  describe '#project_permissions_settings' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_application_setting(spp_repository_pipeline_access: false, lock_spp_repository_pipeline_access: false)
    end

    let(:expected_settings) do
      { requirementsAccessLevel: 20, securityAndComplianceAccessLevel: 10 }
    end

    subject { helper.project_permissions_settings(project) }

    it { is_expected.to include(expected_settings) }

    context 'for cveIdRequestEnabled' do
      where(:project_attrs, :expected) do
        [:public]   | true
        [:internal] | false
        [:private]  | false
      end

      with_them do
        let(:project) { create(:project, :with_cve_request, *project_attrs) }
        subject(:settings) { helper.project_permissions_settings(project) }

        it 'has the correct cveIdRequestEnabled value' do
          expect(settings[:cveIdRequestEnabled]).to eq(expected)
        end
      end
    end

    describe 'sppRepositoryPipelineAccess' do
      it { is_expected.to include(sppRepositoryPipelineAccess: true) }

      context 'when the setting is disabled' do
        before do
          project.project_setting.update!(spp_repository_pipeline_access: false)
        end

        it { is_expected.to include(sppRepositoryPipelineAccess: false) }
      end
    end

    describe 'pipelineExecutionPolicyBotAccessEnabled' do
      it { is_expected.to include(pipelineExecutionPolicyBotAccessEnabled: false) }

      context 'when the setting is enabled' do
        before do
          project.project_setting.update!(pipeline_execution_policy_bot_access_enabled: true)
        end

        it { is_expected.to include(pipelineExecutionPolicyBotAccessEnabled: true) }
      end
    end

    describe 'pipelineExecutionPolicyBotAccessFilePatterns' do
      it { is_expected.to include(pipelineExecutionPolicyBotAccessFilePatterns: []) }

      context 'when patterns are set' do
        before do
          project.project_setting.update!(
            pipeline_execution_policy_bot_access_enabled: true,
            pipeline_execution_policy_bot_access_file_patterns: ['ci/**/*.yml']
          )
        end

        it { is_expected.to include(pipelineExecutionPolicyBotAccessFilePatterns: ['ci/**/*.yml']) }
      end
    end
  end

  describe '#project_permissions_panel_data' do
    using RSpec::Parameterized::TableSyntax

    # A real record rather than a double: the readiness gate checks a feature flag with the
    # user as the actor, which needs a flipper_id.
    let(:user) { build_stubbed(:user) }
    let(:expected_data) do
      { requirementsAvailable: false, sppRepositoryPipelineAccessLocked: false, policySettingsAvailable: false }
    end

    subject(:data) { helper.project_permissions_panel_data(project) }

    before do
      allow(helper).to receive_messages(current_user: user, can?: false)
    end

    it { is_expected.to include(expected_data) }

    context "if in Gitlab.com" do
      where(is_gitlab_com: [true, false])
      with_them do
        before do
          allow(Gitlab).to receive(:com?).and_return(is_gitlab_com)
        end

        it 'sets requestCveAvailable to the correct value' do
          expect(data[:requestCveAvailable]).to eq(is_gitlab_com)
        end
      end
    end

    describe 'policy settings' do
      describe 'policySettingsAvailable' do
        where(:licensed_feature, :policy_project_exists, :result) do
          true  | true  | true
          true  | false | false
          false | true  | false
          false | false | false
        end

        with_them do
          before do
            stub_licensed_features(security_orchestration_policies: licensed_feature)
            allow(::Security::OrchestrationPolicyConfiguration)
              .to receive(:policy_management_project?).with(project).and_return(policy_project_exists)
          end

          it { is_expected.to include(policySettingsAvailable: result) }
        end
      end

      context 'when sppRepositoryPipelineAccessLocked is locked' do
        before do
          stub_application_setting(lock_spp_repository_pipeline_access: true)
        end

        it { is_expected.to include(sppRepositoryPipelineAccessLocked: true) }
      end

      describe 'botAccessSettingsAvailable' do
        context 'when not licensed' do
          it { is_expected.to include(botAccessSettingsAvailable: false) }
          it { is_expected.not_to include(:botAccessGroupId) }
          it { is_expected.not_to include(:botAccessRootGroupId) }
        end

        context 'when licensed' do
          before do
            stub_licensed_features(security_orchestration_policies: true)
          end

          it { is_expected.to include(botAccessSettingsAvailable: true) }
          it { is_expected.to include(:botAccessGroupId) }
          it { is_expected.to include(:botAccessRootGroupId) }

          describe 'botAccessGroupId' do
            it { is_expected.to include(botAccessGroupId: nil) }

            context 'when a group is set' do
              let_it_be(:group) { create(:group) }

              before do
                project.project_setting.update!(pipeline_execution_policy_bot_access_group_id: group.id)
              end

              it { is_expected.to include(botAccessGroupId: group.id) }
            end
          end

          describe 'botAccessRootGroupId' do
            context 'when project is in a group' do
              let_it_be(:group) { create(:group) }
              let_it_be(:project) { create(:project, group: group) }

              it { is_expected.to include(botAccessRootGroupId: group.id) }
            end

            context 'when project is in a personal namespace' do
              let_it_be(:project) { create(:project, :in_user_namespace) }

              it { is_expected.to include(botAccessRootGroupId: nil) }
            end
          end
        end
      end
    end

    describe 'Secrets Manager settings' do
      it { is_expected.to include(projectId: project.id) }

      describe 'topLevelGroupFullPath' do
        context 'when project belongs to a group' do
          let_it_be(:group) { create(:group) }
          let_it_be(:project) { create(:project, group: group) }

          it { is_expected.to include(topLevelGroupFullPath: group.full_path) }
        end

        context 'when project belongs to a personal namespace' do
          let_it_be(:project) { create(:project, :in_user_namespace) }

          it { is_expected.to include(topLevelGroupFullPath: '') }
        end
      end

      describe 'isSecretsManagerAvailable' do
        # Availability AND combinations (license + FF + enrollment) are covered
        # in availability_spec.rb. Here we just verify the helper key reflects
        # the combination of Availability and the :read_project_secrets_manager
        # policy check (which also gates entitlement state, e.g. trial_eligible).
        where(:available, :can_read, :expected) do
          [
            [true,  true,  true],
            [true,  false, false],
            [false, true,  false],
            [false, false, false]
          ]
        end

        with_them do
          before do
            allow(SecretsManagement::Availability).to receive(:for_project?)
              .with(project).and_return(available)
            allow(helper).to receive(:can?).with(user, :read_project_secrets_manager, project)
              .and_return(can_read)
          end

          it { is_expected.to include(isSecretsManagerAvailable: expected) }
        end
      end

      describe 'canManageSecretsManager' do
        before do
          stub_feature_flags(secrets_manager: true)
          stub_licensed_features(native_secrets_management: true)
        end

        context 'when current user is authorized to manage the secrets manager' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_project_secrets_manager, project).and_return(true)
          end

          it { is_expected.to include(canManageSecretsManager: true) }
        end

        context 'when current user is not authorized to manage the secrets manager' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_project_secrets_manager, project).and_return(false)
          end

          it { is_expected.to include(canManageSecretsManager: false) }
        end
      end
    end
  end

  describe '#gitlab_duo_settings_data' do
    # A real record rather than a double: the readiness gate checks a feature flag with the
    # user as the actor, which needs a flipper_id.
    let(:user) { build_stubbed(:user) }
    let(:expected_data) do
      { duoFeaturesEnabled: true,
        licensedAiFeaturesAvailable: false,
        duoFeaturesLocked: false,
        initialDuoRemoteFlowsAvailability: true,
        initialDuoFoundationalFlowsAvailability: true,
        initialDuoSastFalsePositiveDetectionEnabled: false,
        initialDuoSastVrWorkflowEnabled: false,
        ultimateFeaturesAvailable: false,
        initialToolApprovalForSessionEnabled: false,
        toolApprovalForSessionLocked: false,
        dapSessionTrackingAvailable: false,
        initialDapSessionTrackingEnabled: false,
        duoReadinessAvailable: true,
        duoOrbit: {},
        duoMcp: {},
        visibleSettings: [] }
    end

    subject(:data) { helper.gitlab_duo_settings_data(project) }

    before do
      allow(helper).to receive_messages(current_user: user, can?: false)
    end

    it { is_expected.to include(expected_data) }

    describe 'duoReadiness' do
      before do
        allow(helper).to receive(:can?).with(user, :update_duo_setting, project).and_return(true)
      end

      context 'when the feature flag is off' do
        before do
          stub_feature_flags(duo_agent_readiness_settings: false)
        end

        it 'is skipped, so the settings page pays for none of the readiness reads' do
          expect(::Ai::DuoWorkflow::ProjectReadiness).not_to receive(:new)

          expect(data[:duoReadinessAvailable]).to be(false)
          expect(data[:duoReadiness]).to eq({})
        end
      end

      context 'when the user cannot configure Duo settings' do
        before do
          allow(helper).to receive(:can?).with(user, :update_duo_setting, project).and_return(false)
        end

        it 'is skipped' do
          expect(::Ai::DuoWorkflow::ProjectReadiness).not_to receive(:new)

          expect(data[:duoReadiness]).to eq({})
        end
      end

      context 'when Amazon Q is connected in place of Duo' do
        before do
          allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
        end

        it 'is skipped' do
          expect(::Ai::DuoWorkflow::ProjectReadiness).not_to receive(:new)

          expect(data[:duoReadiness]).to eq({})
        end
      end

      context 'when the card will render' do
        it 'exposes the state and paths the status rows need' do
          expect(data[:duoReadinessAvailable]).to be(true)
          expect(data[:duoReadiness])
            .to include(:platformEnabled, :isSaas, :groupSettingsPath, :adminSettingsPath,
              :runnerAvailable, :usableRunnerType, :runnersPath)
        end

        # The client appends ?tab= from usableRunnerType.
        it 'points at the runners settings section without picking a tab' do
          expect(data[:duoReadiness][:runnersPath])
            .to eq("/#{project.full_path}/-/settings/ci_cd#js-runners-settings")
        end
      end

      # Per the design, only the feature flag gates the card; the platform state is what it reports.
      context 'when the Agent Platform is off above the project' do
        before do
          allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?)
            .with(project).and_return(false)
        end

        it 'keeps the card available and reports the platform as off' do
          expect(data[:duoReadinessAvailable]).to be(true)
          expect(data[:duoReadiness]).to include(platformEnabled: false)
        end
      end
    end

    describe 'duoOrbit' do
      let_it_be(:orbit_root_group) { create(:group) }
      let_it_be(:orbit_project) { create(:project, group: orbit_root_group) }

      let(:project) { orbit_project }

      context 'when the readiness feature flag is off' do
        before do
          stub_feature_flags(duo_agent_readiness_settings: false)
        end

        it 'is empty' do
          expect(data[:duoOrbit]).to eq({})
        end
      end

      context 'when the card will render' do
        context 'when the knowledge graph is not available for the user' do
          before do
            allow(::Analytics::KnowledgeGraph).to receive(:enabled_for?).with(user).and_return(false)
          end

          it 'is empty' do
            expect(data[:duoOrbit]).to eq({})
          end
        end

        context 'when the knowledge graph is available' do
          before do
            allow(::Analytics::KnowledgeGraph).to receive(:enabled_for?).with(user).and_return(true)
            stub_licensed_features(orbit: true)
          end

          context 'for a personal project' do
            let_it_be(:personal_project) { create(:project) }

            let(:project) { personal_project }

            it 'is empty, because Orbit is enabled per root group' do
              expect(data[:duoOrbit]).to eq({})
            end
          end

          context 'when the root group has no Orbit license' do
            before do
              stub_licensed_features(orbit: false)
            end

            it 'is empty' do
              expect(data[:duoOrbit]).to eq({})
            end
          end

          context 'when the root group can not enroll and is not enrolled' do
            before do
              stub_feature_flags(orbit_enroll_namespace: false)
            end

            it 'is empty' do
              expect(data[:duoOrbit]).to eq({})
            end
          end

          it 'exposes the state for the Orbit row' do
            expect(data[:duoOrbit]).to eq(
              enabled: false,
              canEnable: false,
              rootGroupPath: orbit_root_group.full_path,
              graphPath: dashboard_orbit_path
            )
          end

          it 'reports an enabled root namespace' do
            allow(project).to receive(:knowledge_graph_indexing_enabled?).and_return(true)

            expect(data[:duoOrbit][:enabled]).to be(true)
          end

          context 'when the user can update the root group knowledge-graph setting' do
            before do
              allow(helper).to receive(:can?)
                .with(user, :update_knowledge_graph_setting, orbit_root_group).and_return(true)
            end

            it 'allows enabling from the row' do
              expect(data[:duoOrbit][:canEnable]).to be(true)
            end
          end
        end
      end
    end

    describe 'duoMcp' do
      context 'when the readiness feature flag is off' do
        before do
          stub_feature_flags(duo_agent_readiness_settings: false)
        end

        it 'is empty' do
          expect(data[:duoMcp]).to eq({})
        end
      end

      context 'when the card will render' do
        it 'is empty when the user cannot read MCP servers' do
          expect(data[:duoMcp]).to eq({})
        end

        context 'when the user can read MCP servers' do
          before do
            allow(helper).to receive(:can?)
              .with(user, :read_ai_catalog_mcp_server, project).and_return(true)
          end

          it 'exposes a zero count when no configured agent uses an MCP server' do
            create(:ai_catalog_mcp_server, organization: project.organization)

            expect(data[:duoMcp]).to eq(
              serversCount: 0,
              serversPath: project_automate_mcp_servers_path(project)
            )
          end

          context 'when configured agents use MCP servers' do
            let_it_be(:mcp_root_group, freeze: false) { create(:group) }
            let_it_be(:mcp_project) { create(:project, group: mcp_root_group) }
            let_it_be(:organization) { mcp_project.organization }
            let_it_be(:server) { create(:ai_catalog_mcp_server, organization: organization) }
            let_it_be(:shared_server) { create(:ai_catalog_mcp_server, organization: organization) }

            let(:project) { mcp_project }
            let(:user) { create(:user, organizations: [organization]) }

            before_all do
              create(:ai_catalog_mcp_server, organization: organization)

              [[server.id, shared_server.id], [shared_server.id]].each do |server_ids|
                agent = create(:ai_catalog_agent, organization: organization)
                create(:ai_catalog_agent_version, item: agent, definition: {
                  'system_prompt' => 'Test prompt',
                  'tools' => [],
                  'user_prompt' => '',
                  'mcp_servers' => server_ids
                })
                create(:ai_catalog_item_consumer, project: mcp_project, item: agent)
              end

              mcp_root_group.namespace_settings.update!(duo_custom_agents_enabled: true)
            end

            before do
              allow(Ability).to receive(:allowed?).and_call_original
              allow(Ability).to receive(:allowed?)
                .with(user, :read_ai_catalog_item_consumer, mcp_project).and_return(true)
              allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
            end

            it 'counts each server of the configured agents once' do
              expect(data[:duoMcp][:serversCount]).to eq(2)
            end

            it 'does not run a query per configured agent' do
              control = ActiveRecord::QueryRecorder.new do
                helper.send(:duo_mcp_servers_count, mcp_project)
              end

              [[server.id], [shared_server.id]].each do |server_ids|
                agent = create(:ai_catalog_agent, organization: organization)
                create(:ai_catalog_agent_version, item: agent, definition: {
                  'system_prompt' => 'Test prompt',
                  'tools' => [],
                  'user_prompt' => '',
                  'mcp_servers' => server_ids
                })
                create(:ai_catalog_item_consumer, project: mcp_project, item: agent)
              end

              expect do
                helper.send(:duo_mcp_servers_count, mcp_project)
              end.not_to exceed_query_limit(control)
            end
          end
        end
      end
    end

    describe 'visibleSettings' do
      context 'when the user can update Duo settings' do
        before do
          allow(helper).to receive(:can?).with(user, :update_duo_setting, project).and_return(true)
        end

        it "is ['all'] so every Duo setting is shown" do
          expect(data[:visibleSettings]).to eq(['all'])
        end
      end

      context 'when the user can update sec AI workflow settings' do
        before do
          allow(helper).to receive(:can?).with(user, :update_duo_setting, project).and_return(false)
          allow(helper).to receive(:can?)
            .with(user, :update_sec_ai_workflow_settings, project).and_return(true)
        end

        context 'when both feature flags are enabled' do
          before do
            stub_feature_flags(
              update_sast_vr_setting_permission: project,
              update_false_positive_detection_setting_permission: project
            )
          end

          it 'includes all sec AI workflow settings' do
            expect(data[:visibleSettings]).to eq(%w[duoSastVrWorkflowEnabled duoSastFalsePositiveDetectionEnabled
              duoSecretDetectionFpEnabled])
          end
        end

        context 'when only the SAST VR feature flag is enabled' do
          before do
            stub_feature_flags(
              update_sast_vr_setting_permission: project,
              update_false_positive_detection_setting_permission: false
            )
          end

          it 'includes only the SAST VR setting' do
            expect(data[:visibleSettings]).to eq(%w[duoSastVrWorkflowEnabled])
          end
        end

        context 'when only the FP detection feature flag is enabled' do
          before do
            stub_feature_flags(
              update_sast_vr_setting_permission: false,
              update_false_positive_detection_setting_permission: project
            )
          end

          it 'includes only the FP detection settings' do
            expect(data[:visibleSettings]).to eq(%w[duoSastFalsePositiveDetectionEnabled duoSecretDetectionFpEnabled])
          end
        end
      end

      context 'when the user has neither permission' do
        it 'is empty' do
          expect(data[:visibleSettings]).to eq([])
        end
      end
    end

    describe 'duoReadinessAvailable' do
      before do
        stub_feature_flags(duo_agent_readiness_settings: true)
        allow(helper).to receive(:can?).with(user, :update_duo_setting, project).and_return(true)
      end

      it { is_expected.to include(duoReadinessAvailable: true) }

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(duo_agent_readiness_settings: false)
        end

        it { is_expected.to include(duoReadinessAvailable: false) }
      end

      context 'when the Agent Platform is not available for the project' do
        before do
          allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(project).and_return(false)
        end

        it 'stays available, so the card can report the platform as the missing prerequisite' do
          expect(data).to include(duoReadinessAvailable: true)
          expect(data[:duoReadiness]).to include(platformEnabled: false)
        end
      end

      context 'when Duo is turned off for the project' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        it 'stays available, so the card can offer to turn Duo back on' do
          expect(data).to include(duoReadinessAvailable: true)
        end
      end
    end

    context 'when root ancestor has :ai_features license' do
      before do
        allow(project.root_ancestor).to receive(:licensed_feature_available?).with(:ai_features).and_return(true)
      end

      it 'includes ultimateFeaturesAvailable as true' do
        expect(data[:ultimateFeaturesAvailable]).to be(true)
      end
    end

    context 'when root ancestor does not have :ai_features license' do
      before do
        allow(project.root_ancestor).to receive(:licensed_feature_available?).with(:ai_features).and_return(false)
      end

      it 'includes ultimateFeaturesAvailable as false' do
        expect(data[:ultimateFeaturesAvailable]).to be(false)
      end
    end

    context "if AmazonQ is connected" do
      let_it_be(:integration, freeze: false) { create(:amazon_q_integration, instance: false, project: project) }

      where(
        connected: [true, false],
        auto_review_enabled: [true, false]
      )
      with_them do
        before do
          allow(::Ai::AmazonQ).to receive(:connected?).and_return(connected)
          integration.update!(auto_review_enabled: auto_review_enabled)
        end

        it 'sets amazonQAvailable to the correct value' do
          expect(data[:amazonQAvailable]).to eq(connected)
          expect(data[:amazonQAutoReviewEnabled]).to eq(auto_review_enabled)
        end
      end
    end
  end

  describe '#approvals_app_data' do
    subject(:data) { helper.approvals_app_data(project) }

    let(:user) { instance_double(User, can_admin_all_resources?: false) }

    before do
      allow(helper).to receive_messages(current_user: user, can?: true, saml_provider_enabled_for_project?: true)
    end

    it 'returns the correct data' do
      expect(data).to include(
        project_id: project.id,
        can_edit: 'true',
        can_modify_author_settings: 'true',
        can_modify_commiter_settings: 'true',
        can_read_security_policies: 'true',
        saml_provider_enabled: 'true',
        approvals_path: expose_path(api_v4_projects_merge_request_approval_setting_path(id: project.id)),
        project_path: expose_path(api_v4_projects_path(id: project.id)),
        rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
        allow_multi_rule: project.multiple_approval_rules_available?.to_s,
        eligible_approvers_docs_path:
          help_page_path('user/project/merge_requests/approvals/rules.md', anchor: 'eligible-approvers'),
        security_configuration_path: project_security_configuration_path(project),
        coverage_check_help_page_path:
          help_page_path('ci/testing/code_coverage/coverage_reporting.md',
            anchor: 'add-a-coverage-check-approval-rule'),
        group_name: project.root_ancestor.name,
        full_path: project.full_path,
        new_policy_path: expose_path(new_project_security_policy_path(project))
      )
    end
  end

  describe '#status_checks_app_data' do
    subject(:data) { helper.status_checks_app_data(project) }

    it 'returns the correct data' do
      expect(data[:data]).to eq({
        project_id: project.id,
        status_checks_path: expose_path(api_v4_projects_external_status_checks_path(id: project.id))
      })
    end
  end

  describe '#remote_mirror_setting_enabled?' do
    context 'when ci_cd_projects licensed feature is enabled' do
      before do
        stub_licensed_features(ci_cd_projects: true)
      end

      context 'when there are import sources' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:import_sources).and_return(["gitlab"])
        end

        context 'when application setting mirror_available is enabled' do
          before do
            stub_application_setting(mirror_available: true)
          end

          it 'is true' do
            expect(helper.remote_mirror_setting_enabled?).to be_truthy
          end
        end

        context 'when application setting mirror_available is disabled' do
          let_it_be(:user) { create(:user) }

          before do
            allow(helper).to receive(:current_user).and_return(user)
            stub_application_setting(mirror_available: false)
          end

          context 'when mirror is not available but user is admin' do
            before do
              allow(user).to receive(:can_admin_all_resources?).and_return(true)
            end

            it 'is true' do
              expect(helper.remote_mirror_setting_enabled?).to be_truthy
            end
          end

          context 'when mirror is not available and user is not admin' do
            it 'is false' do
              expect(helper.remote_mirror_setting_enabled?).to be_falsey
            end
          end
        end
      end
    end

    context 'when ci_cd_projects licensed feature is disabled' do
      before do
        stub_licensed_features(ci_cd_projects: false)
      end

      it 'is false' do
        expect(helper.remote_mirror_setting_enabled?).to be_falsey
      end
    end
  end

  describe '#http_clone_url_to_repo' do
    let(:geo_url) { 'http://localhost/geonode_url' }
    let(:geo_node) { instance_double(GeoNode, url: geo_url) }

    subject(:url) { helper.http_clone_url_to_repo(project) }

    before do
      stub_proxied_site(geo_node)

      allow(helper).to receive(:geo_proxied_http_url_to_repo).with(geo_node, project).and_return(geo_url)
    end

    it { expect(url).to eq geo_url }
  end

  describe '#ssh_clone_url_to_repo' do
    let(:geo_url) { 'git@localhost/geonode_url' }
    let(:geo_node) { instance_double(GeoNode, url: geo_url) }

    subject(:url) { helper.ssh_clone_url_to_repo(project) }

    before do
      stub_proxied_site(geo_node)

      allow(helper).to receive(:geo_proxied_ssh_url_to_repo).with(geo_node, project).and_return(geo_url)
    end

    it { expect(url).to eq geo_url }
  end

  describe '#project_transfer_app_data' do
    it 'returns expected hash' do
      expect(helper.project_transfer_app_data(project)).to eq({
        full_path: project.full_path
      })
    end
  end

  describe '#compliance_framework_data_attributes' do
    let_it_be(:user) { create(:user) }

    where(:custom_compliance_frameworks, :compliance_framework, :has_framework, :color, :name, :description,
      :expected) do
      true  | true  | true    | "#FF0000" | "Framework 1"   | "New framework" | ref(:data_attributes)
      false | true  | true    | "#00FF00" | "Framework 2"   | "Another framework" | {}
      true  | false | false   | nil | nil | nil | {}
      false | false | false   | nil | nil | nil | {}
    end

    with_them do
      before do
        stub_licensed_features(
          custom_compliance_frameworks: custom_compliance_frameworks,
          compliance_framework: compliance_framework)

        if has_framework
          framework = create(:compliance_framework,
            color: color,
            name: name,
            description: description
          )
          create(:compliance_framework_project_setting,
            project: project, compliance_management_framework: framework)
        end

        allow(helper).to receive(:current_user).and_return(user)
      end

      let(:data_attributes) do
        {
          has_compliance_framework_feature: compliance_framework.to_s,
          frameworks: [{
            compliance_framework_badge_color: color,
            compliance_framework_badge_name: name,
            compliance_framework_badge_title: description
          }]
        }
      end

      subject { helper.compliance_framework_data_attributes(project) }

      it { is_expected.to eq(expected) }
    end
  end

  describe '#pages_deployments_usage_quota_data' do
    let_it_be(:group) { create(:group) }
    let(:project) { create(:project, namespace: group) }
    let(:project2) { create(:project, namespace: group) }

    before do
      project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 100)
      project2.project_setting.update!(pages_unique_domain_enabled: false)
      create(:pages_deployment, project: project, path_prefix: '/foo')
      create(:pages_deployment, project: project2, path_prefix: '/foo')
    end

    context 'when project has unique domain enabled' do
      before do
        project.project_setting.update!(pages_unique_domain_enabled: true, pages_unique_domain: 'foo123')
      end

      it 'returns expected hash' do
        expect(helper.pages_deployments_usage_quota_data(project)).to match(
          {
            full_path: project.full_path,
            project_deployments_count: 1,
            deployments_count: 1,
            deployments_limit: 100,
            domain: 'foo123.example.com',
            uses_namespace_domain: 'false'
          }
        )
      end
    end

    context 'when project has unique domain disabled' do
      before do
        project.project_setting.update!(pages_unique_domain_enabled: false)
      end

      it 'returns expected hash' do
        expect(helper.pages_deployments_usage_quota_data(project)).to match(
          {
            full_path: project.full_path,
            project_deployments_count: 1,
            deployments_count: 2,
            deployments_limit: 100,
            domain: "#{group.path}.example.com",
            uses_namespace_domain: 'true'
          }
        )
      end
    end
  end

  describe '#show_duo_otel_button?' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, :repository) }

    subject(:show_duo_otel_button) { helper.show_duo_otel_button?(project, user) }

    it 'delegates to the :create_duo_otel_workflow policy ability' do
      expect(helper).to receive(:can?).with(user, :create_duo_otel_workflow, project).and_return(true)

      expect(show_duo_otel_button).to be true
    end
  end

  describe '#project_general_settings_data' do
    let_it_be_with_reload(:project) { create(:project) }

    subject(:data) { helper.project_general_settings_data(project) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'when the user is an admin and the size limit is licensed', :enable_admin_mode do
      let_it_be(:user) { create(:admin) }

      before do
        stub_licensed_features(repository_size_limit: true)
        project.update!(repository_size_limit: 100.megabytes)
      end

      it 'includes the editable repository size limit data' do
        expect(data).to include(
          can_edit_repository_size_limit: 'true',
          repository_size_limit_value: 100
        )
        expect(data[:repository_size_limit_help_text]).to be_present
      end
    end

    context 'when the size limit is not licensed' do
      let_it_be(:user) { create(:user) }

      before do
        stub_licensed_features(repository_size_limit: false)
      end

      it 'does not expose the repository size limit value' do
        expect(data).to include(
          can_edit_repository_size_limit: 'false',
          repository_size_limit_value: nil,
          repository_size_limit_help_text: ''
        )
      end
    end
  end
end
