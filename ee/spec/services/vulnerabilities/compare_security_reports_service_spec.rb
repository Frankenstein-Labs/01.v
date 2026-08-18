# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::CompareSecurityReportsService, :clean_gitlab_redis_shared_state, feature_category: :vulnerability_management do
  subject(:comparison) { service.execute(base_pipeline, head_pipeline) }

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { project.owner.tap { |user| user.namespace.create_namespace_settings } }
  let_it_be(:test_pipelines) do
    {
      default_base: create(:ee_ci_pipeline),
      with_dependency_scanning_report: create(:ee_ci_pipeline, :with_dependency_scanning_report, project: project),
      with_container_scanning_report: create(:ee_ci_pipeline, :with_container_scanning_report, project: project),
      with_dast_report: create(:ee_ci_pipeline, :with_dast_report, project: project),
      with_sast_report: create(:ee_ci_pipeline, :with_sast_report, project: project),
      with_secret_detection_report: create(:ee_ci_pipeline, :with_secret_detection_report, project: project),
      with_dependency_scanning_feature_branch: create(:ee_ci_pipeline, :with_dependency_scanning_feature_branch,
        project: project),
      with_container_scanning_feature_branch: create(:ee_ci_pipeline, :with_container_scanning_feature_branch,
        project: project),
      with_dast_feature_branch: create(:ee_ci_pipeline, :with_dast_feature_branch, project: project),
      with_sast_feature_branch: create(:ee_ci_pipeline, :with_sast_feature_branch, project: project),
      with_secret_detection_feature_branch: create(:ee_ci_pipeline, :with_secret_detection_feature_branch,
        project: project),
      with_corrupted_dependency_scanning_report: create(:ee_ci_pipeline, :with_corrupted_dependency_scanning_report,
        project: project),
      with_corrupted_container_scanning_report: create(:ee_ci_pipeline, :with_corrupted_container_scanning_report,
        project: project),
      advanced_sast: create(:ee_ci_pipeline, :advanced_sast, project: project),
      sast_differential_scan: create(:ee_ci_pipeline, :sast_differential_scan, project: project)
    }
  end

  let(:params) { { report_type: scan_type.to_s } }
  let(:service) { described_class.new(project, current_user, params) }

  before do
    stub_feature_flags(security_mr_reports_tab_full_data_set: false)
  end

  # This method creates a pipeline with multiple security scans and findings.
  # It allows associating each scan with a specific scanner and configuring
  # whether the scan is partial or not.
  def create_pipeline_with_scans_and_findings(configs, project:)
    pipeline = create(:ee_ci_pipeline, project: project, status: :success)

    configs.each do |config|
      scan_type = config[:scan_type]
      scanner = config[:scanner]
      build_trait = config[:build_trait]
      finding_uuid = config.fetch(:finding_uuid, SecureRandom.uuid)
      is_partial = config.fetch(:partial, false)

      build = create(:ee_ci_build, build_trait, pipeline: pipeline, project: project)

      scan = create(
        :security_scan,
        build: build,
        status: :succeeded,
        project: project,
        pipeline: pipeline,
        scan_type: scan_type
      )

      create(:vulnerabilities_partial_scan, scan: scan) if is_partial

      # Create finding with the specified scanner
      create(
        :security_finding,
        :with_finding_data,
        uuid: finding_uuid,
        deduplicated: true,
        scan: scan,
        scanner: scanner
      )
    end

    pipeline
  end

  def create_scan_with_findings(scan_type, pipeline, count = 1, partial: false)
    scan = create(
      :security_scan,
      :latest_successful,
      project: project,
      pipeline: pipeline,
      scan_type: scan_type
    )

    create(:vulnerabilities_partial_scan, scan: scan) if partial

    create_list(
      :security_finding,
      count,
      :with_finding_data,
      deduplicated: true,
      scan: scan
    )
  end

  before_all do
    create_scan_with_findings('dependency_scanning', test_pipelines[:with_dependency_scanning_report], 4)
    create_scan_with_findings('container_scanning', test_pipelines[:with_container_scanning_report], 8)
    create_scan_with_findings('dast', test_pipelines[:with_dast_report], 20)
    create_scan_with_findings('sast', test_pipelines[:with_sast_report], 5)
    create_scan_with_findings('secret_detection', test_pipelines[:with_secret_detection_report])
    create_scan_with_findings('dependency_scanning', test_pipelines[:with_dependency_scanning_feature_branch], 4)
    create_scan_with_findings('container_scanning', test_pipelines[:with_container_scanning_feature_branch], 8)
    create_scan_with_findings('dast', test_pipelines[:with_dast_feature_branch], 20)
    create_scan_with_findings('sast', test_pipelines[:with_sast_feature_branch], 5)
    create_scan_with_findings('sast', test_pipelines[:advanced_sast], 7)
    create_scan_with_findings('sast', test_pipelines[:sast_differential_scan], 7, partial: true)
    create_scan_with_findings('secret_detection', test_pipelines[:with_secret_detection_feature_branch])
  end

  shared_examples_for 'serializes `found_by_pipeline` attribute' do
    let(:first_added_finding) { comparison.dig(:data, 'added').first }
    let(:first_fixed_finding) { comparison.dig(:data, 'fixed').first }

    it 'sets correct `found_by_pipeline` attribute' do
      expect(first_added_finding.dig('found_by_pipeline', 'iid')).to eq(head_pipeline.iid)
      expect(first_fixed_finding.dig('found_by_pipeline', 'iid')).to eq(base_pipeline.iid)
    end
  end

  shared_examples_for 'when only the head pipeline has a report' do
    let(:base_pipeline) { test_pipelines[:default_base] }
    let(:head_pipeline) { test_pipelines[:"with_#{scan_type}_report"] }

    it 'reports the new vulnerabilities, while not changing the counts of fixed vulnerabilities' do
      expect(comparison[:status]).to eq(:parsed)
      expect(comparison[:data]['added'].count).to eq(num_findings_in_fixture)
      expect(comparison[:data]['fixed'].count).to eq(0)
    end
  end

  shared_examples_for 'when base and head pipelines have scanning reports' do
    let_it_be(:base_pipeline) { test_pipelines[:"with_#{scan_type}_report"] }
    let_it_be(:head_pipeline) { test_pipelines[:"with_#{scan_type}_feature_branch"] }
    let(:expected_payload_fields) do
      %w[create_vulnerability_feedback_issue_path create_vulnerability_feedback_merge_request_path
        create_vulnerability_feedback_dismissal_path]
    end

    it 'reports status as parsed' do
      expect(comparison[:status]).to eq(:parsed)
    end

    it 'populates fields based on current_user' do
      payload = comparison[:data]['added'].first
      expected_payload_fields.each { |f| expect(payload[f]).to be_present }
      expect(service.current_user).to eq(current_user)
    end

    it 'reports added vulnerabilities' do
      expect(comparison[:data]['added'].size).to eq(num_added_findings)
    end

    it 'reports fixed vulnerabilities' do
      expect(comparison[:data]['fixed'].size).to eq(num_fixed_findings)
    end
  end

  shared_examples_for 'when head pipeline has corrupted scanning reports' do
    let_it_be(:base_pipeline) { test_pipelines[:"with_corrupted_#{scan_type}_report"] }
    let_it_be(:head_pipeline) { test_pipelines[:"with_corrupted_#{scan_type}_report"] }

    it 'returns status and error message' do
      expect(comparison[:status]).to eq(:error)
      expect(comparison[:status_reason]).to include('JSON parsing failed')
    end

    it 'returns status and error message when pipeline is nil' do
      result = service.execute(nil, head_pipeline)

      expect(result[:status]).to eq(:error)
      expect(result[:status_reason]).to include('JSON parsing failed')
    end
  end

  shared_examples_for 'when a pipeline has scan that is not in the `succeeded` state' do
    let_it_be(:base_pipeline) { test_pipelines[:default_base] }
    let_it_be(:head_pipeline) { test_pipelines[:"with_#{scan_type}_feature_branch"] }

    let_it_be(:incomplete_scan) do
      create(
        :security_scan,
        build: head_pipeline.builds.last,
        status: :created,
        scan_type: scan_type
      )
    end

    it 'reports status as parsing' do
      expect(comparison[:status]).to eq(:parsing)
    end

    it 'has the parsing payload' do
      payload = comparison[:key]
      expect(payload).to include(base_pipeline.id, head_pipeline.id)
    end
  end

  describe '#execute' do
    before do
      stub_licensed_features(security_dashboard: true, scan_type => true)
    end

    context 'when there is a different scan in the same build that is not ready yet' do
      let_it_be(:scan_type) { :dependency_scanning }
      let_it_be(:base_pipeline) { test_pipelines[:default_base] }
      let_it_be(:head_pipeline) { test_pipelines[:with_dependency_scanning_feature_branch] }
      let_it_be(:incomplete_scan) do
        create(
          :security_scan,
          build: head_pipeline.builds.last,
          status: :created,
          scan_type: :container_scanning
        )
      end

      let_it_be(:complete_scan) do
        create(
          :security_scan,
          :latest_successful,
          project: project,
          build: head_pipeline.builds.last,
          scan_type: scan_type
        )
      end

      it 'reports status as parsed' do
        expect(comparison[:status]).to eq(:parsed)
      end
    end

    context 'with dependency_scanning' do
      let_it_be(:scan_type) { :dependency_scanning }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 4 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 4 }
        let(:num_added_findings) { 4 }

        it_behaves_like 'serializes `found_by_pipeline` attribute'
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    context 'with container_scanning' do
      let_it_be(:scan_type) { :container_scanning }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 8 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 8 }
        let(:num_added_findings) { 8 }

        it_behaves_like 'serializes `found_by_pipeline` attribute'
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    context 'with dast' do
      let_it_be(:scan_type) { :dast }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 20 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 20 }
        let(:num_added_findings) { 20 }

        it_behaves_like 'serializes `found_by_pipeline` attribute'
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    context 'with sast' do
      let_it_be(:scan_type) { :sast }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 5 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 5 }
        let(:num_added_findings) { 5 }

        it_behaves_like 'serializes `found_by_pipeline` attribute'
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'

      context 'when scan_mode is partial' do
        let(:params) { { report_type: 'sast', scan_mode: 'partial' } }

        it_behaves_like 'when only the head pipeline has a report' do
          let_it_be(:head_pipeline) { test_pipelines[:sast_differential_scan] }
          let(:num_findings_in_fixture) { 7 }
        end

        it_behaves_like 'when base and head pipelines have scanning reports' do
          let_it_be(:base_pipeline) { test_pipelines[:advanced_sast] }
          let_it_be(:head_pipeline) { test_pipelines[:sast_differential_scan] }

          # For partial scans we hide the fixed findings since we don't have full coverage.
          let(:num_fixed_findings) { 0 }
          let(:num_added_findings) { 7 }
        end

        context 'when base pipeline contains the same findings' do
          let_it_be(:base_pipeline) { create(:ee_ci_pipeline, :advanced_sast, project: project) }
          let_it_be(:head_pipeline) { create(:ee_ci_pipeline, :sast_differential_scan, project: project) }
          # We need to set explict uuids on the findings to test this
          let_it_be(:base_pipeline_uuids) { Array.new(3).map { SecureRandom.uuid } }
          let_it_be(:new_finding_uuid) { SecureRandom.uuid }
          let_it_be(:head_pipeline_uuids) { base_pipeline_uuids + [new_finding_uuid] }
          let_it_be(:base_scan) do
            create(
              :security_scan,
              :latest_successful,
              project: project,
              pipeline: base_pipeline,
              scan_type: scan_type
            )
          end

          let_it_be(:head_scan) do
            create(
              :security_scan,
              :latest_successful,
              project: project,
              pipeline: head_pipeline,
              scan_type: scan_type
            ).tap { |scan| create(:vulnerabilities_partial_scan, scan: scan) }
          end

          before_all do
            base_pipeline_uuids.each do |uuid|
              create(
                :security_finding,
                :with_finding_data,
                uuid: uuid,
                deduplicated: true,
                scan: base_scan
              )
            end

            head_pipeline_uuids.each do |uuid|
              create(
                :security_finding,
                :with_finding_data,
                uuid: uuid,
                deduplicated: true,
                scan: head_scan
              )
            end
          end

          it 'adds only the new finding' do
            added = comparison.dig(:data, 'added')

            expect(added.size).to eq(1)
            expect(added.first['uuid']).to eq(new_finding_uuid)
          end
        end
      end

      context 'when scan_mode is full and head pipeline contains both full and partial scans' do
        let(:params) { { report_type: 'sast', scan_mode: 'full' } }

        let_it_be(:semgrep_scanner) { create(:vulnerabilities_scanner, project: project, external_id: 'semgrep') }
        let_it_be(:advanced_sast_scanner) do
          create(:vulnerabilities_scanner, project: project, external_id: 'gitlab-advanced-sast')
        end

        let_it_be(:semgrep_base_uuid) { SecureRandom.uuid }
        let_it_be(:semgrep_head_uuid) { SecureRandom.uuid }

        # Create base pipeline with full scans for both semgrep and advanced SAST
        let_it_be(:base_pipeline) do
          create_pipeline_with_scans_and_findings(
            [
              { scan_type: 'sast', scanner: semgrep_scanner,
                build_trait: :sast_semgrep, finding_uuid: semgrep_base_uuid },
              { scan_type: 'sast', scanner: advanced_sast_scanner,
                build_trait: :advanced_sast }
            ],
            project: project
          )
        end

        # Create head pipeline with semgrep and partial advanced SAST scans
        let_it_be(:head_pipeline) do
          create_pipeline_with_scans_and_findings(
            [
              { scan_type: 'sast', scanner: semgrep_scanner,
                build_trait: :sast_semgrep, finding_uuid: semgrep_head_uuid },
              { scan_type: 'sast', scanner: advanced_sast_scanner,
                build_trait: :sast_differential_scan, partial: true }
            ],
            project: project
          )
        end

        let(:fixed_findings) { comparison[:data]['fixed'] }
        let(:added_findings) { comparison[:data]['added'] }

        it 'includes only findings from full scanners in fixed list' do
          expect(fixed_findings.count).to eq(1)
          expect(fixed_findings.first['uuid']).to eq(semgrep_base_uuid)
        end

        it 'includes only full scan findings in added list' do
          expect(added_findings.count).to eq(1)
          expect(added_findings.first['uuid']).to eq(semgrep_head_uuid)
        end
      end
    end

    context 'with secret detection' do
      let_it_be(:scan_type) { :secret_detection }

      it_behaves_like 'when only the head pipeline has a report' do
        let(:num_findings_in_fixture) { 1 }
      end

      it_behaves_like 'when base and head pipelines have scanning reports' do
        let(:num_fixed_findings) { 0 }
        let(:num_added_findings) { 1 }
        let(:expected_payload_fields) { [] }
      end

      it_behaves_like 'when a pipeline has scan that is not in the `succeeded` state'
    end

    context 'when head_pipeline is nil and scan_mode is full' do
      let_it_be(:scan_type) { :sast }
      let_it_be(:base_pipeline) { test_pipelines[:with_sast_report] }
      let(:head_pipeline) { nil }
      let(:params) { { report_type: 'sast', scan_mode: 'full' } }

      it 'reports status as parsed' do
        expect(comparison[:status]).to eq(:parsed)
      end
    end

    describe 'order of findings' do
      let(:head_pipeline) { create(:ee_ci_pipeline, :with_sast_report, project: project) }
      let(:base_pipeline) { test_pipelines[:default_base] }
      let(:scan_type) { 'sast' }

      let(:scan) do
        create(
          :security_scan,
          :latest_successful,
          project: project,
          pipeline: head_pipeline,
          scan_type: scan_type
        )
      end

      let!(:medium_finding) do
        create(
          :security_finding,
          :with_finding_data,
          deduplicated: true,
          severity: Enums::Vulnerability.severity_levels[:medium],
          scan: scan
        )
      end

      let!(:high_finding) do
        create(
          :security_finding,
          :with_finding_data,
          deduplicated: true,
          severity: Enums::Vulnerability.severity_levels[:high],
          scan: scan
        )
      end

      let!(:critical_finding) do
        create(
          :security_finding,
          :with_finding_data,
          deduplicated: true,
          severity: Enums::Vulnerability.severity_levels[:critical],
          scan: scan
        )
      end

      it 'returns findings in decreasing order of severity' do
        added_findings_ids = comparison[:data]['added'].pluck("id")

        expect(added_findings_ids[0]).to eq(critical_finding.id)
        expect(added_findings_ids[1]).to eq(high_finding.id)
        expect(added_findings_ids[2]).to eq(medium_finding.id)
      end

      it 'returns findings in decreasing order with no more than MAX_FINDINGS_COUNT findings' do
        stub_const("Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer::MAX_FINDINGS_COUNT", 2)

        added_findings_ids = comparison[:data]['added'].pluck("id")

        expect(added_findings_ids.count).to eq(2)
        expect(added_findings_ids[0]).to eq(critical_finding.id)
        expect(added_findings_ids[1]).to eq(high_finding.id)
      end

      context 'when security_mr_reports_tab_full_data_set feature flag is enabled' do
        before do
          stub_feature_flags(security_mr_reports_tab_full_data_set: project)
          stub_const("Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer::MAX_FINDINGS_COUNT", 2)
        end

        it 'returns all findings without applying `MAX_FINDINGS_COUNT`' do
          added_findings_ids = comparison[:data]['added'].pluck("id")

          expect(added_findings_ids).to contain_exactly(
            critical_finding.id, high_finding.id, medium_finding.id
          )
        end
      end
    end

    describe 'policy auto-dismissal checks preloading' do
      let_it_be(:scan_type) { :sast }
      let_it_be(:base_pipeline) { test_pipelines[:default_base] }
      let_it_be(:head_pipeline) { test_pipelines[:with_sast_report] }

      before do
        stub_licensed_features(security_dashboard: true, sast: true, security_orchestration_policies: true)
      end

      context 'when there are no auto-dismiss policies' do
        it 'includes attribute matches_auto_dismiss_policy set to false' do
          expect(comparison.dig(:data, 'added')).to all match a_hash_including('matches_auto_dismiss_policy' => false)
        end
      end

      context 'when there are auto-dismiss policies' do
        let_it_be(:policy) do
          create(:security_policy, :vulnerability_management_policy, :auto_dismiss, linked_projects: [project])
        end

        let_it_be(:rule) do
          create(:vulnerability_management_policy_rule, :detected_file_path,
            security_policy: policy,
            file_path: 'test/**/*')
        end

        let!(:policy_finding) do
          create_scan_with_findings('sast', head_pipeline, 1).first.tap do |finding|
            finding.finding_data['location'] = { file: 'test/sample_spec.rb' }
            finding.save!
          end
        end

        it 'includes the attribute matches_auto_dismiss_policy with the correct value' do
          expect(Security::Findings::PolicyAutoDismissalChecker).to receive(:new).once.and_call_original
          expect(comparison.dig(:data, 'added')).to all include('matches_auto_dismiss_policy')

          matching_findings, non_matching_findings = comparison.dig(:data, 'added').partition do |finding|
            finding['matches_auto_dismiss_policy']
          end

          expect(matching_findings).to all match a_hash_including('matches_auto_dismiss_policy' => true)
          expect(non_matching_findings).to all match a_hash_including('matches_auto_dismiss_policy' => false)
        end

        context 'when feature is not licensed' do
          before do
            stub_licensed_features(security_dashboard: true, sast: true, security_orchestration_policies: false)
          end

          it 'does not include the attribute matches_auto_dismiss_policy' do
            expect(comparison.dig(:data, 'added')).to all match hash_excluding('matches_auto_dismiss_policy')
          end
        end
      end
    end

    describe 'policy severity override checks preloading' do
      let_it_be(:scan_type) { :sast }
      let_it_be(:base_pipeline) { test_pipelines[:default_base] }
      let_it_be(:head_pipeline) { test_pipelines[:with_sast_report] }

      before do
        stub_licensed_features(security_dashboard: true, sast: true, security_orchestration_policies: true)
      end

      context 'when there are no severity override policies' do
        it 'does not include auto_severity_override attribute' do
          expect(comparison.dig(:data, 'added')).to all match hash_excluding('auto_severity_override')
        end
      end

      context 'when there are severity override policies' do
        let_it_be(:policy) do
          create(:security_policy, :vulnerability_management_policy, :severity_override,
            severity_override_operation: 'set', severity_override_value: 'critical',
            linked_projects: [project])
        end

        let_it_be(:rule) do
          create(:vulnerability_management_policy_rule, :detected_file_path,
            security_policy: policy,
            file_path: 'test/**/*')
        end

        let_it_be(:policy_finding) do
          create_scan_with_findings('sast', head_pipeline, 1).first.tap do |finding|
            finding.finding_data['location'] = { file: 'test/sample_spec.rb' }
            finding.severity = Enums::Vulnerability.severity_levels[:low]
            finding.save!
          end
        end

        it 'includes auto_severity_override with the correct value for matching findings' do
          expect(Security::Findings::PolicySeverityOverrideChecker).to receive(:new).once.and_call_original

          matching_findings, non_matching_findings = comparison.dig(:data, 'added').partition do |finding|
            finding['auto_severity_override']
          end

          expect(matching_findings).to all match a_hash_including('auto_severity_override' => 'critical')
          expect(non_matching_findings).to all match hash_excluding('auto_severity_override')
        end

        context 'when feature is not licensed' do
          before do
            stub_licensed_features(security_dashboard: true, sast: true, security_orchestration_policies: false)
          end

          it 'does not include the auto_severity_override attribute' do
            expect(comparison.dig(:data, 'added')).to all match hash_excluding('auto_severity_override')
          end
        end
      end
    end
  end
end
