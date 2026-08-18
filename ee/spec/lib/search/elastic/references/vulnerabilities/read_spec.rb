# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::Vulnerabilities::Read, :elastic_helpers, :request_store, feature_category: :vulnerability_management do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user_project) { create(:project, namespace: create(:namespace)) }

  let_it_be(:vulnerability) do
    SecApplicationRecord.feature_flagged_transaction_for(project) do
      create(:vulnerability, :with_finding, :with_read, project: project, report_type: :container_scanning)
    end
  end

  let_it_be(:user_vulnerability) do
    SecApplicationRecord.feature_flagged_transaction_for(user_project) do
      create(:vulnerability, :with_read, project: user_project, report_type: :sast)
    end
  end

  let_it_be_with_reload(:vulnerability_read) { vulnerability.vulnerability_read }
  let_it_be(:user_vulnerability_read) { user_vulnerability.vulnerability_read }

  before do
    stub_const('Gitlab::QueryLimiting::Transaction::THRESHOLD', 100)
    allow(described_class).to receive(:backfill_occurrence_id_completed?).and_return(true)
    allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
  end

  describe '#as_indexed_json', :freeze_time do
    let(:object) { vulnerability_read }

    let(:vulnerability_reference_object) do
      described_class.new(object[:id], object.es_parent)
    end

    let(:expected_hash) do
      {
        vulnerability_id: object.vulnerability_id,
        vulnerability_occurrence_id: object.vulnerability_occurrence_id,
        created_at: be_within(0.1.seconds).of(object.vulnerability_occurrence.created_at),
        updated_at: be_within(0.1.seconds).of(object.vulnerability_occurrence.updated_at),
        detected_at: be_within(0.1.seconds).of(object.vulnerability_occurrence.detected_at),
        resolved_at: nil,
        dismissed_at: nil,
        project_id: object.project_id,
        organization_id: object.project.namespace.organization_id,
        scanner_id: object.scanner_id,
        scanner_external_id: object.scanner.external_id,
        report_type: object.report_type_before_type_cast,
        severity: object.severity_before_type_cast,
        state: object.state_before_type_cast,
        has_issues: object.has_issues,
        resolved_on_default_branch: object.resolved_on_default_branch,
        uuid: object.uuid,
        location_image: object.location_image,
        cluster_agent_id: object.cluster_agent_id,
        casted_cluster_agent_id: object.casted_cluster_agent_id,
        dismissal_reason: object.dismissal_reason_before_type_cast,
        has_merge_request: object.has_merge_request,
        has_remediations: object.has_remediations,
        traversal_ids: object.project.namespace.elastic_namespace_ancestry,
        archived: object.archived,
        has_vulnerability_resolution: object.has_vulnerability_resolution,
        auto_resolved: object.auto_resolved,
        identifier_names: object.identifier_names,
        reachability: [],
        token_status: [],
        policy_violations: [],
        risk_score: [],
        false_positive: [],
        undetected_since: [],
        policy_auto_dismissed: [],
        type: described_class::DOC_TYPE,
        schema_version: described_class::SCHEMA_VERSION,
        security_project_tracked_context_id: object.security_project_tracked_context_id,
        is_default: [],
        latest_flag: []
      }
    end

    subject(:indexed_json) do
      vulnerability_reference_object.as_indexed_json.with_indifferent_access
    end

    it 'serializes vulnerability as a hash' do
      expect(indexed_json).to match(expected_hash)
    end

    it 'always includes all fields without migration checks' do
      expect(indexed_json).to have_key(:security_project_tracked_context_id)
      expect(indexed_json).to have_key(:false_positive)
      expect(indexed_json).to have_key(:undetected_since)
      expect(indexed_json).to have_key(:policy_auto_dismissed)
      expect(indexed_json).to have_key(:vulnerability_occurrence_id)
    end

    context 'with reachability mappings' do
      let(:reachability_data) { 1 }

      before do
        allow(object).to receive(:reachability).and_return(reachability_data)
        allow(vulnerability_reference_object).to receive(:database_record).and_return(object)
      end

      it 'includes reachability in the indexed JSON' do
        expect(indexed_json[:reachability]).to eq(reachability_data)
      end
    end

    context 'when scanner is nil' do
      before do
        allow(vulnerability_reference_object).to receive(:database_record).and_return(object)
        allow(object).to receive(:scanner).and_return(nil)
      end

      it 'sets scanner_external_id to nil' do
        expect(indexed_json[:scanner_external_id]).to be_nil
      end
    end

    # TODO: Remove this spec check once BackfillOccurrenceIdToVulnerabilityReads
    # BBM is finalized - https://gitlab.com/gitlab-org/gitlab/-/work_items/594422
    context 'when vulnerability_occurrence is nil' do
      before do
        allow(vulnerability_reference_object).to receive(:database_record).and_return(object)
        allow(object).to receive(:vulnerability_occurrence).and_return(nil)
      end

      it 'sets created_at, updated_at, and detected_at to nil' do
        expect(indexed_json[:created_at]).to be_nil
        expect(indexed_json[:updated_at]).to be_nil
        expect(indexed_json[:detected_at]).to be_nil
      end
    end

    context 'with resolved_at, dismissed_at mappings' do
      context 'with resolved_at' do
        let(:resolved_at) { 1.day.ago }
        let(:resolved_vulnerability) do
          create(:vulnerability, :with_read, project: project, resolved_at: resolved_at)
        end

        let(:resolved_vulnerability_read) { resolved_vulnerability.vulnerability_read }
        let(:object) { resolved_vulnerability_read }

        it 'sets resolved_at field on the indexed json' do
          expect(indexed_json[:resolved_at]).to be_within(0.1.seconds).of(resolved_at)
        end
      end

      context 'with dismissed_at' do
        let(:dismissed_at) { 1.day.ago }
        let(:dismissed_vulnerability) do
          create(:vulnerability, :with_read, project: project, dismissed_at: dismissed_at)
        end

        let(:dismissed_vulnerability_read) { dismissed_vulnerability.vulnerability_read }
        let(:object) { dismissed_vulnerability_read }

        it 'sets dismissed_at field on the indexed json' do
          expect(indexed_json[:dismissed_at]).to be_within(0.1.seconds).of(dismissed_at)
        end
      end

      context 'with organization_id migration mappings' do
        context 'when organization_id migration has finished' do
          before do
            set_elasticsearch_migration_to(:add_organization_id_to_vulnerability_reads)
          end

          it 'returns correct schema version' do
            expect(indexed_json[:schema_version]).to eq(26_04)
          end

          it 'includes organization_id in the indexed json' do
            expect(indexed_json[:organization_id]).to eq(object.project.namespace.organization_id)
          end
        end

        context 'when organization_id migration has not completed' do
          before do
            set_elasticsearch_migration_to(:add_organization_id_to_vulnerability_reads, including: false)
          end

          it 'returns schema version without organization_id' do
            expect(indexed_json[:schema_version]).to eq(26_03)
          end

          it 'does not assign organization_id on the indexed json' do
            expect(indexed_json).not_to have_key(:organization_id)
          end
        end
      end

      context 'with is_default migration mappings' do
        context 'when is_default migration has finished' do
          let(:is_default_value) { true }

          before do
            allow(object).to receive(:is_default).and_return(is_default_value)
            allow(vulnerability_reference_object).to receive(:database_record).and_return(object)
          end

          it 'returns correct schema version' do
            expect(indexed_json[:schema_version]).to eq(26_04)
          end

          it 'includes is_default in the indexed json' do
            expect(indexed_json[:is_default]).to be(true)
          end

          context 'when is_default is false' do
            let(:is_default_value) { false }

            it 'indexes false' do
              expect(indexed_json[:is_default]).to be(false)
            end
          end
        end

        context 'when is_default migration has not completed' do
          before do
            set_elasticsearch_migration_to(:add_latest_flag_field_to_vulnerability_reads, including: false)
            set_elasticsearch_migration_to(:add_is_default_to_vulnerability_reads, including: false)
          end

          it 'returns schema version without is_default' do
            expect(indexed_json[:schema_version]).to eq(26_01)
          end

          it 'does not assign is_default on the indexed json' do
            expect(indexed_json[:is_default]).to be_blank
          end
        end
      end

      context 'with latest_flag migration mappings' do
        context 'when latest_flag migration has finished' do
          let(:flag_data) { { status: 'detected_as_fp', origin: 'ai_sast_fp_detection', confidence_score: 0.9 } }

          before do
            allow(object).to receive(:latest_flag).and_return(flag_data)
            allow(vulnerability_reference_object).to receive(:database_record).and_return(object)
            set_elasticsearch_migration_to(:add_latest_flag_field_to_vulnerability_reads)
          end

          it 'returns correct schema version' do
            expect(indexed_json[:schema_version]).to eq(26_03)
          end

          it 'includes latest_flag in the indexed json' do
            expect(indexed_json[:latest_flag]).to include(
              'status' => 'detected_as_fp',
              'origin' => 'ai_sast_fp_detection',
              'confidence_score' => 0.9
            )
          end
        end

        context 'when latest_flag migration has not completed' do
          before do
            set_elasticsearch_migration_to(:add_latest_flag_field_to_vulnerability_reads, including: false)
          end

          it 'returns schema version without latest_flag' do
            expect(indexed_json[:schema_version]).to eq(26_02)
          end

          it 'does not assign latest_flag on the indexed json' do
            expect(indexed_json[:latest_flag]).to be_blank
          end
        end
      end
    end
  end

  describe '.preload_indexing_data' do
    let(:vulnerability_ref) { described_class.new(vulnerability_read[:id], vulnerability_read.es_parent) }
    let(:user_vulnerability_ref) do
      described_class.new(user_vulnerability_read[:id], user_vulnerability_read.es_parent)
    end

    let(:refs) { [vulnerability_ref, user_vulnerability_ref] }

    it 'preloads vulnerability records' do
      expect(::Vulnerabilities::Read).to receive(:preload_indexing_data).and_call_original

      described_class.preload_indexing_data(refs)

      expect(vulnerability_ref.database_record).to be_present
      expect(user_vulnerability_ref.database_record).to be_present
    end

    context 'with reachability data' do
      let!(:sbom_occurrence_1) do
        create(:sbom_occurrence, reachability: 'in_use')
      end

      let!(:sbom_occurrence_2) do
        create(:sbom_occurrence, reachability: 'unknown')
      end

      let!(:sbom_occurrences_vulnerability_1) do
        create(:sbom_occurrences_vulnerability,
          occurrence: sbom_occurrence_1,
          vulnerability_id: vulnerability_read.vulnerability_id,
          vulnerability_occurrence_id: vulnerability_read.vulnerability_occurrence_id)
      end

      let!(:sbom_occurrences_vulnerability_2) do
        create(:sbom_occurrences_vulnerability,
          occurrence: sbom_occurrence_2,
          vulnerability_id: user_vulnerability_read.vulnerability_id,
          vulnerability_occurrence_id: user_vulnerability_read.vulnerability_occurrence_id)
      end

      it 'preserves reachability data after preloading' do
        described_class.preload_indexing_data(refs)

        expect(vulnerability_ref.database_record.reachability).to eq(
          sbom_occurrence_1.reachability_before_type_cast)
        expect(user_vulnerability_ref.database_record.reachability).to eq(
          sbom_occurrence_2.reachability_before_type_cast)
      end
    end

    context 'with false positive data' do
      let!(:false_positive_flag) do
        create(
          :vulnerabilities_flag,
          flag_type: :false_positive,
          status: :detected_as_fp,
          finding: vulnerability_read.vulnerability_occurrence
        )
      end

      it 'preserves false positive flag after preloading' do
        described_class.preload_indexing_data(refs)

        expect(vulnerability_ref.database_record.false_positive).to be(true)
        expect(user_vulnerability_ref.database_record.false_positive).to be(false)
      end
    end

    context 'with undetected_since data' do
      let(:transition_time) { 2.days.ago }
      let!(:transition) do
        create(:vulnerability_detection_transition, finding: vulnerability_read.vulnerability_occurrence,
          detected: false, created_at: transition_time)
      end

      it 'preloads undetected_since' do
        described_class.preload_indexing_data(refs)

        expect(vulnerability_ref.database_record.undetected_since).to be_within(0.1.seconds).of(transition_time)
        expect(user_vulnerability_ref.database_record.undetected_since).to be_nil
      end
    end

    context 'with token_status data' do
      let!(:secret_finding) do
        create(
          :vulnerabilities_finding,
          report_type: :secret_detection,
          vulnerability: vulnerability,
          project: project
        )
      end

      let!(:finding_token_status) do
        create(
          :finding_token_status,
          finding: secret_finding,
          project: project,
          status: ::Security::TokenStatus::ACTIVE
        )
      end

      before do
        vulnerability_read.update_column(:vulnerability_occurrence_id, secret_finding.id)
      end

      it 'preserves token_status after preloading' do
        described_class.preload_indexing_data(refs)

        expect(vulnerability_ref.database_record.token_status)
          .to eq(::Security::TokenStatus::ACTIVE)

        expect(user_vulnerability_ref.database_record.token_status)
          .to be_nil
      end
    end

    context 'with policy_violations data' do
      before do
        create(:policy_dismissal, :preserved, project: project, security_findings_uuids: [vulnerability_read.uuid])
      end

      it 'preloads policy_violations' do
        described_class.preload_indexing_data(refs)

        expect(vulnerability_ref.database_record.policy_violations).to eq(::Security::PolicyViolations::DISMISSED_IN_MR)
        expect(user_vulnerability_ref.database_record.policy_violations).to eq(
          ::Security::PolicyViolations::NOT_APPLICABLE)
      end
    end

    context 'with policy_auto_dismissed data' do
      before do
        vulnerability_read.vulnerability.update!(state: 'dismissed', dismissed_by: create(:user, :security_policy_bot))
      end

      it 'preloads policy_auto_dismissed' do
        described_class.preload_indexing_data(refs)

        expect(vulnerability_ref.database_record.policy_auto_dismissed).to be(true)
        expect(user_vulnerability_ref.database_record.policy_auto_dismissed).to be(false)
      end
    end

    context 'with latest_flag data' do
      it 'preloads latest_flag', :aggregate_failures do
        create(
          :vulnerabilities_flag,
          flag_type: :false_positive,
          status: :detected_as_fp,
          origin: 'ai_sast_fp_detection',
          confidence_score: 0.85,
          finding: vulnerability_read.vulnerability_occurrence
        )

        described_class.preload_indexing_data(refs)

        expect(vulnerability_ref.database_record.latest_flag).to include(
          status: 'detected_as_fp',
          origin: 'ai_sast_fp_detection',
          confidence_score: 0.85
        )
        expect(user_vulnerability_ref.database_record.latest_flag).to be_nil
      end
    end

    context 'for database_record' do
      it 'without preloading returns an instance of model class' do
        expect(vulnerability_ref.database_record).to be_an_instance_of(described_class.model_klass)
      end

      it 'with preloading it returns the proxy record' do
        described_class.preload_indexing_data(refs)

        expect(vulnerability_ref.database_record).to be_an_instance_of(Search::Elastic::RecordProxy::Vulnerability)
      end
    end

    context 'when checking for N+1 queries' do
      it 'does not have N+1 queries when preloading multiple references' do
        stub_env('GITALY_DISABLE_REQUEST_LIMITS', 'true')

        project1 = create(:project, group: group)
        project2 = create(:project, namespace: create(:namespace, organization: group.organization))

        vulnerability1 = SecApplicationRecord.feature_flagged_transaction_for(project1) do
          create(:vulnerability, :with_finding, :with_read, :dismissed,
            dismissed_by: create(:user, :security_policy_bot), project: project1, report_type: :secret_detection)
        end
        vulnerability2 = SecApplicationRecord.feature_flagged_transaction_for(project2) do
          create(:vulnerability, :with_finding, :with_read, project: project2,
            report_type: :secret_detection)
        end

        sbom_occurrence1 = create(:sbom_occurrence, reachability: 'in_use')
        sbom_occurrence2 = create(:sbom_occurrence, reachability: 'unknown')

        vulnerability_read1 = vulnerability1.vulnerability_read
        vulnerability_read2 = vulnerability2.vulnerability_read
        finding1 = vulnerability_read1.vulnerability_occurrence
        finding2 = vulnerability_read2.vulnerability_occurrence

        create(:sbom_occurrences_vulnerability,
          occurrence: sbom_occurrence1,
          vulnerability_id: vulnerability_read1.vulnerability_id)
        create(:sbom_occurrences_vulnerability,
          occurrence: sbom_occurrence2,
          vulnerability_id: vulnerability_read2.vulnerability_id)

        create(:policy_dismissal, :preserved, project: project1, security_findings_uuids: [vulnerability_read1.uuid])
        create(:policy_dismissal, :preserved, project: project2, security_findings_uuids: [vulnerability_read2.uuid])

        create(:vulnerability_finding_risk_score, finding: finding1, risk_score: 0.6)
        create(:vulnerability_finding_risk_score, finding: finding2, risk_score: 0.4)

        create(:vulnerabilities_flag, flag_type: :false_positive, finding: finding1)
        create(:vulnerabilities_flag, flag_type: :false_positive, finding: finding2)

        create(:finding_token_status, finding: finding1, project: project1, status: ::Security::TokenStatus::ACTIVE)
        create(:finding_token_status, finding: finding2, project: project2, status: ::Security::TokenStatus::INACTIVE)

        create(:vulnerability_detection_transition, finding: finding1, detected: false, created_at: 2.days.ago)
        create(:vulnerability_detection_transition, finding: finding2, detected: false, created_at: 1.day.ago)

        refs = [
          described_class.new(vulnerability_read1[:id], vulnerability_read1.es_parent)
        ]

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          described_class.preload_indexing_data(refs)
        end

        project3 = create(:project, group: group)

        vulnerability3 = SecApplicationRecord.feature_flagged_transaction_for(project3) do
          create(:vulnerability, :with_finding, :with_read, project: project3, report_type: :secret_detection)
        end

        sbom_occurrence3 = create(:sbom_occurrence, reachability: 'not_found')

        vulnerability_read3 = vulnerability3.vulnerability_read
        finding3 = vulnerability_read3.vulnerability_occurrence

        create(:sbom_occurrences_vulnerability,
          occurrence: sbom_occurrence3,
          vulnerability_id: vulnerability_read3.vulnerability_id)

        create(:policy_dismissal, :preserved, project: project3, security_findings_uuids: [vulnerability_read3.uuid])

        create(:vulnerability_finding_risk_score, finding: finding3, risk_score: 0.5)

        create(:vulnerabilities_flag, flag_type: :false_positive, finding: finding3)

        create(:finding_token_status, finding: finding3, project: project2, status: ::Security::TokenStatus::UNKNOWN)

        create(:vulnerability_detection_transition, finding: finding3, detected: false, created_at: 3.days.ago)

        vulnerability4 = create(:vulnerability, :with_read, :dismissed,
          dismissed_by: create(:user, :security_policy_bot), project: project3, report_type: :secret_detection)
        vulnerability_read4 = vulnerability4.vulnerability_read

        refs += [
          described_class.new(vulnerability_read2[:id], vulnerability_read2.es_parent),
          described_class.new(vulnerability_read3[:id], vulnerability_read3.es_parent),
          described_class.new(vulnerability_read4[:id], vulnerability_read4.es_parent)
        ]

        expect { described_class.preload_indexing_data(refs) }.not_to exceed_all_query_limit(control)
        expect { refs.each(&:as_indexed_json) }.not_to exceed_all_query_limit(0)
      end
    end

    context 'when BackfillOccurrenceIdToVulnerabilityReads BBM is not completed' do
      let(:refs) { [described_class.new(vulnerability_read[:id], vulnerability_read.es_parent)] }

      before do
        allow(described_class).to receive(:backfill_occurrence_id_completed?).and_return(false)
      end

      it 'returns refs without preloading' do
        expect(::Vulnerabilities::Read).not_to receive(:preload_indexing_data)

        expect(described_class.preload_indexing_data(refs)).to eq(refs)
      end
    end
  end

  describe '.backfill_occurrence_id_completed?' do
    before do
      allow(described_class).to receive(:backfill_occurrence_id_completed?).and_call_original
    end

    context 'when BBM has finished' do
      let(:batched_migration) do
        instance_double(
          Gitlab::Database::BackgroundMigration::BatchedMigration,
          finished?: true,
          finalized?: false
        )
      end

      before do
        allow(Gitlab::Database::BackgroundMigration::BatchedMigration)
          .to receive(:find_for_configuration)
          .with(:gitlab_sec, 'BackfillOccurrenceIdToVulnerabilityReads', :vulnerability_reads, :id, [])
          .and_return(batched_migration)
      end

      it { expect(described_class.send(:backfill_occurrence_id_completed?)).to be(true) }
    end

    context 'when BBM does not exist' do
      before do
        allow(Gitlab::Database::BackgroundMigration::BatchedMigration)
          .to receive(:find_for_configuration)
          .with(:gitlab_sec, 'BackfillOccurrenceIdToVulnerabilityReads', :vulnerability_reads, :id, [])
          .and_return(nil)
      end

      it { expect(described_class.send(:backfill_occurrence_id_completed?)).to be(false) }
    end

    context 'when BBM exists but is not finished' do
      let(:batched_migration) do
        instance_double(
          Gitlab::Database::BackgroundMigration::BatchedMigration,
          finished?: false,
          finalized?: false
        )
      end

      before do
        allow(Gitlab::Database::BackgroundMigration::BatchedMigration)
          .to receive(:find_for_configuration)
          .with(:gitlab_sec, 'BackfillOccurrenceIdToVulnerabilityReads', :vulnerability_reads, :id, [])
          .and_return(batched_migration)
      end

      it { expect(described_class.send(:backfill_occurrence_id_completed?)).to be(false) }
    end

    context 'when BBM is finalized' do
      let(:batched_migration) do
        instance_double(
          Gitlab::Database::BackgroundMigration::BatchedMigration,
          finished?: false,
          finalized?: true
        )
      end

      before do
        allow(Gitlab::Database::BackgroundMigration::BatchedMigration)
          .to receive(:find_for_configuration)
          .with(:gitlab_sec, 'BackfillOccurrenceIdToVulnerabilityReads', :vulnerability_reads, :id, [])
          .and_return(batched_migration)
      end

      it { expect(described_class.send(:backfill_occurrence_id_completed?)).to be(true) }
    end
  end

  describe '#fetch_record_attribute' do
    let(:vulnerability_ref) { described_class.new(vulnerability_read[:id], vulnerability_read.es_parent) }

    subject(:fetch_record_attribute) do
      vulnerability_ref.send(:fetch_record_attribute, record, attribute)
    end

    context 'when record responds to the attribute' do
      let(:record) { vulnerability_read }
      let(:attribute) { :reachability }
      let(:expected_result) { 1 }

      before do
        allow(record).to receive(attribute).and_return(expected_result)
        allow(record).to receive(:respond_to?).with(attribute).and_return(true)
      end

      it 'returns the attribute value' do
        expect(fetch_record_attribute).to eq(expected_result)
      end
    end

    context 'when record does not respond to the attribute' do
      let(:record) { vulnerability_read }
      let(:attribute) { :non_existent_attribute }

      before do
        allow(record).to receive(:respond_to?).with(attribute).and_return(false)
      end

      it 'returns an empty array' do
        expect(fetch_record_attribute).to eq([])
      end
    end
  end

  describe '#instantiate' do
    let(:vulnerability_ref) { described_class.new(vulnerability_read[:id], vulnerability_read.es_parent) }

    it 'instantiates from a serialized string' do
      new_ref = described_class.instantiate(vulnerability_ref.serialize)
      expect(new_ref.routing).to eq(vulnerability_read.es_parent)
      expect(new_ref.identifier).to eq(vulnerability_read[:id])
    end
  end

  describe '#serialize' do
    it 'returns serialized string from class method' do
      expect(described_class.serialize(vulnerability_read)).to eq(
        "Vulnerabilities::Read|#{vulnerability_read[:id]}|#{vulnerability_read.es_parent}")
    end

    it 'returns serialized string from instance method' do
      expect(described_class.new(vulnerability_read[:id],
        vulnerability_read.es_parent).serialize).to eq(
          "Vulnerabilities::Read|#{vulnerability_read[:id]}|#{vulnerability_read.es_parent}")
    end
  end

  describe '#klass' do
    it 'returns the full namespaced class name' do
      ref = described_class.new(vulnerability_read[:id], vulnerability_read.es_parent)
      expect(ref.klass).to eq('Vulnerabilities::Read')
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name from class method' do
      expect(described_class.index).to eq('gitlab-test-vulnerability_reads')
    end

    it 'returns correct environment based index name from instance method' do
      expect(described_class.new(vulnerability_read[:id],
        vulnerability_read.es_parent).index_name).to eq('gitlab-test-vulnerability_reads')
    end
  end

  describe '.model_klass' do
    it 'returns Vulnerabilities::Read' do
      expect(described_class.model_klass).to eq(::Vulnerabilities::Read)
    end
  end

  describe '#operation' do
    context 'when database record exists' do
      it 'returns :index' do
        ref = described_class.new(vulnerability_read[:id], vulnerability_read.es_parent)
        expect(ref.operation).to eq(:index)
      end
    end

    context 'when database record does not exist' do
      it 'returns :delete' do
        ref = described_class.new(0, 'group_1')
        expect(ref.operation).to eq(:delete)
      end
    end
  end
end
