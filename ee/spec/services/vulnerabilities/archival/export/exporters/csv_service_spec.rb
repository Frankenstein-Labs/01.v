# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::Export::Exporters::CsvService, feature_category: :vulnerability_management do
  describe '#generate' do
    let_it_be(:archived_record) do
      create(:vulnerability_archived_record, :dismissed, :with_issues, :with_merge_requests)
    end

    let(:export_csv_service) { described_class.new([archived_record]) }

    context 'when block is not given' do
      it 'renders csv to string' do
        expect(export_csv_service.generate).to be_a(String)
      end
    end

    context 'when block is given' do
      it 'returns handle to Tempfile' do
        expect(export_csv_service.generate { |file| file }).to be_a(Tempfile)
      end
    end

    describe 'CSV content' do
      let(:csv) { CSV.parse(export_csv_service.generate, headers: true) }

      describe 'headers' do
        let(:expected_headers) do
          ['Tool', 'Scanner Name', 'Status', 'Vulnerability', 'Details', 'Severity', 'CVE', 'CWE', 'Other Identifiers',
            'Dismissed At', 'Dismissed By', 'Confirmed At', 'Confirmed By', 'Resolved At', 'Resolved By', 'Detected At',
            'Location', 'Issues', 'Merge Requests', 'Activity', 'Comments', 'Full Path', 'CVSS Vectors',
            'Dismissal Reason', 'Vulnerability ID']
        end

        it 'contains the expected headers' do
          expect(csv.headers).to eq(expected_headers)
        end
      end

      describe 'rows' do
        it 'serializes correct number of rows' do
          expect(csv.length).to be(1)
        end

        it 'serializes the correct content' do
          location = {
            'class' => 'com.gitlab.security_products.tests.App',
            'end_line' => 29,
            'file' => 'maven/src/main/java/com/gitlab/security_products/tests/App.java',
            'method' => 'insecureCypher',
            'start_line' => 29
          }
          issues = [{ 'type' => 'created', 'id' => 1 }]

          expect(csv[0].to_h).to match(
            {
              'Tool' => 'sast',
              'Scanner Name' => 'Find Security Bugs',
              'Status' => 'dismissed',
              'Vulnerability' => 'Test Title',
              'Details' => 'Test Description',
              'Severity' => 'high',
              'CVE' => 'CVE-2018-1234',
              'CWE' => 'CWE-123',
              'Other Identifiers' => 'OWASP-A01:2021',
              'Dismissed At' => '2025-01-30 19:02:08 UTC',
              'Dismissed By' => 'user',
              'Confirmed At' => nil,
              'Confirmed By' => nil,
              'Resolved At' => nil,
              'Resolved By' => nil,
              'Detected At' => '2025-01-29 19:02:08 UTC',
              'Location' => location.to_s,
              'Issues' => issues.to_s,
              'Merge Requests' => '[1, 2]',
              'Activity' => 'false',
              'Comments' => 'Test notes summary',
              'Full Path' => 'Test full path',
              'CVSS Vectors' => 'GitLab=CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:L/I:L/A:N',
              'Dismissal Reason' => 'False positive',
              'Vulnerability ID' => archived_record.vulnerability_identifier.to_s
            }
          )
        end
      end
    end
  end
end
