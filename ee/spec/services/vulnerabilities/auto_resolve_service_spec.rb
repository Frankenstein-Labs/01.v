# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::AutoResolveService, :elastic, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user, :security_policy_bot) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be_with_reload(:project) { create(:project, namespace: namespace) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, :detected, :high_severity, project: project) }
  let_it_be(:resolved_vulnerability) { create(:vulnerability, :with_findings, :resolved, project: project) }
  let_it_be(:dismissed_vulnerability) { create(:vulnerability, :with_findings, :dismissed, project: project) }
  let_it_be(:policy) { create(:security_policy, :vulnerability_management_policy, linked_projects: [project]) }
  let_it_be(:policy_rule) do
    create(:vulnerability_management_policy_rule,
      security_policy: policy,
      content: {
        type: 'no_longer_detected',
        scanners: [],
        severity_levels: []
      }
    )
  end

  let(:vulnerability_ids) { [vulnerability.id] }

  let(:comment) do
    format(
      _("Auto-resolved by the vulnerability management policy named '%{policy_name}' " \
        "as the vulnerability was no longer detected in pipeline %{pipeline_link}."),
      policy_name: security_policy_name,
      pipeline_link: "[#{pipeline.id}](#{Gitlab::UrlBuilder.build(pipeline)})"
    )
  end

  let(:security_policy_name) { policy.name }
  let(:budget) { 1000 }

  subject(:service) { described_class.new(pipeline, vulnerability_ids, budget) }

  before_all do
    project.add_guest(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe '#execute' do
    before do
      allow(::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker).to receive(:perform_async)
    end

    it_behaves_like 'sync vulnerabilities changes to ES' do
      let(:expected_vulnerabilities) { vulnerability.vulnerability_read }

      subject { service.execute }
    end

    it 'resolves vulnerabilities that are not resolved or dismissed', :freeze_time do
      service.execute

      vulnerability.reload
      expect(vulnerability).to be_resolved
      expect(vulnerability.resolved_by).to eq(project.security_policy_bot)
      expect(vulnerability.resolved_at).to eq(Time.current)
      expect(vulnerability.auto_resolved).to be(true)

      # Ruby has nanosecond precision on timestamps, while Postgress has microsecond precision.
      # This causes the timestamp to be rounded down to the nearest microsecond when the record is reloaded.
      # We need to make the comparison in microseconds to avoid a false-negative.
      expect { resolved_vulnerability.reload }.not_to change { resolved_vulnerability.updated_at.floor(6) }
      expect { dismissed_vulnerability.reload }.not_to change { dismissed_vulnerability.updated_at.floor(6) }
    end

    it 'inserts a state transition for each vulnerability' do
      service.execute

      last_state = vulnerability.reload.state_transitions.last
      expect(last_state.from_state).to eq('detected')
      expect(last_state.to_state).to eq('resolved')
      expect(last_state.comment).to eq(comment)
      expect(last_state.author).to eq(project.security_policy_bot)
      expect(last_state.vulnerability_occurrence_id)
        .to eq(vulnerability.vulnerability_read&.vulnerability_occurrence_id)
    end

    it 'inserts a system note for each vulnerability' do
      service.execute

      last_note = Note.last

      expect(last_note.noteable).to eq(vulnerability)
      expect(last_note.author).to eq(project.security_policy_bot)
      expect(last_note.project).to eq(project)
      expect(last_note.namespace_id).to be_nil
      expect(last_note.note).to eq(
        "changed vulnerability status to Resolved with the following comment: \"#{comment}\""
      )
      expect(last_note).to be_system
      expect(last_note.system_note_metadata.action).to eq('vulnerability_resolved')
    end

    it 'updates the statistics', :sidekiq_inline do
      _active_vulnerability = create(:vulnerability, :with_finding, :high_severity, project: project)
      Vulnerabilities::Read.update_all(traversal_ids: project.namespace.traversal_ids)

      service.execute

      expect(project.vulnerability_statistic).to be_present
      expect(project.vulnerability_statistic.total).to eq(1)
      expect(project.vulnerability_statistic.critical).to eq(0)
      expect(project.vulnerability_statistic.high).to eq(1)
      expect(project.vulnerability_statistic.medium).to eq(0)
      expect(project.vulnerability_statistic.low).to eq(0)
      expect(project.vulnerability_statistic.unknown).to eq(0)
      expect(project.vulnerability_statistic.letter_grade).to eq('d')
    end

    it 'returns the correct count' do
      result = service.execute
      expect(result.success?).to be true
      expect(result.payload[:count]).to eq(1)
    end

    context 'when project has active hooks' do
      before do
        allow(project).to receive(:has_active_hooks?).with(:vulnerability_hooks).and_return(true)
      end

      it 'triggers webhook events for resolved vulnerabilities' do
        expect_any_instance_of(Vulnerability) do |vulnerability|
          expect(vulnerability).to receive(:trigger_webhook_event)
        end

        service.execute
      end
    end

    context 'when project does not have a security_policy_bot' do
      before_all do
        project.security_policy_bots.delete_all
      end

      it 'creates a new security policy bot' do
        expect { service.execute }.to change { project.security_policy_bots.count }.by(1)
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:count]).to eq(1)
      end
    end

    context 'when user does not have permission' do
      let_it_be(:non_bot_user) { create(:user) }

      before_all do
        project.add_guest(non_bot_user)
      end

      before do
        allow(project).to receive(:security_policy_bot).and_return(non_bot_user)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Could not resolve vulnerabilities')
        expect(result.reason).to eq('Bot user does not have permission to create state transitions')
      end
    end

    context 'when an error occurs' do
      before do
        allow(Note).to receive(:insert_all!).and_raise(ActiveRecord::RecordNotUnique)
      end

      it 'returns an appropriate service response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Could not resolve vulnerabilities')
        expect(result.reason).to eq('ActiveRecord error')
        expect(result.payload[:exception]).to be_a(ActiveRecord::RecordNotUnique)
      end
    end

    context 'when updating multiple vulnerabilities' do
      let_it_be(:vulnerabilities) { create_list(:vulnerability, 2, :with_findings, project: project) }

      let(:vulnerability_ids) { vulnerabilities.map(&:id) }

      describe 'internal event tracking' do
        let(:event) { 'autoresolve_vulnerability_in_project_after_pipeline_run_if_policy_is_set' }
        let(:distinct_count_weekly) do
          'redis_hll_counters.count_distinct_project_id_from_vulnerability_auto_resolution_weekly'
        end

        let(:distinct_count_monthly) do
          'redis_hll_counters.count_distinct_project_id_from_vulnerability_auto_resolution_monthly'
        end

        let(:total_count_weekly) do
          'sums.count_total_autoresolve_vulnerability_in_project_after_pipeline_run_if_policy_is_set_weekly'
        end

        let(:total_count_monthly) do
          'sums.count_total_autoresolve_vulnerability_in_project_after_pipeline_run_if_policy_is_set_monthly'
        end

        let(:total_count) do
          'sums.count_total_autoresolve_vulnerability_in_project_after_pipeline_run_if_policy_is_set'
        end

        let(:additional_properties) do
          {
            value: vulnerabilities.size
          }
        end

        it 'tracks internal events', :clean_gitlab_redis_shared_state, :aggregate_failures do
          expect { service.execute }
            .to trigger_internal_events(event)
            .with(
              project: project,
              namespace: project.namespace,
              additional_properties: additional_properties
            ).and increment_usage_metrics(distinct_count_weekly).by(1)
              .and increment_usage_metrics(distinct_count_monthly).by(1)
              .and increment_usage_metrics(total_count_weekly).by(2)
              .and increment_usage_metrics(total_count_monthly).by(2)
              .and increment_usage_metrics(total_count).by(2)
        end
      end

      describe 'policy evaluation tracking' do
        let(:evaluation_event) { 'evaluate_vulnerability_management_policy_in_project' }
        let(:evaluation_project_metric_weekly) do
          'redis_hll_counters.count_distinct_project_id_from_evaluate_vulnerability_management_policy_weekly'
        end

        let(:evaluation_project_metric_monthly) do
          'redis_hll_counters.count_distinct_project_id_from_evaluate_vulnerability_management_policy_monthly'
        end

        it 'tracks policy evaluation event and increments metrics',
          :clean_gitlab_redis_shared_state, :aggregate_failures do
          expect { service.execute }
            .to trigger_internal_events(evaluation_event)
            .with(
              project: project,
              namespace: project.namespace,
              additional_properties: { label: 'auto_resolve' }
            ).and increment_usage_metrics(evaluation_project_metric_weekly).by(1)
              .and increment_usage_metrics(evaluation_project_metric_monthly).by(1)
        end
      end

      it 'does not introduce N+1 queries' do
        # Reload pipeline so that associations are not cached for the control
        pipeline.reload

        control = ActiveRecord::QueryRecorder.new do
          described_class.new(pipeline, vulnerability_ids, budget).execute
        end

        new_vulnerability = create(:vulnerability, :with_findings, project: project)
        vulnerability_ids << new_vulnerability.id

        other_policy = create(:security_policy, :vulnerability_management_policy, linked_projects: [project])
        create(:vulnerability_management_policy_rule,
          security_policy: other_policy,
          content: {
            type: 'no_longer_detected',
            scanners: [],
            severity_levels: []
          }
        )

        expect do
          described_class.new(pipeline, vulnerability_ids, budget).execute
        end.not_to exceed_query_limit(control)
      end

      it 'respects the budget' do
        result = described_class.new(pipeline, vulnerability_ids, 1).execute

        expect(result.payload[:count]).to eq(1)
        ordered_vulnerabilities = Vulnerability.where(id: vulnerability_ids).order(:auto_resolved)
        expect(ordered_vulnerabilities[0]).not_to be_auto_resolved
        expect(ordered_vulnerabilities[1]).to be_auto_resolved
      end
    end

    context 'when resolving vulnerabilities' do
      it 'updates the vulnerability read records with correct state and auto_resolved flag' do
        vulnerability_read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id) ||
          create(:vulnerability_read,
            vulnerability: vulnerability,
            state: 'detected',
            auto_resolved: false)

        vulnerability_read.update!(state: 'detected', auto_resolved: false)

        service.execute

        vulnerability_read.reload
        expect(vulnerability_read.state).to eq('resolved')
        expect(vulnerability_read.auto_resolved).to be(true)
      end

      it 'updates multiple vulnerability read records when resolving multiple vulnerabilities' do
        vulnerabilities = create_list(:vulnerability, 2, :with_findings, :detected, project: project)
        vulnerability_ids = vulnerabilities.map(&:id)

        vulnerability_reads = vulnerabilities.map do |vuln|
          read = Vulnerabilities::Read.find_by(vulnerability_id: vuln.id) ||
            create(:vulnerability_read, vulnerability: vuln)

          read.update!(state: 'detected', auto_resolved: false)
          read
        end

        described_class.new(pipeline, vulnerability_ids, budget).execute

        vulnerability_reads.each do |read|
          read.reload
          expect(read.state).to eq('resolved')
          expect(read.auto_resolved).to be(true)
        end
      end

      it 'respects the budget when updating vulnerability reads' do
        vulnerabilities = create_list(:vulnerability, 3, :with_findings, :detected, project: project)
        vulnerability_ids = vulnerabilities.map(&:id)

        vulnerability_reads = vulnerabilities.map do |vuln|
          read = Vulnerabilities::Read.find_by(vulnerability_id: vuln.id) ||
            create(:vulnerability_read, vulnerability: vuln)

          read.update!(state: 'detected', auto_resolved: false)
          read
        end

        described_class.new(pipeline, vulnerability_ids, 2).execute

        updated_reads = vulnerability_reads.select { |read| read.reload.state == 'resolved' }
        expect(updated_reads.count).to eq(2)

        updated_reads.each do |read|
          expect(read.auto_resolved).to be(true)
        end
      end
    end
  end
end
