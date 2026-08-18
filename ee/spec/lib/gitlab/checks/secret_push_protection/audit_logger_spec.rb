# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::AuditLogger, feature_category: :secret_detection do
  include_context 'secrets check context'

  subject(:audit_logger) { described_class.new(project: project, changes_access: changes_access) }

  shared_examples 'respects audit event licensing' do
    context 'with Free tier' do
      before do
        stub_licensed_features(audit_events: false)
      end

      it 'does not create audit events' do
        expect { perform_action }.not_to change { AuditEventReader.count }
      end
    end

    context 'with Ultimate tier' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'creates audit events' do
        expect { perform_action }.to change { AuditEventReader.count }.by(expected_audit_event_count)
      end
    end
  end

  describe '#log_skip_secret_push_protection' do
    let(:comparison_path) do
      ::Gitlab::Utils.append_path(
        ::Gitlab::Routing.url_helpers.root_url,
        ::Gitlab::Routing.url_helpers.project_compare_path(project, from: initial_commit, to: new_commit)
      )
    end

    shared_examples 'audit event logging' do |skip_method|
      it_behaves_like 'respects audit event licensing' do
        let(:perform_action) { audit_logger.log_skip_secret_push_protection(skip_method) }
        let(:expected_audit_event_count) { 1 }
      end

      context 'with licensed audit events' do
        before do
          stub_licensed_features(audit_events: true)
        end

        it "creates an audit event for #{skip_method} skip" do
          expect { audit_logger.log_skip_secret_push_protection(skip_method) }
            .to change { AuditEventReader.count }.by(1)

          audit_event = AuditEventReader.order(:id).last
          expect(audit_event.details[:custom_message]).to eq(
            "Secret push protection skipped via #{skip_method} on branch master"
          )
          expect(audit_event.details[:event_name]).to eq('skip_secret_push_protection')
          expect(audit_event.details[:target_details]).to eq(comparison_path)
          expect(audit_event.author_id).to eq(user.id)
          expect(audit_event.entity_id).to eq(project.id)
        end
      end

      context 'when internal event tracking' do
        it_behaves_like 'internal event tracking' do
          let(:event) { 'skip_secret_push_protection' }
          let(:namespace) { project.namespace }
          let(:label) { skip_method.to_s }
          let(:category) { "Gitlab::Checks::SecretPushProtection::AuditLogger" }
          subject { audit_logger.track_spp_skipped(skip_method.to_s) }
        end

        context 'on Free tier' do
          before do
            stub_licensed_features(audit_events: false)
          end

          it 'still tracks internal events' do
            expect { audit_logger.track_spp_skipped(skip_method.to_s) }
              .to trigger_internal_events('skip_secret_push_protection')
              .with(user: user, project: project, namespace: project.namespace,
                additional_properties: { label: skip_method.to_s })
          end
        end
      end
    end

    it_behaves_like 'audit event logging', 'commit message'
    it_behaves_like 'audit event logging', 'push option'
  end

  describe '#log_spp_too_many_changed_paths' do
    let(:changed_paths_count) { 1500 }
    let(:changed_paths_threshold) { 1000 }
    let(:comparison_path) do
      ::Gitlab::Utils.append_path(
        ::Gitlab::Routing.url_helpers.root_url,
        ::Gitlab::Routing.url_helpers.project_compare_path(project, from: initial_commit, to: new_commit)
      )
    end

    it_behaves_like 'respects audit event licensing' do
      let(:perform_action) { audit_logger.log_spp_too_many_changed_paths(changed_paths_count, changed_paths_threshold) }
      let(:expected_audit_event_count) { 1 }
    end

    context 'with licensed audit events' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'creates an audit event for too many changed paths', :aggregate_failures do
        expect { audit_logger.log_spp_too_many_changed_paths(changed_paths_count, changed_paths_threshold) }
          .to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.order(:id).last
        expect(audit_event.details[:custom_message]).to eq(
          "Secret push protection was skipped: #{changed_paths_count} changed paths exceeds " \
            "the threshold of #{changed_paths_threshold}."
        )
        expect(audit_event.details[:event_name]).to eq('spp_too_many_changed_paths')
        expect(audit_event.details[:target_details]).to eq(comparison_path)
        expect(audit_event.author_id).to eq(user.id)
        expect(audit_event.entity_id).to eq(project.id)
      end
    end
  end

  describe '#log_spp_too_many_lines' do
    let(:lines_count) { 400_000 }
    let(:lines_threshold) { 300_000 }
    let(:comparison_path) do
      ::Gitlab::Utils.append_path(
        ::Gitlab::Routing.url_helpers.root_url,
        ::Gitlab::Routing.url_helpers.project_compare_path(project, from: initial_commit, to: new_commit)
      )
    end

    it_behaves_like 'respects audit event licensing' do
      let(:perform_action) { audit_logger.log_spp_too_many_lines(lines_count, lines_threshold) }
      let(:expected_audit_event_count) { 1 }
    end

    context 'with licensed audit events' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'creates an audit event for too many lines' do
        expect { audit_logger.log_spp_too_many_lines(lines_count, lines_threshold) }
          .to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.order(:id).last
        expect(audit_event.details[:custom_message]).to eq(
          "Secret push protection was skipped: #{lines_count} lines count exceeds " \
            "the threshold of #{lines_threshold}."
        )
        expect(audit_event.details[:event_name]).to eq('spp_too_many_lines')
        expect(audit_event.details[:target_details]).to eq(comparison_path)
        expect(audit_event.author_id).to eq(user.id)
        expect(audit_event.entity_id).to eq(project.id)
      end
    end
  end

  describe '#log_spp_scan_timeout' do
    let(:comparison_path) do
      ::Gitlab::Utils.append_path(
        ::Gitlab::Routing.url_helpers.root_url,
        ::Gitlab::Routing.url_helpers.project_compare_path(project, from: initial_commit, to: new_commit)
      )
    end

    it_behaves_like 'respects audit event licensing' do
      let(:perform_action) { audit_logger.log_spp_scan_timeout }
      let(:expected_audit_event_count) { 1 }
    end

    context 'with licensed audit events' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'creates an audit event for scan timeout', :aggregate_failures do
        expect { audit_logger.log_spp_scan_timeout }
          .to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.order(:id).last

        expect(audit_event.details[:custom_message]).to eq(
          'Secret push protection scan timed out. The push was accepted.'
        )
        expect(audit_event.details[:event_name]).to eq('spp_scan_timeout')
        expect(audit_event.details[:target_details]).to eq(comparison_path)
        expect(audit_event.author_id).to eq(user.id)
        expect(audit_event.entity_id).to eq(project.id)
      end
    end
  end

  describe '#log_spp_ruleset_error' do
    let(:comparison_path) do
      ::Gitlab::Utils.append_path(
        ::Gitlab::Routing.url_helpers.root_url,
        ::Gitlab::Routing.url_helpers.project_compare_path(project, from: initial_commit, to: new_commit)
      )
    end

    it_behaves_like 'respects audit event licensing' do
      let(:perform_action) { audit_logger.log_spp_ruleset_error }
      let(:expected_audit_event_count) { 1 }
    end

    context 'with licensed audit events' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'creates an audit event for ruleset errors', :aggregate_failures do
        expect { audit_logger.log_spp_ruleset_error }
          .to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.order(:id).last
        expect(audit_event.details[:custom_message]).to eq(
          'Secret push protection encountered a ruleset parse or compile error.'
        )
        expect(audit_event.details[:event_name]).to eq('spp_ruleset_error')
        expect(audit_event.details[:target_details]).to eq(comparison_path)
        expect(audit_event.author_id).to eq(user.id)
        expect(audit_event.entity_id).to eq(project.id)
      end
    end
  end

  describe '#log_spp_invalid_input' do
    let(:comparison_path) do
      ::Gitlab::Utils.append_path(
        ::Gitlab::Routing.url_helpers.root_url,
        ::Gitlab::Routing.url_helpers.project_compare_path(project, from: initial_commit, to: new_commit)
      )
    end

    it_behaves_like 'respects audit event licensing' do
      let(:perform_action) { audit_logger.log_spp_invalid_input }
      let(:expected_audit_event_count) { 1 }
    end

    context 'with licensed audit events' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'creates an audit event for invalid input', :aggregate_failures do
        expect { audit_logger.log_spp_invalid_input }
          .to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.order(:id).last
        expect(audit_event.details[:custom_message]).to eq('Secret push protection skipped due to invalid input.')
        expect(audit_event.details[:event_name]).to eq('spp_invalid_input')
        expect(audit_event.details[:target_details]).to eq(comparison_path)
        expect(audit_event.author_id).to eq(user.id)
        expect(audit_event.entity_id).to eq(project.id)
      end
    end
  end

  describe '#log_spp_generic_scan_error' do
    let(:comparison_path) do
      ::Gitlab::Utils.append_path(
        ::Gitlab::Routing.url_helpers.root_url,
        ::Gitlab::Routing.url_helpers.project_compare_path(project, from: initial_commit, to: new_commit)
      )
    end

    it_behaves_like 'respects audit event licensing' do
      let(:perform_action) { audit_logger.log_spp_generic_scan_error }
      let(:expected_audit_event_count) { 1 }
    end

    context 'with licensed audit events' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'creates an audit event for generic scan errors' do
        expect { audit_logger.log_spp_generic_scan_error }
          .to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.order(:id).last
        expect(audit_event.details[:custom_message]).to eq(
          'Secret push protection encountered an unexpected scan error.'
        )
        expect(audit_event.details[:event_name]).to eq('spp_generic_scan_error')
        expect(audit_event.details[:target_details]).to eq(comparison_path)
        expect(audit_event.author_id).to eq(user.id)
        expect(audit_event.entity_id).to eq(project.id)
      end
    end
  end

  describe '#log_exclusion_audit_event' do
    context 'with a path exclusion' do
      let(:exclusion) do
        create(:project_security_exclusion, :active, :with_path, project: project, value: "file-exclusion-1.rb")
      end

      it_behaves_like 'respects audit event licensing' do
        let(:perform_action) { audit_logger.log_exclusion_audit_event(exclusion) }
        let(:expected_audit_event_count) { 1 }
      end

      context 'with licensed audit events' do
        before do
          stub_licensed_features(audit_events: true)
        end

        it 'creates an audit event for applied exclusion' do
          expect { audit_logger.log_exclusion_audit_event(exclusion) }.to change { AuditEventReader.count }.by(1)

          audit_event = AuditEventReader.last
          expect(audit_event.details[:custom_message]).to eq(
            "An exclusion of type (path) with value (file-exclusion-1.rb) was applied in Secret push protection"
          )
          expect(audit_event.details[:event_name])
            .to eq('project_security_exclusion_applied')
          expect(audit_event.author_id).to eq(user.id)
          expect(audit_event.target_details).to eq(exclusion.audit_details.to_s)
        end
      end
    end

    context 'with a rule exclusion' do
      let(:exclusion) do
        create(:project_security_exclusion, :active, :with_rule, project: project,
          value: "gitlab_personal_access_token")
      end

      it_behaves_like 'respects audit event licensing' do
        let(:perform_action) { audit_logger.log_exclusion_audit_event(exclusion) }
        let(:expected_audit_event_count) { 1 }
      end

      context 'with licensed audit events' do
        before do
          stub_licensed_features(audit_events: true)
        end

        it 'creates an audit event for applied exclusion' do
          expect { audit_logger.log_exclusion_audit_event(exclusion) }.to change { AuditEventReader.count }.by(1)

          audit_event = AuditEventReader.last
          expect(audit_event.details[:custom_message]).to eq(
            "An exclusion of type (rule) with value (gitlab_personal_access_token) " \
              "was applied in Secret push protection"
          )
          expect(audit_event.details[:event_name])
            .to eq('project_security_exclusion_applied')
          expect(audit_event.author_id).to eq(user.id)
        end
      end
    end
  end

  describe '#log_applied_exclusions_audit_events' do
    let(:exclusion1) do
      create(:project_security_exclusion, :active, :with_path, project: project, value: "file-exclusion-1.rb")
    end

    let(:exclusion2) do
      create(:project_security_exclusion, :active, :with_rule, project: project, value: "gitlab_personal_access_token")
    end

    let(:applied_exclusions) { [exclusion1, exclusion2] }

    it_behaves_like 'respects audit event licensing' do
      let(:perform_action) { audit_logger.log_applied_exclusions_audit_events(applied_exclusions) }
      let(:expected_audit_event_count) { 2 }
    end

    context 'with licensed audit events' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'logs audit events for all applied exclusions' do
        expect { audit_logger.log_applied_exclusions_audit_events(applied_exclusions) }.to change {
          AuditEventReader.count
        }.by(2)
      end
    end
  end

  describe '#track_secret_found' do
    it_behaves_like 'internal event tracking' do
      let(:event) { 'detect_secret_type_on_push' }
      let(:namespace) { project.namespace }
      let(:label) { "gitlab_personal_access_token" }
      let(:category) { "Gitlab::Checks::SecretPushProtection::AuditLogger" }
      subject { super().track_secret_found('gitlab_personal_access_token') }
    end

    context 'on Free tier' do
      before do
        stub_licensed_features(audit_events: false)
      end

      it 'still tracks internal events' do
        expect { audit_logger.track_secret_found('gitlab_personal_access_token') }
          .to trigger_internal_events('detect_secret_type_on_push')
          .with(user: user, project: project, namespace: project.namespace,
            additional_properties: { label: 'gitlab_personal_access_token' })
      end
    end
  end

  describe '#get_project_security_exclusion_from_sds_exclusion' do
    let(:exclusion) { create(:project_security_exclusion, :with_rule, project: project) }

    let(:sds_exclusion) do
      Gitlab::SecretDetection::GRPC::Exclusion.new(
        exclusion_type: Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_RULE,
        value: exclusion.value
      )
    end

    it 'returns the same object if it is a ProjectSecurityExclusion' do
      result = audit_logger.send(:get_project_security_exclusion_from_sds_exclusion, exclusion)
      expect(result).to be exclusion
    end

    it 'returns the ProjectSecurityExclusion with the same value' do
      result = audit_logger.send(:get_project_security_exclusion_from_sds_exclusion, sds_exclusion)
      expect(result).to eq exclusion
    end
  end

  describe '#track_spp_scan_executed' do
    context 'when scan type is dark launch' do
      let(:properties) { { label: 'dark-launch' } }

      it 'triggers internal events and increment usage metrics' do
        expect { audit_logger.track_spp_scan_executed('dark-launch') }
          .to trigger_internal_events('spp_scan_executed')
          .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
          .and increment_usage_metrics('counts.count_total_spp_scan_executed')
      end

      context 'on Free tier' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it 'still triggers internal events' do
          expect { audit_logger.track_spp_scan_executed('dark-launch') }
            .to trigger_internal_events('spp_scan_executed')
            .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
        end
      end
    end

    context 'when scan type is regular' do
      let(:properties) { { label: 'regular' } }

      it 'triggers internal events and increment usage metrics' do
        expect { audit_logger.track_spp_scan_executed('regular') }
          .to trigger_internal_events('spp_scan_executed')
          .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
          .and increment_usage_metrics('counts.count_total_spp_scan_executed')
      end
    end
  end

  describe '#track_spp_scan_passed' do
    it 'triggers internal events and increment usage metrics' do
      expect { audit_logger.track_spp_scan_passed }
        .to trigger_internal_events('spp_scan_passed')
        .with(user: user, project: project, namespace: project.namespace)
        .and increment_usage_metrics('counts.count_total_spp_scan_passed')
    end

    context 'on Free tier' do
      before do
        stub_licensed_features(audit_events: false)
      end

      it 'still triggers internal events' do
        expect { audit_logger.track_spp_scan_passed }
          .to trigger_internal_events('spp_scan_passed')
          .with(user: user, project: project, namespace: project.namespace)
      end
    end
  end

  describe '#track_spp_push_blocked_secrets_found' do
    let(:properties) { { value: 2 } }

    it 'triggers internal events and increment usage metrics' do
      expect { audit_logger.track_spp_push_blocked_secrets_found(properties[:value]) }
        .to trigger_internal_events('spp_push_blocked_secrets_found')
        .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
        .and increment_usage_metrics('counts.count_total_spp_push_blocked_secrets_found')
    end

    context 'on Free tier' do
      before do
        stub_licensed_features(audit_events: false)
      end

      it 'still triggers internal events' do
        expect { audit_logger.track_spp_push_blocked_secrets_found(properties[:value]) }
          .to trigger_internal_events('spp_push_blocked_secrets_found')
          .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
      end
    end
  end

  describe '#track_spp_push_blocked_secrets_found_with_errors' do
    let(:properties) { { value: 2 } }

    it 'triggers internal events and increment usage metrics' do
      expect { audit_logger.track_spp_push_blocked_secrets_found_with_errors(properties[:value]) }
        .to trigger_internal_events('spp_push_blocked_secrets_found_with_errors')
        .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
        .and increment_usage_metrics('counts.count_total_spp_push_blocked_secrets_found_with_errors')
    end

    context 'on Free tier' do
      before do
        stub_licensed_features(audit_events: false)
      end

      it 'still triggers internal events' do
        expect { audit_logger.track_spp_push_blocked_secrets_found_with_errors(properties[:value]) }
          .to trigger_internal_events('spp_push_blocked_secrets_found_with_errors')
          .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
      end
    end
  end

  describe '#track_changed_paths_calculated' do
    let(:properties) { { value: 2 } }

    it 'triggers the internal event' do
      expect { audit_logger.track_changed_paths_calculated(properties[:value]) }
        .to trigger_internal_events('calculate_changed_paths_in_secret_push_protection')
        .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
    end
  end

  describe '#track_spp_execution_time_in_seconds' do
    let(:properties) { { value: 2.3 } }

    it 'triggers the internal event' do
      expect { audit_logger.track_spp_execution_time_in_seconds(properties[:value]) }
        .to trigger_internal_events('spp_total_execution_time')
        .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
    end
  end

  describe '#track_spp_standard_error_exception' do
    let(:exception_class) { 'GRPC::Unavailable' }
    let(:properties) { { label: exception_class } }

    it 'triggers the internal event' do
      expect { audit_logger.track_spp_standard_error_exception(exception_class) }
        .to trigger_internal_events('spp_standard_error_exception_encountered')
        .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
    end
  end

  describe '#track_spp_too_many_changed_paths_error' do
    let(:changed_paths_count) { 1500 }
    let(:changed_paths_threshold) { 1000 }
    let(:error) do
      Gitlab::Checks::SecretPushProtection::TooManyChangedPathsError.new(
        changed_paths_count,
        changed_paths_threshold
      )
    end

    let(:properties) do
      {
        label: error.message,
        value: changed_paths_count
      }
    end

    it 'triggers the internal event' do
      expect { audit_logger.track_spp_too_many_changed_paths_error(error.message, changed_paths_count) }
        .to trigger_internal_events('spp_too_many_changed_paths_error_encountered')
        .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
    end
  end

  describe '#track_spp_too_many_lines_error' do
    let(:lines_count) { 400_000 }
    let(:lines_threshold) { 350_000 }
    let(:error) do
      Gitlab::Checks::SecretPushProtection::TooManyLinesError.new(
        lines_count,
        lines_threshold
      )
    end

    let(:properties) do
      {
        label: error.message,
        value: lines_count
      }
    end

    it 'triggers the internal event' do
      expect { audit_logger.track_spp_too_many_lines_error(error.message, lines_count) }
        .to trigger_internal_events('spp_too_many_lines_error_encountered')
        .with(user: user, project: project, namespace: project.namespace, additional_properties: properties)
    end
  end

  describe '#track_spp_ruleset_error' do
    it 'triggers the internal event' do
      expect { audit_logger.track_spp_ruleset_error }
        .to trigger_internal_events('spp_ruleset_error_encountered')
        .with(user: user, project: project, namespace: project.namespace)
    end
  end

  describe 'constants' do
    it 'defines the expected audit event names', :aggregate_failures do
      expect(described_class::AUDIT_EVENT_SKIP_SECRET_PUSH_PROTECTION).to eq('skip_secret_push_protection')
      expect(described_class::AUDIT_EVENT_SPP_TOO_MANY_CHANGED_PATHS).to eq('spp_too_many_changed_paths')
      expect(described_class::AUDIT_EVENT_SPP_TOO_MANY_LINES).to eq('spp_too_many_lines')
      expect(described_class::AUDIT_EVENT_SPP_SCAN_TIMEOUT).to eq('spp_scan_timeout')
      expect(described_class::AUDIT_EVENT_SPP_RULESET_ERROR).to eq('spp_ruleset_error')
      expect(described_class::AUDIT_EVENT_SPP_INVALID_INPUT).to eq('spp_invalid_input')
      expect(described_class::AUDIT_EVENT_SPP_GENERIC_SCAN_ERROR).to eq('spp_generic_scan_error')
      expect(described_class::AUDIT_EVENT_PROJECT_SECURITY_EXCLUSION_APPLIED)
        .to eq('project_security_exclusion_applied')
    end

    it 'defines the expected internal event names', :aggregate_failures do
      expect(described_class::INTERNAL_EVENT_SKIP_SECRET_PUSH_PROTECTION).to eq('skip_secret_push_protection')
      expect(described_class::INTERNAL_EVENT_DETECT_SECRET_TYPE_ON_PUSH).to eq('detect_secret_type_on_push')
      expect(described_class::INTERNAL_EVENT_SPP_SCAN_EXECUTED).to eq('spp_scan_executed')
      expect(described_class::INTERNAL_EVENT_SPP_SCAN_PASSED).to eq('spp_scan_passed')
      expect(described_class::INTERNAL_EVENT_SPP_PUSH_BLOCKED_SECRETS_FOUND)
        .to eq('spp_push_blocked_secrets_found')
      expect(described_class::INTERNAL_EVENT_SPP_PUSH_BLOCKED_SECRETS_FOUND_WITH_ERRORS)
        .to eq('spp_push_blocked_secrets_found_with_errors')
      expect(described_class::INTERNAL_EVENT_CALCULATE_CHANGED_PATHS)
        .to eq('calculate_changed_paths_in_secret_push_protection')
      expect(described_class::INTERNAL_EVENT_SPP_TOTAL_EXECUTION_TIME).to eq('spp_total_execution_time')
      expect(described_class::INTERNAL_EVENT_SPP_STANDARD_ERROR_EXCEPTION)
        .to eq('spp_standard_error_exception_encountered')
      expect(described_class::INTERNAL_EVENT_SPP_TOO_MANY_CHANGED_PATHS_ERROR)
        .to eq('spp_too_many_changed_paths_error_encountered')
      expect(described_class::INTERNAL_EVENT_SPP_TOO_MANY_LINES_ERROR)
        .to eq('spp_too_many_lines_error_encountered')
      expect(described_class::INTERNAL_EVENT_SPP_RULESET_ERROR).to eq('spp_ruleset_error_encountered')
    end
  end
end
