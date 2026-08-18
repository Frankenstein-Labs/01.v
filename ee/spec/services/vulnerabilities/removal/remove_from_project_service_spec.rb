# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Removal::RemoveFromProjectService, :elastic, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:security_statistics) { project.security_statistics }
    let_it_be(:vulnerabilities) do
      create_list(
        :vulnerability,
        2,
        :with_finding,
        :with_state_transition,
        :with_notes,
        :with_issue_links,
        :with_user_mention,
        project: project)
    end

    let_it_be(:resolved_vulnerability) do
      create(:vulnerability,
        :with_finding,
        project: project,
        resolved_on_default_branch: true)
    end

    let_it_be(:finding) { vulnerabilities.first.vulnerability_finding }

    let(:params) { {} }
    let(:service_object) { described_class.new(project, params) }

    subject(:remove_vulnerabilities) { service_object.execute }

    before_all do
      project.project_setting.update!(has_vulnerabilities: true)
    end

    describe 'batching' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)

        allow(Vulnerability).to receive(:feature_flagged_transaction_for).and_call_original
      end

      it 'deletes records in batches' do
        remove_vulnerabilities

        expect(Vulnerability).to have_received(:feature_flagged_transaction_for).exactly(3).times
      end
    end

    describe 'deleting the records', :aggregate_failures do
      before do
        allow(Vulnerabilities::Statistics::AdjustmentWorker).to receive(:perform_async)
      end

      before_all do
        merge_request = create(:merge_request, source_project: project)

        create(:vulnerability_feedback, project: project)
        create(:vulnerability_statistic, project: project)
        create(:vulnerability_historical_statistic, project: project)

        create(:vulnerabilities_external_issue_link, vulnerability: vulnerabilities.first)
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerabilities.first, merge_request: merge_request)
        create(:vulnerability_severity_override, vulnerability: vulnerabilities.first)

        create(:finding_link, finding: finding)
        create(:vulnerabilities_flag, finding: finding)
        create(:vulnerabilties_finding_evidence, finding: finding)
        create(:vulnerabilities_finding_signature, finding: finding)
        create(:vulnerabilities_finding_identifier, finding: finding)
        create(:vulnerabilities_remediation, project: project, findings: [finding])

        create(:vulnerability, project: project, present_on_default_branch: false)
        resolved_vulnerability.vulnerability_finding.identifiers << finding.identifiers.first

        other_project = create(:project)
        create(:vulnerability, :with_finding, project: other_project)
      end

      it 'removes all the records from the database' do
        expect { remove_vulnerabilities }.to change { Vulnerability.count }.by(-4)
                                         .and change { Vulnerabilities::Read.count }.by(-3)
                                         .and change { Vulnerabilities::Flag.count }.by(-1)
                                         .and change { VulnerabilityUserMention.count }.by(-2)
                                         .and change { Vulnerabilities::Finding.count }.by(-4)
                                         .and change { Vulnerabilities::Feedback.count }.by(-1)
                                         .and change { Vulnerabilities::IssueLink.count }.by(-4)
                                         .and change { Vulnerabilities::FindingLink.count }.by(-1)
                                         .and change { Vulnerabilities::SeverityOverride.count }.by(-1)
                                         .and change { Vulnerabilities::StateTransition.count }.by(-2)
                                         .and change { Vulnerabilities::MergeRequestLink.count }.by(-1)
                                         .and change { Vulnerabilities::FindingSignature.count }.by(-1)
                                         .and change { Vulnerabilities::FindingIdentifier.count }.by(-2)
                                         .and change { Vulnerabilities::Finding::Evidence.count }.by(-1)
                                         .and change { Vulnerabilities::ExternalIssueLink.count }.by(-1)
                                         .and change { Vulnerabilities::FindingRemediation.count }.by(-1)
                                         .and change { Vulnerabilities::HistoricalStatistic.count }.by(-1)
                                         .and change { security_statistics.reload.vulnerability_count }.by(-3)
                                         .and change {
                                                project.project_setting.reload.has_vulnerabilities
                                              }.from(true).to(false)

        expect(Vulnerabilities::Statistics::AdjustmentWorker).to have_received(:perform_async).with([project.id])
      end

      context 'when the `resolved_on_default_branch` argument presents' do
        context 'when the cleanup is only for the vulnerabilities resolved on default branch' do
          let(:params) { { resolved_on_default_branch: true } }

          it 'removes only the vulnerabilities resolved on default branch' do
            expect { remove_vulnerabilities }.to change { Vulnerability.count }.by(-1)
                                             .and change { Vulnerabilities::Read.count }.by(-1)
                                             .and change { Vulnerabilities::Finding.count }.by(-1)
                                             .and change { Vulnerabilities::FindingIdentifier.count }.by(-1)
                                             .and change { security_statistics.reload.vulnerability_count }.by(-1)
                                             .and not_change { Vulnerabilities::Flag.count }
                                             .and not_change { VulnerabilityUserMention.count }
                                             .and not_change { Vulnerabilities::Feedback.count }
                                             .and not_change { Vulnerabilities::IssueLink.count }
                                             .and not_change { Vulnerabilities::Identifier.count }
                                             .and not_change { Vulnerabilities::FindingLink.count }
                                             .and not_change { Vulnerabilities::Remediation.count }
                                             .and not_change { Vulnerabilities::SeverityOverride.count }
                                             .and not_change { Vulnerabilities::StateTransition.count }
                                             .and not_change { Vulnerabilities::MergeRequestLink.count }
                                             .and not_change { Vulnerabilities::FindingSignature.count }
                                             .and not_change { Vulnerabilities::Finding::Evidence.count }
                                             .and not_change { Vulnerabilities::ExternalIssueLink.count }
                                             .and not_change { Vulnerabilities::FindingRemediation.count }
                                             .and not_change { Vulnerabilities::HistoricalStatistic.count }
                                             .and not_change { project.project_setting.reload.has_vulnerabilities }

            expect(Vulnerabilities::Statistics::AdjustmentWorker).to have_received(:perform_async).with([project.id])
          end
        end

        context 'when the cleanup is only for the vulnerabilities still detected' do
          let(:params) { { resolved_on_default_branch: false } }

          it 'removes only the still detected vulnerabilities' do
            expect { remove_vulnerabilities }.to change { Vulnerability.count }.by(-2)
                                             .and change { Vulnerabilities::Read.count }.by(-2)
                                             .and change { Vulnerabilities::Flag.count }.by(-1)
                                             .and change { VulnerabilityUserMention.count }.by(-2)
                                             .and change { Vulnerabilities::Finding.count }.by(-2)
                                             .and change { Vulnerabilities::IssueLink.count }.by(-4)
                                             .and change { Vulnerabilities::FindingLink.count }.by(-1)
                                             .and change { Vulnerabilities::SeverityOverride.count }.by(-1)
                                             .and change { Vulnerabilities::StateTransition.count }.by(-2)
                                             .and change { Vulnerabilities::MergeRequestLink.count }.by(-1)
                                             .and change { Vulnerabilities::FindingSignature.count }.by(-1)
                                             .and change { Vulnerabilities::FindingIdentifier.count }.by(-1)
                                             .and change { Vulnerabilities::Finding::Evidence.count }.by(-1)
                                             .and change { Vulnerabilities::ExternalIssueLink.count }.by(-1)
                                             .and change { Vulnerabilities::FindingRemediation.count }.by(-1)
                                             .and change { security_statistics.reload.vulnerability_count }.by(-2)
                                             .and not_change { Vulnerabilities::Feedback.count }
                                             .and not_change { Vulnerabilities::Identifier.count }
                                             .and not_change { Vulnerabilities::HistoricalStatistic.count }

            expect(Vulnerabilities::Statistics::AdjustmentWorker).to have_received(:perform_async).with([project.id])
          end
        end
      end
    end

    it_behaves_like 'sync vulnerabilities changes to ES' do
      let!(:expected_vulnerabilities) do
        Vulnerabilities::Read.by_vulnerabilities(vulnerabilities + [resolved_vulnerability])
          .flat_map(&:elastic_reference)
      end

      subject do
        remove_vulnerabilities
      end
    end

    describe 'N+1 queries for ES reference building' do
      include_context 'with ES stubs'

      it 'avoids N+1 DB queries' do
        test_project = create(:project, namespace: create(:group, :nested))
        create(:vulnerability, :with_finding, project: test_project)

        control = ActiveRecord::QueryRecorder.new do
          batch = Vulnerability.with_project(test_project)
          described_class::BatchRemoval.new(test_project, batch, update_counts: false)
            .send(:build_es_references)
        end

        create_list(:vulnerability, 2, :with_finding, project: test_project)

        expect do
          batch = Vulnerability.with_project(test_project)
          described_class::BatchRemoval.new(test_project, batch, update_counts: false)
            .send(:build_es_references)
        end.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency
      end
    end

    context 'when ES migrations have not completed' do
      before do
        set_elasticsearch_migration_to :create_vulnerability_reads_index, including: false
      end

      it_behaves_like 'sync vulnerabilities changes to ES' do
        let(:expected_vulnerabilities) do
          (vulnerabilities + [resolved_vulnerability]).flat_map(&:elastic_reference)
        end

        subject do
          remove_vulnerabilities
        end
      end
    end
  end
end
