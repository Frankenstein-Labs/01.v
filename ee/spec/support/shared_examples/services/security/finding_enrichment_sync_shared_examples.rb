# frozen_string_literal: true

RSpec.shared_examples 'a service that syncs finding enrichments' do
  let_it_be(:cve_enrichment_1, freeze: false) do
    create(:pm_cve_enrichment, cve: cve_identifier_1.name, epss_score: 0.5)
  end

  let_it_be(:cve_enrichment_2) { create(:pm_cve_enrichment, cve: cve_identifier_2.name, is_known_exploit: false) }
  let_it_be(:cve_enrichment_3) { create(:pm_cve_enrichment, cve: cve_identifier_3.name, epss_score: 0.9) }

  it 'creates finding enrichment records for findings with CVE identifiers' do
    expect { execute_service }.to change { Security::FindingEnrichment.count }.by(4)

    expect(Security::FindingEnrichment.where(project: project).pluck(:cve))
      .to match_array([cve_identifier_1.name, cve_identifier_2.name, cve_identifier_3.name, cve_identifier_4.name])
  end

  it 'associates the correct enrichment data' do
    execute_service

    enrichment = Security::FindingEnrichment.find_by(finding_uuid: finding_with_single_cve.uuid,
      cve: cve_identifier_1.name)
    expect(enrichment).to have_attributes(
      cve: cve_identifier_1.name,
      cve_enrichment_id: cve_enrichment_1.id,
      epss_score: cve_enrichment_1.epss_score,
      is_known_exploit: cve_enrichment_1.is_known_exploit
    )
  end

  it 'creates multiple enrichment records for findings with multiple CVE identifiers' do
    execute_service

    expect(Security::FindingEnrichment.where(finding_uuid: finding_with_multiple_cves.uuid)).to contain_exactly(
      have_attributes(cve: cve_identifier_2.name, cve_enrichment_id: cve_enrichment_2.id),
      have_attributes(cve: cve_identifier_3.name, cve_enrichment_id: cve_enrichment_3.id)
    )
  end

  it 'does not create enrichment records for findings without CVE identifiers' do
    execute_service

    expect(Security::FindingEnrichment.where(finding_uuid: finding_without_cve.uuid)).to be_empty
  end

  it 'sets the correct project_id on all enrichment records' do
    execute_service

    expect(Security::FindingEnrichment.where(project: project).pluck(:project_id)).to all(eq(project.id))
  end

  context 'when no PackageMetadata::CveEnrichment exists for the CVE' do
    it 'creates a finding enrichment record with nil cve_enrichment_id' do
      execute_service

      enrichment = Security::FindingEnrichment.find_by(finding_uuid: finding_with_unenriched_cve.uuid,
        cve: cve_identifier_4.name)
      expect(enrichment).to have_attributes(
        cve: cve_identifier_4.name,
        cve_enrichment_id: nil,
        epss_score: nil,
        is_known_exploit: nil
      )
    end
  end

  context 'when enrichment records already exist' do
    before do
      create_security_finding_for_cve_identifier_1
      Security::FindingEnrichment.create!(
        project: project,
        finding_uuid: finding_with_single_cve.uuid,
        cve_enrichment: cve_enrichment_1,
        cve: cve_identifier_1.name,
        epss_score: cve_enrichment_1.epss_score,
        is_known_exploit: cve_enrichment_1.is_known_exploit
      )
    end

    it 'does not create duplicate enrichment records' do
      expect { execute_service }.to change { Security::FindingEnrichment.count }.by(3)

      expect(Security::FindingEnrichment.where(project: project).pluck(:cve))
        .to match_array([cve_identifier_1.name, cve_identifier_2.name, cve_identifier_3.name, cve_identifier_4.name])
    end

    it 'updates cve_enrichment_id, epss_score, is_known_exploit and updated_at on conflict' do
      new_epss_score = 0.8
      new_is_known_exploit = true
      cve_enrichment_1.update!(epss_score: new_epss_score, is_known_exploit: new_is_known_exploit)

      enrichment = Security::FindingEnrichment.find_by!(
        project: project,
        finding_uuid: finding_with_single_cve.uuid,
        cve: cve_identifier_1.name
      )

      travel_to(1.hour.from_now) do
        execute_service

        expect(enrichment.reload).to have_attributes(
          cve_enrichment_id: cve_enrichment_1.id,
          epss_score: new_epss_score,
          is_known_exploit: new_is_known_exploit,
          updated_at: eq(Time.current)
        )
      end
    end

    it 'preserves existing vulnerability_id on conflict' do
      existing_vulnerability = create(:vulnerability, project: project)
      enrichment = Security::FindingEnrichment.find_by!(
        project: project,
        finding_uuid: finding_with_single_cve.uuid,
        cve: cve_identifier_1.name
      )
      enrichment.update!(vulnerability_id: existing_vulnerability.id)

      execute_service

      expect(enrichment.reload.vulnerability_id).to eq(existing_vulnerability.id)
    end
  end

  context 'when upsert raises an error' do
    before do
      allow(Security::FindingEnrichment).to receive(:upsert_all).and_raise(StandardError.new('DB error'))
    end

    it 'does not raise' do
      expect { execute_service }.not_to raise_error
    end

    it 'tracks the exception' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        an_instance_of(StandardError),
        hash_including(project_id: project.id)
      )

      execute_service
    end
  end
end
