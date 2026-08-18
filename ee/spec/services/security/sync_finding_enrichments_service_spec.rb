# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncFindingEnrichmentsService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let(:execute_service) { execute }

  let_it_be(:cve_identifier_1) do
    create(:vulnerabilities_identifier, project: project, external_type: 'cve', name: 'CVE-2024-1234')
  end

  let_it_be(:cve_identifier_2) do
    create(:vulnerabilities_identifier, project: project, external_type: 'cve', name: 'CVE-2024-5678')
  end

  let_it_be(:cve_identifier_3) do
    create(:vulnerabilities_identifier, project: project, external_type: 'cve', name: 'CVE-2024-8910')
  end

  let_it_be(:cve_identifier_4) do
    create(:vulnerabilities_identifier, project: project, external_type: 'cve', name: 'CVE-2024-9999')
  end

  let_it_be(:non_cve_identifier) do
    create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-79')
  end

  let_it_be(:finding_with_single_cve) do
    create(:vulnerabilities_finding, project: project).tap do |f|
      create(:vulnerabilities_finding_identifier, finding: f, identifier: cve_identifier_1)
      create(:vulnerability, project: project, vulnerability_finding: f)
    end
  end

  let_it_be(:finding_with_multiple_cves) do
    create(:vulnerabilities_finding, project: project).tap do |f|
      create(:vulnerabilities_finding_identifier, finding: f, identifier: cve_identifier_2)
      create(:vulnerabilities_finding_identifier, finding: f, identifier: cve_identifier_3)
      create(:vulnerability, project: project, vulnerability_finding: f)
    end
  end

  let_it_be(:finding_without_cve) do
    create(:vulnerabilities_finding, project: project).tap do |f|
      create(:vulnerabilities_finding_identifier, finding: f, identifier: non_cve_identifier)
      create(:vulnerability, project: project, vulnerability_finding: f)
    end
  end

  let_it_be(:finding_with_unenriched_cve) do
    create(:vulnerabilities_finding, project: project).tap do |f|
      create(:vulnerabilities_finding_identifier, finding: f, identifier: cve_identifier_4)
      create(:vulnerability, project: project, vulnerability_finding: f)
    end
  end

  let(:create_security_finding_for_cve_identifier_1) do
    create(:security_finding, uuid: finding_with_single_cve.uuid, scan: create(:security_scan, project: project))
  end

  subject(:execute) { described_class.new(project).execute }

  describe '#execute' do
    it_behaves_like 'a service that syncs finding enrichments'

    context 'when enrichment records already exist (idempotency)' do
      it 'is safe to run multiple times' do
        service = described_class.new(project)
        service.execute
        expect { service.execute }.not_to change { Security::FindingEnrichment.count }
      end
    end

    it 'sets vulnerability_id on enrichment records' do
      execute

      enrichment = Security::FindingEnrichment.find_by(finding_uuid: finding_with_single_cve.uuid)
      expect(enrichment.vulnerability_id).to eq(finding_with_single_cve.vulnerability_id)
    end

    context 'when the project has no findings with CVE identifiers' do
      let_it_be(:empty_project) { create(:project) }

      it 'does not create any enrichment records' do
        expect { described_class.new(empty_project).execute }
          .not_to change { Security::FindingEnrichment.count }
      end
    end

    context 'when batching' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'processes all findings across multiple batches' do
        expect { execute }.to change { Security::FindingEnrichment.count }.by(4)
      end

      it 'calls upsert_all once per batch' do
        expect(Security::FindingEnrichment).to receive(:upsert_all).twice.and_call_original

        execute
      end
    end

    context 'when a vulnerability is not on the default branch' do
      let_it_be(:off_branch_cve_identifier) do
        create(:vulnerabilities_identifier, project: project, external_type: 'cve', name: 'CVE-2024-0001')
      end

      let_it_be(:off_branch_finding) do
        create(:vulnerabilities_finding, project: project).tap do |f|
          create(:vulnerabilities_finding_identifier, finding: f, identifier: off_branch_cve_identifier)
          create(:vulnerability, project: project, findings: [f], present_on_default_branch: false)
        end
      end

      it 'does not create enrichment records for findings not on the default branch' do
        execute

        expect(Security::FindingEnrichment.where(finding_uuid: off_branch_finding.uuid)).to be_empty
      end
    end

    context 'when findings belong to a different project' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_cve_identifier) do
        create(:vulnerabilities_identifier, project: other_project, external_type: 'cve', name: 'CVE-2024-1237')
      end

      let_it_be(:other_finding) do
        create(:vulnerabilities_finding, project: other_project).tap do |f|
          create(:vulnerabilities_finding_identifier, finding: f, identifier: other_cve_identifier)
          create(:vulnerability, project: other_project, findings: [f])
        end
      end

      it 'only creates enrichment records for the given project' do
        execute

        other_enrichments = Security::FindingEnrichment.where(project: other_project)
        expect(other_enrichments).to be_empty
      end
    end
  end
end
