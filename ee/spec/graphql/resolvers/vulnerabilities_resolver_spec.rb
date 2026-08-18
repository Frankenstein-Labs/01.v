# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::VulnerabilitiesResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:resolved) { resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user, **extra_context }) }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }
    let_it_be(:user) { create(:user, security_dashboard_projects: [project]) }

    let_it_be(:low_vulnerability) do
      create(:vulnerability, :with_finding, :detected, :low, :dast, :with_issue_links, :with_merge_request_links, project: project)
    end

    let_it_be(:critical_vulnerability) do
      create(:vulnerability, :with_finding, :detected, :critical, :sast, resolved_on_default_branch: true, project: project)
        .tap { |v| v.vulnerability_read.update!(has_vulnerability_resolution: true) }
    end

    let_it_be(:high_vulnerability) do
      create(:vulnerability, :with_finding, :dismissed, :high, :container_scanning, project: project)
    end

    let(:current_user) { user }
    let(:params) { {} }
    let(:extra_context) { {} }
    let(:vulnerable) { project }

    context 'when security_dashboard feature is disabled' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'returns an empty collection' do
        expect(resolved).to be_empty
      end
    end

    shared_examples_for "a resolver with proper association preloading" do
      it "preloads necessary associations" do
        records = resolved.to_a

        expect do
          records.first.project.namespace
          records.first.project.group
          records.first.project.route
          records.first.finding.scanner
          records.first.finding.identifiers
          records.first.vulnerability_read
          records.first.dismissed_by
        end.not_to exceed_query_limit(0)
      end
    end

    context 'when given sort' do
      context 'when sorting descending by severity' do
        let(:params) { { sort: :severity_desc } }

        it { is_expected.to eq([critical_vulnerability, high_vulnerability, low_vulnerability]) }
      end

      context 'when sorting ascending by severity' do
        let(:params) { { sort: :severity_asc } }

        it { is_expected.to eq([low_vulnerability, high_vulnerability, critical_vulnerability]) }
      end

      context 'when sorting param is not provided' do
        let(:params) { {} }

        it { is_expected.to eq([critical_vulnerability, high_vulnerability, low_vulnerability]) }
      end

      context 'when sorting by invalid param' do
        let(:params) { { sort: :invalid } }

        it { is_expected.to eq([critical_vulnerability, high_vulnerability, low_vulnerability]) }
      end
    end

    context 'when given severities' do
      let(:params) { { severity: ['low'] } }

      it 'only returns vulnerabilities of the given severities' do
        is_expected.to contain_exactly(low_vulnerability)
      end
    end

    context 'when given states' do
      let(:params) { { state: ['dismissed'] } }

      it 'only returns vulnerabilities of the given states' do
        is_expected.to contain_exactly(high_vulnerability)
      end

      context 'when dismissal reason and state other than dismissed is given' do
        let(:params) { { state: %w[detected], dismissal_reason: %w[USED_IN_TESTS FALSE_POSITIVE] } }

        let_it_be(:dismissed_vulnerability_1) { create(:vulnerability, :dismissed, project: project) }
        let_it_be(:vulnerability_read_1) { create(:vulnerability_read, :used_in_tests, vulnerability: dismissed_vulnerability_1, project: project) }

        let_it_be(:dismissed_vulnerability_2) { create(:vulnerability, :dismissed, project: project) }
        let_it_be(:vulnerability_read_2) { create(:vulnerability_read, :false_positive, vulnerability: dismissed_vulnerability_2, project: project) }

        it 'returns only dissmissed Vulnerabilities with matching dismissal reason' do
          is_expected.to match_array([low_vulnerability, critical_vulnerability, dismissed_vulnerability_1, dismissed_vulnerability_2])
        end
      end
    end

    context 'when given scanner external IDs' do
      let(:params) { { scanner: [high_vulnerability.finding_scanner_external_id] } }

      it 'only returns vulnerabilities of the given scanner external IDs' do
        is_expected.to contain_exactly(high_vulnerability)
      end
    end

    context 'when given scanner ID' do
      let(:params) { { scanner_id: [GitlabSchema.id_from_object(high_vulnerability.finding.scanner)] } }

      it 'only returns vulnerabilities of the given scanner IDs' do
        is_expected.to contain_exactly(high_vulnerability)
      end
    end

    context 'when given report types' do
      let(:params) { { report_type: %i[dast sast] } }

      it 'only returns vulnerabilities of the given report types' do
        is_expected.to contain_exactly(critical_vulnerability, low_vulnerability)
      end
    end

    context 'when given value for hasIssues argument' do
      let(:params) { { has_issues: has_issues } }

      context 'when has_issues is set to true' do
        let(:has_issues) { true }

        it 'only returns vulnerabilities that have issues' do
          is_expected.to contain_exactly(low_vulnerability)
        end
      end

      context 'when has_issues is set to false' do
        let(:has_issues) { false }

        it 'only returns vulnerabilities that does not have issues' do
          is_expected.to contain_exactly(critical_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when given value for hasMergeRequest argument' do
      let(:params) { { has_merge_request: has_merge_request } }

      context 'when has_merge_request is set to true' do
        let(:has_merge_request) { true }

        it 'only returns vulnerabilities that have merge_request' do
          is_expected.to contain_exactly(low_vulnerability)
        end
      end

      context 'when has_issues is set to false' do
        let(:has_merge_request) { false }

        it 'only returns vulnerabilities that does not have merge_request' do
          is_expected.to contain_exactly(critical_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when given value for has_resolution argument' do
      let(:params) { { has_resolution: has_resolution } }

      context 'when has_resolution is set to true' do
        let(:has_resolution) { true }

        it 'only returns resolution that have resolution' do
          is_expected.to contain_exactly(critical_vulnerability)
        end
      end

      context 'when has_resolution is set to false' do
        let(:has_resolution) { false }

        it 'only returns resolution that does not have resolution' do
          is_expected.to contain_exactly(low_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when given value for has_ai_resolution argument' do
      let(:params) { { has_ai_resolution: has_ai_resolution } }

      context 'when has_ai_resolution is set to true' do
        let(:has_ai_resolution) { true }

        it 'only returns vulnerabilities that are eligible to be resolved by an LLM' do
          is_expected.to contain_exactly(critical_vulnerability)
        end
      end

      context 'when has_ai_resolution is set to false' do
        let(:has_ai_resolution) { false }

        it 'only returns vulnerabilities that are ineligible to be resolved by an LLM' do
          is_expected.to contain_exactly(low_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when given project IDs' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project2) { create(:project, namespace: group) }
      let_it_be(:project2_vulnerability) { create(:vulnerability, :with_read, :with_merge_request_links, project: project2) }

      let(:params) { { project_id: [project2.id] } }
      let(:vulnerable) { group }

      before do
        project.update!(namespace: group)
      end

      it 'only returns vulnerabilities belonging to the given projects' do
        is_expected.to contain_exactly(project2_vulnerability)
      end

      context 'with multiple project IDs' do
        let(:params) { { project_id: [project.id, project2.id] } }

        it 'avoids N+1 queries' do
          control = ActiveRecord::QueryRecorder.new do
            resolve(described_class, obj: vulnerable, args: { project_id: [project2.id] }, ctx: { current_user: current_user })
          end

          expect do
            resolved
          end.not_to exceed_query_limit(control)
        end
      end
    end

    context 'when resolving vulnerabilities for a project' do
      it "returns the project's vulnerabilities" do
        is_expected.to contain_exactly(critical_vulnerability, high_vulnerability, low_vulnerability)
      end
    end

    context 'when resolving vulnerabilities for an instance security dashboard' do
      before do
        project.add_developer(user)
      end

      let(:vulnerable) { InstanceSecurityDashboard.new(user, project_ids: [project.id]) }

      context 'when user has valid projects' do
        it "returns vulnerabilities for all projects on the current user's instance security dashboard" do
          is_expected.to contain_exactly(critical_vulnerability, high_vulnerability, low_vulnerability)
        end
      end

      context 'when user does not have valid projects' do
        let(:user) { create(:user) }
        let(:current_user) { nil }

        it 'returns no vulnerabilities' do
          is_expected.to be_empty
        end
      end
    end

    context 'when image is given' do
      let_it_be(:cluster_vulnerability) { create(:vulnerability, :cluster_image_scanning, project: project) }
      let_it_be(:cluster_finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, vulnerability: cluster_vulnerability, project: project) }

      let(:params) { { image: [cluster_finding.location['image']] } }

      it 'only returns vulnerabilities with given image' do
        is_expected.to contain_exactly(cluster_vulnerability)
      end

      context 'when different report_type is given along with image' do
        let(:params) { { report_type: %w[sast], image: [cluster_finding.location['image']] } }

        it 'returns empty list' do
          is_expected.to be_empty
        end
      end
    end

    context 'when cluster_id is given' do
      let_it_be(:cluster_agent) { create(:cluster_agent, project: project) }
      let_it_be(:cluster_vulnerability) { create(:vulnerability, :cluster_image_scanning, project: project) }
      let_it_be(:cluster_finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, agent_id: cluster_agent.id.to_s, vulnerability: cluster_vulnerability, project: project) }
      let_it_be(:cluster_gid) { ::Gitlab::GlobalId.as_global_id(cluster_finding.location['kubernetes_resource']['cluster_id'].to_i, model_name: 'Clusters::Cluster') }

      let(:params) { { cluster_id: [Gitlab::GlobalId.build(nil, model_name: 'Clusters::Cluster', id: non_existing_record_id)] } }

      it 'ignores the filter and returns unmatching vulnerabilities' do
        is_expected.to include(cluster_vulnerability)
      end
    end

    context 'when cluster_agent_id is given' do
      let_it_be(:cluster_agent) { create(:cluster_agent, project: project) }
      let_it_be(:cluster_vulnerability) { create(:vulnerability, :cluster_image_scanning, project: project) }
      let_it_be(:cluster_finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, agent_id: cluster_agent.id.to_s, project: project, vulnerability: cluster_vulnerability) }
      let_it_be(:cluster_gid) { ::Gitlab::GlobalId.as_global_id(cluster_finding.location['kubernetes_resource']['agent_id'].to_i, model_name: 'Clusters::Agent') }

      let(:params) { { cluster_agent_id: [cluster_gid] } }

      it 'only returns vulnerabilities with given cluster' do
        is_expected.to contain_exactly(cluster_vulnerability)
      end

      context 'when different report_type is given along with cluster' do
        let(:params) { { report_type: %w[sast], cluster_agent_id: [cluster_gid] } }

        it 'returns empty list' do
          is_expected.to be_empty
        end
      end
    end

    context 'when given value for has_remediations argument' do
      let(:params) { { has_remediations: has_remediations } }
      let_it_be(:vulnerability_read_with_remediations) { create(:vulnerability_read, :with_remediations, project: project) }

      context 'when has_remediations is set to true' do
        let(:has_remediations) { true }

        it 'only returns vulnerabilities that have remediations' do
          is_expected.to contain_exactly(vulnerability_read_with_remediations.vulnerability)
        end
      end

      context 'when has_remediations is set to false' do
        let(:has_remediations) { false }

        it 'only returns vulnerabilities that does not have remediations' do
          is_expected.to contain_exactly(low_vulnerability, critical_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when owasp_top_10 is given' do
      let(:params) { { owasp_top_ten: ['A1:2017-Injection'] } }

      let_it_be(:vuln_read_with_owasp_top_10_first) do
        create(:vulnerability_read, :with_owasp_top_10,
          owasp_top_10: 'A1:2017-Injection', severity: :high, project: project)
      end

      let_it_be(:vuln_read) { create(:vulnerability_read, severity: :medium) }

      it 'only returns vulnerabilities with owasp_top_10' do
        is_expected.to contain_exactly(vuln_read_with_owasp_top_10_first.vulnerability)
      end
    end

    context 'when filtering vulnerabilities with owasp_top_10_2021', :elastic do
      let(:params) do
        { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] }
      end

      let_it_be(:vuln_read_with_owasp_top_10_first) do
        create(:vulnerability_read, :with_owasp_top_10, severity: :high, project: project,
          identifier_names: ['A1:2021-Broken Access Control'])
      end

      let_it_be(:vuln_read_with_owasp_top_10_second) do
        create(:vulnerability_read, :with_owasp_top_10,
          owasp_top_10: 'A1:2021-Broken Access Control', severity: :low, project: project,
          identifier_names: ['A1:2021-Broken Access Control'])
      end

      let_it_be(:vuln_read) { create(:vulnerability_read, severity: :medium) }

      context 'with elastic search' do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            low_vulnerability.vulnerability_read,
            critical_vulnerability.vulnerability_read,
            high_vulnerability.vulnerability_read,
            vuln_read_with_owasp_top_10_first,
            vuln_read_with_owasp_top_10_second
          )
          ensure_elasticsearch_index!

          allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
        end

        it 'only returns vulnerabilities with matching owasp_top_10_2021 values in identifier_names' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

          results = resolved.to_a

          expect(results).to match_array([
            vuln_read_with_owasp_top_10_first,
            vuln_read_with_owasp_top_10_second
          ].map(&:vulnerability))
        end

        it 'avoids N+1 queries', :use_sql_query_cache do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user }).to_a
          end

          create(:vulnerability, :with_findings, project: project)
          .tap { |v| v.vulnerability_read.update!(identifier_names: ['A1:2021-Broken Access Control']) }
          ensure_elasticsearch_index!

          expect do
            resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user }).to_a
          end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
        end

        context 'with reachability as parameter' do
          using RSpec::Parameterized::TableSyntax

          let_it_be(:vuln_read_without_occurrences) do
            [
              low_vulnerability.vulnerability_read,
              critical_vulnerability.vulnerability_read,
              high_vulnerability.vulnerability_read,
              vuln_read_with_owasp_top_10_first,
              vuln_read_with_owasp_top_10_second
            ]
          end

          let_it_be(:vuln_read_in_use) do
            sbom_occurrence_in_use = create(:sbom_occurrence, reachability: :in_use)
            vuln_read = create(:vulnerability_read, report_type: :dependency_scanning, project: project)
            create(:sbom_occurrences_vulnerability, occurrence: sbom_occurrence_in_use, vulnerability: vuln_read.vulnerability)

            vuln_read
          end

          let_it_be(:vuln_read_not_found) do
            sbom_occurrence_not_found = create(:sbom_occurrence, reachability: :not_found)
            vuln_read = create(:vulnerability_read, report_type: :dependency_scanning, project: project)
            create(:sbom_occurrences_vulnerability, occurrence: sbom_occurrence_not_found, vulnerability: vuln_read.vulnerability)

            vuln_read
          end

          before do
            Elastic::ProcessBookkeepingService.track!(
              vuln_read_in_use,
              vuln_read_not_found
            )
            ensure_elasticsearch_index!
          end

          where(:reachability, :expected_result) do
            :in_use | [ref(:vuln_read_in_use)]
            :not_found | [ref(:vuln_read_not_found)]
            :unknown | ref(:vuln_read_without_occurrences)
          end

          with_them do
            let(:params) { { reachability: reachability } }

            it 'only returns vulnerabilities with matching reachability values' do
              expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

              results = resolved.to_a

              expect(results).to match_array(
                expected_result.map(&:vulnerability))
            end
          end
        end
      end
    end

    context 'when filtering vulnerabilities with owasp_top_10_2025', :elastic do
      let(:params) do
        { owasp_top_ten_2025: ['A01:2025-Broken Access Control'] }
      end

      let_it_be(:vuln_read_with_owasp_2025_first) do
        create(:vulnerability_read, :with_owasp_top_10, severity: :high, project: project,
          identifier_names: ['A01:2025-Broken Access Control'])
      end

      let_it_be(:vuln_read_with_owasp_2025_second) do
        create(:vulnerability_read, :with_owasp_top_10, severity: :low, project: project,
          identifier_names: ['A01:2025-Broken Access Control'])
      end

      let_it_be(:vuln_read) { create(:vulnerability_read, severity: :medium) }

      context 'with elastic search' do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            low_vulnerability.vulnerability_read,
            critical_vulnerability.vulnerability_read,
            high_vulnerability.vulnerability_read,
            vuln_read_with_owasp_2025_first,
            vuln_read_with_owasp_2025_second
          )
          ensure_elasticsearch_index!

          allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
        end

        it 'only returns vulnerabilities with matching owasp_top_10_2025 values in identifier_names' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

          results = resolved.to_a

          expect(results).to match_array([
            vuln_read_with_owasp_2025_first,
            vuln_read_with_owasp_2025_second
          ].map(&:vulnerability))
        end

        it 'avoids N+1 queries', :use_sql_query_cache do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user }).to_a
          end

          create(:vulnerability, :with_findings, project: project)
          .tap { |v| v.vulnerability_read.update!(identifier_names: ['A01:2025-Broken Access Control']) }
          ensure_elasticsearch_index!

          expect do
            resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user }).to_a
          end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
        end
      end
    end

    context 'with validity_check as parameter', :elastic do
      using RSpec::Parameterized::TableSyntax

      def create_vuln_with_status(severity:, status: nil)
        vuln = create(:vulnerability, :with_read, project: project, severity: severity)
        if status
          finding = create(
            :vulnerabilities_finding,
            report_type: :secret_detection,
            vulnerability: vuln,
            project: project
          )
          create(:finding_token_status, finding: finding, project: project, status: status)
        end

        vuln.vulnerability_read
      end

      let_it_be(:vuln_read_active)   { create_vuln_with_status(severity: :critical, status: :active) }
      let_it_be(:vuln_read_inactive) { create_vuln_with_status(severity: :high,     status: :inactive) }
      let_it_be(:vuln_read_unknown)  { create_vuln_with_status(severity: :medium,   status: :unknown) }
      let_it_be(:vuln_read_without_token) { create_vuln_with_status(severity: :low) }

      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

        Elastic::ProcessBookkeepingService.track!(
          vuln_read_active,
          vuln_read_inactive,
          vuln_read_unknown,
          vuln_read_without_token
        )
        ensure_elasticsearch_index!

        allow(current_user)
          .to receive(:can?)
          .with(:access_advanced_vulnerability_management, vulnerable)
          .and_return(true)
      end

      where(:validity_check, :expected_result) do
        :active   | { 'critical' => 1 }
        :inactive | { 'high' => 1 }
        :unknown  | { 'medium' => 1 }
      end

      with_them do
        let(:params) { { validity_check: [validity_check] } }

        it 'only considers vulnerabilities with matching token_status values' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

          results = resolved.to_a
          severities = results.map(&:severity)
          severity_counts = severities.tally.transform_keys(&:to_s)

          expect(severity_counts).to eq(expected_result)
        end
      end

      context 'when filtering vulnerabilities without token status' do
        let(:params) { { validity_check: [:unknown] } }

        it 'does not include vulnerabilities without token status in the results' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

          results = resolved.to_a
          severities = results.map(&:severity)
          severity_counts = severities.tally.transform_keys(&:to_s)

          # Should only match vuln_read_unknown (medium), not vuln_read_without_token (low)
          expect(severity_counts).to eq({ 'medium' => 1 })

          # Verify that the low severity vulnerability without token is not included
          expect(severity_counts.keys).not_to include('low')
        end
      end
    end

    context 'when filtering vulnerabilities with policy_violations', :elastic do
      let(:params) { { policy_violations: ['DISMISSED_IN_MR'] } }

      shared_examples_for 'when elasticsearch is available' do
        let_it_be(:dismissed_vulnerability_read) { create(:vulnerability_read, project: project) }

        let_it_be(:non_dismissed_vulnerability_read) { create(:vulnerability_read, project: project) }

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          create(:policy_dismissal, :preserved, project: project, security_findings_uuids: [dismissed_vulnerability_read.uuid])

          Elastic::ProcessBookkeepingService.track!(dismissed_vulnerability_read, non_dismissed_vulnerability_read)
          ensure_elasticsearch_index!

          allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
        end

        it 'only returns vulnerabilities with matching policy_violations types' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

          results = resolved.to_a

          expect(results).to match_array([dismissed_vulnerability_read].map(&:vulnerability))
        end
      end

      context 'when vulnerable is a project' do
        let(:vulnerable) { project }

        it_behaves_like 'when elasticsearch is available'
      end

      context 'when vulnerable is a group' do
        let(:vulnerable) { group }

        it_behaves_like 'when elasticsearch is available'
      end
    end

    context 'when filtering vulnerabilities with policy_auto_dismissed', :elastic do
      let(:params) { { policy_auto_dismissed: policy_auto_dismissed } }

      let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }
      let_it_be(:dismissed_vulnerability) { create(:vulnerability, :dismissed, dismissed_by: security_policy_bot, project: project) }
      let_it_be(:dismissed_vulnerability_read) { create(:vulnerability_read, vulnerability: dismissed_vulnerability, project: project) }

      let_it_be(:non_dismissed_vulnerability_read) { create(:vulnerability_read, project: project) }

      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

        Elastic::ProcessBookkeepingService.track!(dismissed_vulnerability_read, non_dismissed_vulnerability_read)
        ensure_elasticsearch_index!

        allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
      end

      shared_examples_for 'when elasticsearch is available' do
        context 'when filtering by auto dismissed vulnerabilities' do
          let(:policy_auto_dismissed) { true }

          it 'only returns vulnerabilities with matching policy_auto_dismissed' do
            expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

            results = resolved.to_a

            expect(results).to match_array([dismissed_vulnerability_read].map(&:vulnerability))
          end
        end

        context 'when filtering by not auto dismissed vulnerabilities' do
          let(:policy_auto_dismissed) { false }

          it 'only returns vulnerabilities with matching policy_auto_dismissed' do
            expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

            results = resolved.to_a

            expect(results).to match_array([non_dismissed_vulnerability_read].map(&:vulnerability))
          end
        end
      end

      context 'when vulnerable is a project' do
        let(:vulnerable) { project }

        it_behaves_like 'when elasticsearch is available'
      end

      context 'when vulnerable is a group' do
        let(:vulnerable) { group }

        it_behaves_like 'when elasticsearch is available'
      end

      context 'when vulnerable is nil' do
        let(:policy_auto_dismissed) { true }
        let(:vulnerable) { nil }
        let(:error_msg) { 'The filter policy_auto_dismissed is not available.' }

        it 'raises an error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, s_(error_msg)) do
            resolved
          end
        end
      end
    end

    context 'when filtering vulnerabilities with false_positive', :elastic do
      let(:params) { { false_positive: true } }

      let_it_be(:vulnerability_read_with_flag) { create_vulnerability_with_flag }
      let_it_be(:vulnerability_read_without_flag) { create_vulnerability_with_flag(has_flag: false) }

      def create_vulnerability_with_flag(has_flag: true)
        vulnerability = create(:vulnerability, :with_read, project: project)
        create(:vulnerabilities_finding, vulnerability: vulnerability)

        if has_flag
          create(
            :vulnerabilities_flag,
            :false_positive,
            status: :detected_as_fp,
            finding: vulnerability.findings.first
          )
        end

        vulnerability.vulnerability_read
      end

      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

        Elastic::ProcessBookkeepingService.track!(
          vulnerability_read_with_flag,
          vulnerability_read_without_flag
        )
        ensure_elasticsearch_index!

        allow(current_user)
          .to receive(:can?)
                .with(:access_advanced_vulnerability_management, vulnerable)
                .and_return(true)
      end

      shared_examples_for 'when elasticsearch is available' do
        it 'only returns vulnerabilities with matching false_positive' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

          results = resolved.to_a

          expect(results).to match_array([vulnerability_read_with_flag.vulnerability])
        end
      end

      context 'when vulnerable is a project' do
        let(:vulnerable) { project }

        it_behaves_like 'when elasticsearch is available'
      end

      context 'when vulnerable is a group' do
        let(:vulnerable) { group }

        it_behaves_like 'when elasticsearch is available'
      end

      context 'when vulnerable is nil' do
        let(:vulnerable) { nil }
        let(:error_msg) { 'The false_positive filter is not available.' }

        it 'raises an error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, s_(error_msg)) do
            resolved
          end
        end
      end
    end

    context 'when filtering vulnerabilities with malware', :elastic do
      let_it_be(:malware_vuln_read) do
        create(:vulnerability_read, :with_identifer_name,
          identifier_names: %w[GLAM-2024-001],
          project: project)
      end

      let_it_be(:non_malware_vuln_read) do
        create(:vulnerability_read, :with_identifer_name,
          identifier_names: ['CVE-2024-1234'],
          project: project)
      end

      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        stub_feature_flags(
          malicious_vulnerability_filter_group: true,
          malicious_vulnerability_filter_project: true
        )

        Elastic::ProcessBookkeepingService.track!(malware_vuln_read, non_malware_vuln_read)
        ensure_elasticsearch_index!

        allow(current_user)
          .to receive(:can?)
                .with(:access_advanced_vulnerability_management, vulnerable)
                .and_return(true)
      end

      shared_examples_for 'malware elasticsearch filter' do
        context 'when malware is true' do
          let(:params) { { malware: true } }

          it 'only returns malware vulnerabilities' do
            expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

            results = resolved.to_a

            expect(results).to match_array([malware_vuln_read.vulnerability])
          end
        end

        context 'when malware is false' do
          let(:params) { { malware: false } }

          it 'only returns non-malware vulnerabilities' do
            expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

            results = resolved.to_a

            expect(results).to match_array([non_malware_vuln_read.vulnerability])
          end
        end
      end

      context 'when vulnerable is a project' do
        let(:vulnerable) { project }

        it_behaves_like 'malware elasticsearch filter'
      end

      context 'when vulnerable is a group' do
        let(:vulnerable) { group }

        it_behaves_like 'malware elasticsearch filter'
      end

      context 'when the malware filter is not available' do
        let(:params) { { malware: true } }

        shared_examples 'raises malware filter not available' do
          it 'raises an argument error' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
              'The malware filter is not available.') do
              resolved
            end
          end
        end

        context 'when the filter feature flag is disabled' do
          before do
            stub_feature_flags(malicious_vulnerability_filter_group: false, malicious_vulnerability_filter_project: false)
          end

          context 'when vulnerable is a project' do
            let(:vulnerable) { project }

            it_behaves_like 'raises malware filter not available'
          end

          context 'when vulnerable is a group' do
            let(:vulnerable) { group }

            it_behaves_like 'raises malware filter not available'
          end
        end

        context 'when the add-on is not available' do
          before do
            stub_feature_flags(sscs_malware_detection: false)
          end

          context 'when vulnerable is a project' do
            let(:vulnerable) { project }

            it_behaves_like 'raises malware filter not available'
          end

          context 'when vulnerable is a group' do
            let(:vulnerable) { group }

            it_behaves_like 'raises malware filter not available'
          end
        end
      end
    end

    context 'when identifer_name is given' do
      let_it_be(:identifier_name) { 'CVE-2024-1234' }

      let_it_be(:vuln_read_with_identifier_name_first) do
        create(:vulnerability_read, :with_identifer_name, identifier_names: [identifier_name], project: project)
      end

      let_it_be(:vuln_read_with_identifier_name_second) do
        create(:vulnerability_read, :with_identifer_name, identifier_names: ['CVE-2024-1235'], project: project)
      end

      let_it_be(:vuln_read) { create(:vulnerability_read, severity: :medium) }

      let(:params) { { identifier_name: identifier_name } }

      shared_examples_for 'when elasticsearch is available', :elastic do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            vuln_read_with_identifier_name_first, vuln_read_with_identifier_name_second
          )
          ensure_elasticsearch_index!

          allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
        end

        it 'retuns vulnerabilities from elasticsearch' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original
          results = resolved.to_a

          expect(results).to match_array([vuln_read_with_identifier_name_first].map(&:vulnerability))
        end
      end

      context 'when vulnerable is a project' do
        it 'only returns vulnerabilities with matching identifier_name alone' do
          is_expected.to contain_exactly(vuln_read_with_identifier_name_first.vulnerability)
        end

        it_behaves_like 'when elasticsearch is available'
      end

      context 'when vulnerable is a group' do
        let(:vulnerable) { group }

        it_behaves_like 'validates filters from vulnerability filterable', :params

        context 'when the group has more vulnerabilities than the max' do
          let(:error_msg) { 'Group has more than 20k vulnerabilities.' }
          let(:max) { group.vulnerabilities.count - 1 }

          before do
            stub_const(
              '::Security::GroupIdentifierSearch::MAX_VULNERABILITY_COUNT_GROUP_SUPPORT',
              max
            )

            allow(::Security::ProjectStatistics).to receive(:sum_vulnerability_count_for_group)
                                                      .with(group).and_return(group.vulnerabilities.count)
          end

          it 'raises an error' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, s_(error_msg)) do
              resolved
            end
            expect(::Security::ProjectStatistics).to have_received(:sum_vulnerability_count_for_group).once
          end

          it_behaves_like 'when elasticsearch is available'
        end

        context 'when the group has fewer vulnerabilities than the max' do
          it 'only returns vulnerabilities with matching identifier_name alone' do
            is_expected.to contain_exactly(vuln_read_with_identifier_name_first.vulnerability)
          end
        end
      end
    end

    describe 'before and after cursors' do
      let(:vulnerable) { group }
      let(:cursor) { Base64.urlsafe_encode64({ severity: 'high' }.to_json) }

      before_all do
        project.vulnerability_reads.update_all(traversal_ids: group.traversal_ids)
      end

      context 'when there is `before` cursor' do
        let(:extra_context) { { current_arguments: { before: cursor } } }

        it { is_expected.to match_array([critical_vulnerability, high_vulnerability]) }
      end

      context 'when there is `after` cursor' do
        let(:extra_context) { { current_arguments: { after: cursor } } }

        it { is_expected.to match_array([low_vulnerability, high_vulnerability]) }
      end

      context 'when the given cursor is not Base64 encoded' do
        let(:extra_context) { { current_arguments: { after: 'cursor' } } }

        it 'does not raise an error' do
          expect { resolved }.not_to raise_error
        end
      end

      context 'when the given cursor does not contain a valid JSON' do
        let(:cursor) { Base64.urlsafe_encode64('{ invalid JSON') }
        let(:extra_context) { { current_arguments: { after: cursor } } }

        it 'does not raise an error' do
          expect { resolved }.not_to raise_error
        end
      end
    end

    it_behaves_like 'validates filters from vulnerability filterable', :params

    describe "association preloading" do
      context "when filtering by postgres" do
        it_behaves_like "a resolver with proper association preloading"
      end

      context "when filtering by elasticsearch", :elastic do
        let(:params) do
          { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] }
        end

        let_it_be(:vuln) do
          create(:vulnerability, :with_findings, project: project)
          .tap { |v| v.vulnerability_read.update!(identifier_names: ['A1:2021-Broken Access Control']) }
        end

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            vuln.vulnerability_read
          )
          ensure_elasticsearch_index!

          allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
        end

        it_behaves_like "a resolver with proper association preloading"
      end
    end

    describe "ElasticSearch pagination", :elastic do
      let_it_be(:vulnerabilities_with_owasp) do
        [
          { severity: :low, cve: 'CVE-2024-1234' },
          { severity: :medium, cve: 'CVE-2024-5678' },
          { severity: :high, cve: 'CVE-2024-9012' },
          { severity: :critical, cve: 'CVE-2024-3456' }
        ].map do |attrs|
          create(:vulnerability, :with_findings, project: project, severity: attrs[:severity])
            .tap { |v| v.vulnerability_read.update!(identifier_names: [attrs[:cve], 'A01:2021-Broken Access Control']) }
        end
      end

      let_it_be(:vulnerability_1) { vulnerabilities_with_owasp[0] }
      let_it_be(:vulnerability_2) { vulnerabilities_with_owasp[1] }
      let_it_be(:vulnerability_3) { vulnerabilities_with_owasp[2] }
      let_it_be(:vulnerability_4) { vulnerabilities_with_owasp[3] }

      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

        Elastic::ProcessBookkeepingService.track!(
          *vulnerabilities_with_owasp.map(&:vulnerability_read)
        )
        ensure_elasticsearch_index!

        allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
      end

      shared_examples 'elasticsearch pagination behavior' do |sort_order = nil|
        it "returns vulnerabilities in #{sort_order || 'default'} order after the cursor" do
          expect(resolved).to be_a(Search::Elastic::Relation)
          expect(resolved.after(severity, reference_vulnerability.id).first(2)).to eq(expected_vulnerabilities)
        end
      end

      context 'when sorting with pagination using after and first' do
        context 'with ascending sort and pagination' do
          let(:params) { { owasp_top_ten_2021: ['A01:2021-Broken Access Control'], sort: :severity_asc } }
          let(:severity) { Enums::Vulnerability::SEVERITY_LEVELS[:low] }
          let(:reference_vulnerability) { vulnerability_1 }
          let(:expected_vulnerabilities) { [vulnerability_2, vulnerability_3] }
          let(:extra_context) { { current_arguments: { first: 2, after: Base64.urlsafe_encode64([severity, reference_vulnerability.id].to_json) } } }

          it_behaves_like 'elasticsearch pagination behavior', 'ascending severity'
        end

        context 'with descending sort and pagination' do
          let(:params) { { owasp_top_ten_2021: ['A01:2021-Broken Access Control'], sort: :severity_desc } }
          let(:severity) { Enums::Vulnerability::SEVERITY_LEVELS[:critical] }
          let(:reference_vulnerability) { vulnerability_4 }
          let(:expected_vulnerabilities) { [vulnerability_3, vulnerability_2] }
          let(:extra_context) { { current_arguments: { first: 2, after: Base64.urlsafe_encode64([severity, reference_vulnerability.id].to_json) } } }

          it_behaves_like 'elasticsearch pagination behavior', 'descending severity'
        end
      end
    end

    describe 'finder selection' do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
      end

      shared_examples 'uses postgres finder' do
        it 'uses VulnerabilityReadsFinder' do
          finder_double = instance_double(::Security::VulnerabilityReadsFinder)
          allow(::Security::VulnerabilityReadsFinder).to receive(:new).and_return(finder_double)
          allow(finder_double).to receive_message_chain(:execute, :as_vulnerabilities).and_return(Vulnerability.none)

          expect(::Search::AdvancedFinders::Security::Vulnerability::SearchFinder).not_to receive(:new)

          resolved
        end
      end

      shared_examples 'uses elasticsearch finder' do
        it 'uses Elasticsearch SearchFinder' do
          finder_double = instance_double(::Search::AdvancedFinders::Security::Vulnerability::SearchFinder)
          allow(::Search::AdvancedFinders::Security::Vulnerability::SearchFinder).to receive(:new).and_return(finder_double)
          allow(finder_double).to receive(:execute).and_return(Vulnerability.none)

          expect(::Security::VulnerabilityReadsFinder).not_to receive(:new)

          resolved
        end
      end

      context 'for Project level' do
        let_it_be(:test_project) { create(:project, namespace: group) }
        let(:vulnerable) { test_project }

        before do
          test_project.add_developer(current_user)
        end

        context 'with no advanced filters' do
          let(:params) { { state: ['detected'] } }

          it_behaves_like 'uses elasticsearch finder'
        end

        context 'with advanced filters' do
          let(:params) { { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] } }

          it_behaves_like 'uses elasticsearch finder'
        end
      end

      context 'for Group level' do
        let(:vulnerable) { group }

        before do
          group.add_developer(current_user)
        end

        context 'with no advanced filters' do
          let(:params) { { state: ['detected'] } }

          it_behaves_like 'uses elasticsearch finder'
        end

        context 'with advanced filters' do
          let(:params) { { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] } }

          it_behaves_like 'uses elasticsearch finder'
        end
      end

      context 'for InstanceSecurityDashboard level' do
        let_it_be(:isd_project) { create(:project, namespace: group) }
        let(:vulnerable) { InstanceSecurityDashboard.new(current_user, project_ids: [isd_project.id]) }

        before do
          allow(current_user).to receive(:can?)
            .with(:read_all_resources).and_return(true)
        end

        context 'with no advanced filters' do
          let(:params) { { state: ['detected'] } }

          it_behaves_like 'uses postgres finder'
        end

        context 'with advanced filters' do
          let(:params) { { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] } }

          it 'raises an error' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, _("Feature is not supported for InstanceSecurityDashboard")) do
              resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user })
            end
          end
        end
      end

      context 'when vuln_finder_always_use_es is disabled' do
        before do
          stub_feature_flags(vuln_finder_always_use_es: false)
        end

        context 'for Project level' do
          let_it_be(:test_project) { create(:project, namespace: group) }
          let(:vulnerable) { test_project }

          before do
            test_project.add_developer(current_user)
          end

          context 'with no advanced filters' do
            let(:params) { { state: ['detected'] } }

            it_behaves_like 'uses postgres finder'
          end

          context 'with advanced filters' do
            let(:params) { { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] } }

            it_behaves_like 'uses elasticsearch finder'
          end
        end

        context 'for Group level' do
          let(:vulnerable) { group }

          before do
            group.add_developer(current_user)
          end

          context 'with no advanced filters' do
            let(:params) { { state: ['detected'] } }

            it_behaves_like 'uses postgres finder'
          end

          context 'with advanced filters' do
            let(:params) { { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] } }

            it_behaves_like 'uses elasticsearch finder'
          end
        end

        context 'for InstanceSecurityDashboard level' do
          let_it_be(:isd_project) { create(:project, namespace: group) }
          let(:vulnerable) { InstanceSecurityDashboard.new(current_user, project_ids: [isd_project.id]) }

          before do
            allow(current_user).to receive(:can?)
              .with(:read_all_resources).and_return(true)
          end

          context 'with no advanced filters' do
            let(:params) { { state: ['detected'] } }

            it_behaves_like 'uses postgres finder'
          end

          context 'with advanced filters' do
            let(:params) { { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] } }

            it 'raises an error' do
              expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, _("Feature is not supported for InstanceSecurityDashboard")) do
                resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user })
              end
            end
          end
        end
      end
    end
  end

  describe 'event tracking' do
    subject(:service_action) { resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: user }) }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:proj) { create(:project, namespace: group) }
    let_it_be(:user) { create(:user, security_dashboard_projects: [proj]) }

    let(:params) { {} }
    let(:category) { described_class.name }

    shared_examples 'tracks events at different levels' do |use_elasticsearch|
      let(:additional_properties) { { label: 'graphql', value: use_elasticsearch ? 1 : 0 } }

      before do
        if use_elasticsearch
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:use_elasticsearch?).and_return(true)
          end
        end
      end

      context 'for Project level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { proj }
          let(:namespace) { group }
          let(:vulnerable) { proj }
        end
      end

      context 'for Group level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { nil }
          let(:namespace) { group }
          let(:vulnerable) { group }
        end
      end

      # Elasticsearch is not supported on InstanceSecurityDashboard.
      unless use_elasticsearch
        context 'for Instance level' do
          it_behaves_like 'internal event tracking' do
            let(:project) { nil }
            let(:namespace) { nil }
            let(:vulnerable) { InstanceSecurityDashboard.new(user, project_ids: [proj.id]) }
          end
        end
      end
    end

    context 'when calling resolver' do
      let(:event) { 'called_vulnerability_api' }

      context 'when using postgres' do
        it_behaves_like 'tracks events at different levels', false
      end

      context 'when using elasticsearch' do
        it_behaves_like 'tracks events at different levels', true
      end
    end

    context 'when filtering by false_positive', :elastic do
      before do
        stub_licensed_features(security_dashboard: true)

        stub_ee_application_setting(
          elasticsearch_search: true,
          elasticsearch_indexing: true
        )

        allow(user)
          .to receive(:can?)
                .with(:access_advanced_vulnerability_management, vulnerable)
                .and_return(true)

        allow(::Search::Elastic::VulnerabilityIndexHelper)
          .to receive(:self_managed_and_first_backfill_completed?)
                .and_return(true)

        set_elasticsearch_migration_to(:add_false_positive_detected_as_fp_to_vulnerability)
      end

      let(:event) { 'filter_ai_fp' }

      shared_examples 'tracks filter_ai_fp event' do |expected_value|
        let(:additional_properties) { { label: 'graphql', value: expected_value } }

        context 'for Project level' do
          it_behaves_like 'internal event tracking' do
            let(:project) { proj }
            let(:namespace) { group }
            let(:vulnerable) { proj }
          end
        end

        context 'for Group level' do
          it_behaves_like 'internal event tracking' do
            let(:project) { nil }
            let(:namespace) { group }
            let(:vulnerable) { group }
          end
        end
      end

      context 'with false_positive: true' do
        let(:params) { { false_positive: true } }

        it_behaves_like 'tracks filter_ai_fp event', 1
      end

      context 'with false_positive: false' do
        let(:params) { { false_positive: false } }

        it_behaves_like 'tracks filter_ai_fp event', 0
      end
    end

    context 'when grouping by owasp_top_10' do
      let(:event) { 'group_by_owasp_top_10_in_vulnerability_report' }
      let(:additional_properties) { { label: 'graphql', value: 1 } }
      let(:params) { { owasp_top_ten: ['A1_2017'] } }
      let(:vulnerable) { proj }

      context 'for Project level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { proj }
          let(:namespace) { group }
          let(:vulnerable) { proj }
        end
      end

      context 'for Group level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { nil }
          let(:namespace) { group }
          let(:vulnerable) { group }
        end
      end

      context 'when owasp_top_10 is not present' do
        let(:params) { {} }

        it 'does not track the event' do
          expect { service_action }.not_to trigger_internal_events('group_by_owasp_top_10_in_vulnerability_report')
        end
      end
    end

    context 'when grouping by owasp_top_10_2021', :elastic do
      before do
        stub_feature_flags(owasp2025_vulnerability_filter: false)

        stub_ee_application_setting(
          elasticsearch_search: true,
          elasticsearch_indexing: true
        )

        allow(user)
          .to receive(:can?)
                .with(:access_advanced_vulnerability_management, vulnerable)
                .and_return(true)

        allow(::Search::Elastic::VulnerabilityIndexHelper)
          .to receive(:self_managed_and_first_backfill_completed?)
                .and_return(true)
      end

      let(:event) { 'group_by_owasp_top_10_2021_in_vulnerability_report' }
      let(:additional_properties) { { label: 'graphql', value: 1 } }
      let(:params) { { owasp_top_ten_2021: ['A01:2021-Broken Access Control'] } }
      let(:vulnerable) { proj }

      context 'for Project level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { proj }
          let(:namespace) { group }
          let(:vulnerable) { proj }
        end
      end

      context 'for Group level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { nil }
          let(:namespace) { group }
          let(:vulnerable) { group }
        end
      end

      context 'when owasp_top_10_2021 is not present' do
        let(:params) { {} }

        it 'does not track the event' do
          expect { service_action }.not_to trigger_internal_events('group_by_owasp_top_10_2021_in_vulnerability_report')
        end
      end
    end

    context 'when grouping by owasp_top_10_2025', :elastic do
      before do
        stub_licensed_features(security_dashboard: true)

        stub_feature_flags(owasp2025_vulnerability_filter: true)

        stub_ee_application_setting(
          elasticsearch_search: true,
          elasticsearch_indexing: true
        )

        allow(user)
          .to receive(:can?)
                .with(:access_advanced_vulnerability_management, vulnerable)
                .and_return(true)

        allow(::Search::Elastic::VulnerabilityIndexHelper)
          .to receive(:self_managed_and_first_backfill_completed?)
                .and_return(true)
      end

      let(:event) { 'group_by_owasp_top_10_2025_in_vulnerability_report' }
      let(:additional_properties) { { label: 'graphql', value: 1 } }
      let(:params) { { owasp_top_ten_2025: ['A01:2025-Broken Access Control'] } }
      let(:vulnerable) { proj }

      context 'for Project level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { proj }
          let(:namespace) { group }
          let(:vulnerable) { proj }
        end
      end

      context 'for Group level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { nil }
          let(:namespace) { group }
          let(:vulnerable) { group }
        end
      end

      context 'when owasp_top_10_2025 is not present' do
        let(:params) { {} }

        it 'does not track the event' do
          expect { service_action }.not_to trigger_internal_events('group_by_owasp_top_10_2025_in_vulnerability_report')
        end
      end
    end

    context 'when filtering by identifier' do
      let(:event) { 'filter_identifier_in_vulnerability_report' }
      let(:vulnerable) { proj }

      context 'for Project level' do
        it_behaves_like 'internal event tracking' do
          let(:additional_properties) { { label: 'graphql', property: 'A1:2017-Injection' } }
          let(:params) { { identifier_name: 'A1:2017-Injection' } }
          let(:project) { proj }
          let(:namespace) { group }
        end
      end

      context 'for Group level' do
        it_behaves_like 'internal event tracking' do
          let(:additional_properties) { { label: 'graphql', property: 'A1:2017-Injection' } }
          let(:params) { { identifier_name: 'A1:2017-Injection' } }
          let(:project) { nil }
          let(:namespace) { group }
          let(:vulnerable) { group }
        end
      end

      context 'with a 2021 identifier' do
        it_behaves_like 'internal event tracking' do
          let(:additional_properties) { { label: 'graphql', property: 'A01:2021-Broken Access Control' } }
          let(:params) { { identifier_name: 'A01:2021-Broken Access Control' } }
          let(:project) { proj }
          let(:namespace) { group }
        end
      end

      context 'with a 2025 identifier' do
        it_behaves_like 'internal event tracking' do
          let(:additional_properties) { { label: 'graphql', property: 'A01:2025-Broken Access Control' } }
          let(:params) { { identifier_name: 'A01:2025-Broken Access Control' } }
          let(:project) { proj }
          let(:namespace) { group }
        end
      end

      context 'when identifier_name is not present' do
        let(:params) { {} }

        it 'does not track the event' do
          expect { service_action }.not_to trigger_internal_events('filter_identifier_in_vulnerability_report')
        end
      end

      context 'when identifier_name is not an OWASP identifier but contains a tracked year' do
        let(:params) { { identifier_name: 'foo:2021' } }

        it 'does not track the event' do
          expect { service_action }.not_to trigger_internal_events('filter_identifier_in_vulnerability_report')
        end
      end

      context 'when identifier_name does not match any OWASP year' do
        let(:params) { { identifier_name: 'CVE-2021-12345' } }

        it 'does not track the event' do
          expect { service_action }.not_to trigger_internal_events('filter_identifier_in_vulnerability_report')
        end
      end
    end
  end
end
