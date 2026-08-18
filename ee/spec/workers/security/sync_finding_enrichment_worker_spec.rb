# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncFindingEnrichmentWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let(:worker) { described_class.new }

  describe '#perform' do
    subject(:perform) { worker.perform }

    shared_examples_for 'returns early without loading cve enrichments' do
      it 'returns early without loading cve enrichments' do
        expect(PackageMetadata::CveEnrichment).not_to receive(:updated_after)

        perform
      end
    end

    context 'when security_orchestration_policies feature is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it_behaves_like 'returns early without loading cve enrichments'
    end

    context 'when security_orchestration_policies feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when in development environment without PM_SYNC_IN_DEV' do
        before do
          allow(Rails.env).to receive(:development?).and_return(true)
          allow(ENV).to receive(:fetch).with('PM_SYNC_IN_DEV', 'false').and_return('false')
        end

        it_behaves_like 'returns early without loading cve enrichments'
      end

      context 'when there are no recently updated CVE enrichments' do
        before do
          cve_enrichment = create(:pm_cve_enrichment, updated_at: 1.hour.ago)
          finding = create(:security_finding, project_id: project.id)
          create(:security_finding_enrichment,
            project: project,
            finding_uuid: finding.uuid,
            cve_enrichment: cve_enrichment)
        end

        it 'does not issue any UPDATE on security_finding_enrichments' do
          expect(SecApplicationRecord.connection).not_to receive(:exec_query)

          perform
        end
      end

      context 'when there are recently updated CVE enrichments' do
        let_it_be(:cve_enrichment) do
          create(:pm_cve_enrichment, epss_score: 0.5, is_known_exploit: true, updated_at: 50.minutes.ago)
        end

        let_it_be(:other_cve_enrichment) do
          create(:pm_cve_enrichment, epss_score: 0.9, is_known_exploit: false, updated_at: 30.minutes.ago)
        end

        let_it_be(:finding) { create(:security_finding, project_id: project.id) }
        let_it_be(:finding_with_enrichment) do
          create(:security_finding_enrichment,
            project: project,
            finding_uuid: finding.uuid,
            cve_enrichment: cve_enrichment,
            epss_score: nil,
            is_known_exploit: false
          )
        end

        let_it_be(:another_finding_enrichment) do
          create(:security_finding_enrichment,
            project: project,
            finding_uuid: finding.uuid,
            cve_enrichment: other_cve_enrichment,
            epss_score: 0.8,
            is_known_exploit: false
          )
        end

        shared_examples_for 'bulk updates finding enrichments' do
          it 'issues a bulk UPDATE on security_finding_enrichments' do
            expect(SecApplicationRecord.connection).to receive(:exec_query).and_call_original

            perform

            expect(finding_with_enrichment.reload.epss_score).to eq(cve_enrichment.epss_score)
            expect(finding_with_enrichment.reload.is_known_exploit).to eq(cve_enrichment.is_known_exploit)
            expect(another_finding_enrichment.reload.epss_score).to eq(other_cve_enrichment.epss_score)
            expect(another_finding_enrichment.reload.is_known_exploit).to eq(other_cve_enrichment.is_known_exploit)
          end
        end

        shared_examples_for 'it does not update merge request approvals' do
          it 'does not enqueue SyncMergeRequestsWorker' do
            expect(Security::SyncMergeRequestsWorker).not_to receive(:perform_async)

            perform
          end
        end

        shared_examples_for 'it updates merge request approvals' do
          it 'enqueues SyncMergeRequestsWorker with the correct arguments' do
            expect(Security::SyncMergeRequestsWorker).to receive(:perform_async).with(project.id, policy.id)

            perform
          end
        end

        context 'when there are no policies with enrichment filters' do
          it_behaves_like 'bulk updates finding enrichments'
          it_behaves_like 'it does not update merge request approvals'
        end

        context 'when there are policies with enrichment filters' do
          let_it_be(:policy) { create(:security_policy, :approval_policy, enabled: true, linked_projects: [project]) }
          let_it_be(:approval_policy_rule) do
            create(:approval_policy_rule, :scan_finding_with_enrichment_filters, security_policy: policy)
          end

          it_behaves_like 'bulk updates finding enrichments'
          it_behaves_like 'it updates merge request approvals'

          context 'when the policy is disabled' do
            before do
              Security::Policy.update_all(enabled: false)
            end

            it_behaves_like 'bulk updates finding enrichments'
            it_behaves_like 'it does not update merge request approvals'
          end

          context 'when the bulk UPDATE affects no rows' do
            before do
              allow(SecApplicationRecord.connection).to receive(:exec_query)
                .and_return(ActiveRecord::Result.new(['project_id'], []))
            end

            it_behaves_like 'it does not update merge request approvals'
          end

          context 'when project has multiple policies with enrichment filters' do
            let_it_be(:other_policy) do
              create(:security_policy, :approval_policy, enabled: true, linked_projects: [project])
            end

            let_it_be(:other_approval_policy_rule) do
              create(:approval_policy_rule, :scan_finding_with_enrichment_filters, security_policy: other_policy)
            end

            it_behaves_like 'bulk updates finding enrichments'

            it 'updates MR Approvals for all policies' do
              [policy, other_policy].each do |security_policy|
                expect(Security::SyncMergeRequestsWorker).to receive(:perform_async).with(project.id,
                  security_policy.id)
              end

              perform
            end
          end
        end
      end
    end
  end
end
