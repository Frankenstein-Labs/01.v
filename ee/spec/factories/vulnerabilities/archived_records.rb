# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_archived_record, class: 'Vulnerabilities::ArchivedRecord' do
    project
    archive factory: :vulnerability_archive
    sequence(:vulnerability_identifier)
    data do
      {
        report_type: 'sast',
        scanner: 'Find Security Bugs',
        state: 'dismissed',
        severity: 'high',
        title: 'Test Title',
        description: 'Test Description',
        cve_value: 'CVE-2018-1234',
        cwe_value: 'CWE-123',
        other_identifiers: ['OWASP-A01:2021'],
        created_at: '2025-01-29 19:02:08 UTC',
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
      }.deep_stringify_keys
    end

    trait :dismissed do
      after(:build) do |archived_record|
        archived_record.data[:dismissed_at] = '2025-01-30 19:02:08 UTC'
        archived_record.data[:dismissed_by] = 'user'
      end
    end

    trait :with_issues do
      after(:build) do |archived_record|
        archived_record.data[:related_issues] = [
          {
            type: 'created',
            id: 1
          }
        ]
      end
    end

    trait :with_merge_requests do
      after(:build) do |archived_record|
        archived_record.data[:related_mrs] = [1, 2]
      end
    end

    trait :with_unicode_null_character do
      data do
        {
          report_type: 'sast',
          scanner: 'Find Security Bugs',
          state: 'dismissed',
          severity: 'high',
          title: 'Test Title',
          description: "Test Description\u0000",
          cve_value: 'CVE-2018-1234',
          cwe_value: 'CWE-123',
          other_identifiers: ['OWASP-A01:2021'],
          created_at: '2025-01-29 19:02:08 UTC',
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
        }.deep_stringify_keys
      end
    end
  end
end
