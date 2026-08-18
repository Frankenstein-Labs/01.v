# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::ArchivedRecordBuilderService, feature_category: :vulnerability_management do
  describe '.execute' do
    let(:mock_archive) { instance_double(Vulnerabilities::Archive) }
    let(:mock_vulnerability) { instance_double(Vulnerability) }
    let(:mock_service_object) { instance_spy(described_class) }

    subject(:build_archived_record) { described_class.execute(mock_archive, mock_vulnerability) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates an object and delegates the call to it' do
      build_archived_record

      expect(described_class).to have_received(:new).with(mock_archive, mock_vulnerability)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute', :freeze_time do
    let_it_be(:user) { create(:user, username: 'john.doe') }
    let_it_be(:project) { create(:project) }
    let_it_be(:archive) { create(:vulnerability_archive, project: project) }
    let_it_be(:finding, freeze: false) { create(:vulnerabilities_finding, description: 'Test Description') }
    let_it_be_with_refind(:vulnerability) do
      create(:vulnerability,
        :dismissed,
        dismissed_by: user,
        confirmed_at: Time.zone.now,
        confirmed_by: user,
        resolved_at: Time.zone.now,
        resolved_by: user,
        project: project,
        findings: [finding],
        title: 'Test Title')
    end

    let(:service_object) { described_class.new(archive, vulnerability) }

    subject(:build_archived_record) { service_object.execute }

    before do
      allow(vulnerability).to receive_messages(notes_summary: 'Test notes summary', full_path: 'Test full path')

      finding.identifiers = [
        build(:vulnerabilities_identifier,
          project: project,
          external_type: 'CVE',
          external_id: 'CVE-2018-1234',
          name: 'CVE-2018-1234'),
        build(:vulnerabilities_identifier,
          project: project,
          external_type: 'CWE',
          external_id: 'CWE-123',
          name: 'CWE-123'),
        build(:vulnerabilities_identifier,
          project: project,
          external_type: 'OWASP',
          external_id: 'A01:2021',
          name: 'OWASP-A01:2021')
      ]
    end

    it 'builds a new instance of `Vulnerabilities::ArchivedRecord` with correct attributes' do
      vulnerability.vulnerability_read.dismissal_reason = :false_positive

      expect(build_archived_record).to have_attributes(
        archive: archive,
        date: archive.date,
        project: project,
        vulnerability_identifier: vulnerability.id,
        data: {
          report_type: 'sast',
          scanner: 'Find Security Bugs',
          state: 'dismissed',
          severity: 'high',
          title: 'Test Title',
          description: 'Test Description',
          cve_value: 'CVE-2018-1234',
          cwe_value: 'CWE-123',
          other_identifiers: ['OWASP-A01:2021'],
          dismissed_at: vulnerability.dismissed_at.to_s,
          dismissed_by: 'john.doe',
          created_at: vulnerability.created_at.to_s,
          location: {
            class: 'com.gitlab.security_products.tests.App',
            end_line: 29,
            file: 'maven/src/main/java/com/gitlab/security_products/tests/App.java',
            method: 'insecureCypher',
            start_line: 29
          },
          resolved_on_default_branch: false,
          notes_summary: 'Test notes summary',
          full_path: 'Test full path',
          cvss: [
            {
              vector: 'CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:L/I:L/A:N',
              vendor: 'GitLab'
            }
          ],
          dismissal_reason: 'false_positive'
        }.deep_stringify_keys,
        created_at: Time.zone.now,
        updated_at: Time.zone.now
      )
    end

    context 'when the vulnerability is confirmed' do
      before do
        vulnerability.update!(state: :confirmed)
      end

      it 'sets the confirmed at and confirmed by information' do
        expect(build_archived_record[:data]).to match(hash_including(
          'confirmed_at' => vulnerability.confirmed_at.to_s,
          'confirmed_by' => 'john.doe'
        ))
      end
    end

    context 'when the vulnerability is resolved' do
      before do
        vulnerability.update!(state: :resolved)
      end

      it 'sets the resolved at and resolved by information' do
        expect(build_archived_record[:data]).to match(hash_including(
          'resolved_at' => vulnerability.resolved_at.to_s,
          'resolved_by' => 'john.doe'
        ))
      end
    end

    context 'when the vulnerability has related issues' do
      let!(:related_issue_link) { create(:vulnerabilities_issue_link, :related, vulnerability: vulnerability) }
      let!(:created_issue_link) { create(:vulnerabilities_issue_link, :created, vulnerability: vulnerability) }

      it 'sets the `related_issues` information' do
        expect(build_archived_record[:data]).to match(hash_including(
          'related_issues' => match_array([
            {
              'type' => 'related',
              'id' => related_issue_link.issue_id
            },
            {
              'type' => 'created',
              'id' => created_issue_link.issue_id
            }
          ])
        ))
      end
    end

    context 'when the vulnerability has related MRs' do
      let!(:merge_request_link_1) { create(:vulnerabilities_merge_request_link, vulnerability: vulnerability) }
      let!(:merge_request_link_2) { create(:vulnerabilities_merge_request_link, vulnerability: vulnerability) }

      it 'sets the `related_mrs` information' do
        expect(build_archived_record[:data]).to match(hash_including(
          'related_mrs' => match_array([
            merge_request_link_1.merge_request_id, merge_request_link_2.merge_request_id
          ])
        ))
      end
    end

    context 'when the vulnerabilites does not have a related read record' do
      before do
        vulnerability.vulnerability_read.delete

        vulnerability.reload
      end

      it 'builds a new instance of `Vulnerabilities::ArchivedRecord` without a failure' do
        expect(build_archived_record).to have_attributes(
          archive: archive,
          date: archive.date,
          project: project,
          vulnerability_identifier: vulnerability.id,
          data: {
            report_type: 'sast',
            scanner: 'Find Security Bugs',
            state: 'dismissed',
            severity: 'high',
            title: 'Test Title',
            description: 'Test Description',
            cve_value: 'CVE-2018-1234',
            cwe_value: 'CWE-123',
            other_identifiers: ['OWASP-A01:2021'],
            dismissed_at: vulnerability.dismissed_at.to_s,
            dismissed_by: 'john.doe',
            created_at: vulnerability.created_at.to_s,
            location: {
              class: 'com.gitlab.security_products.tests.App',
              end_line: 29,
              file: 'maven/src/main/java/com/gitlab/security_products/tests/App.java',
              method: 'insecureCypher',
              start_line: 29
            },
            resolved_on_default_branch: false,
            notes_summary: 'Test notes summary',
            full_path: 'Test full path',
            cvss: [
              {
                vector: 'CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:L/I:L/A:N',
                vendor: 'GitLab'
              }
            ],
            dismissal_reason: nil
          }.deep_stringify_keys,
          created_at: Time.zone.now,
          updated_at: Time.zone.now
        )
      end
    end

    context 'when the vulnerability has no findings' do
      let_it_be_with_refind(:vulnerability) do
        create(:vulnerability,
          :dismissed,
          dismissed_by: user,
          confirmed_at: Time.zone.now,
          confirmed_by: user,
          resolved_at: Time.zone.now,
          resolved_by: user,
          project: project,
          title: 'Test Title')
      end

      it 'builds a new instance of `Vulnerabilities::ArchivedRecord` with correct attributes' do
        expect(build_archived_record).to have_attributes(
          archive: archive,
          date: archive.date,
          project: project,
          vulnerability_identifier: vulnerability.id,
          data: {
            report_type: 'sast',
            scanner: '',
            state: 'dismissed',
            severity: 'high',
            title: 'Test Title',
            description: '',
            cve_value: nil,
            cwe_value: nil,
            other_identifiers: [],
            dismissed_at: vulnerability.dismissed_at.to_s,
            dismissed_by: 'john.doe',
            created_at: vulnerability.created_at.to_s,
            location: nil,
            resolved_on_default_branch: false,
            notes_summary: 'Test notes summary',
            full_path: 'Test full path',
            cvss: [
              {
                vector: 'CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:L/I:L/A:N',
                vendor: 'GitLab'
              }
            ],
            dismissal_reason: nil
          }.deep_stringify_keys,
          created_at: Time.zone.now,
          updated_at: Time.zone.now
        )
      end
    end
  end
end
