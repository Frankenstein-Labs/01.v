# frozen_string_literal: true

FactoryBot.define do
  factory :security_finding, class: 'Security::Finding' do
    scanner factory: :vulnerabilities_scanner
    scan factory: :security_scan

    severity { :critical }
    uuid { SecureRandom.uuid }
    context_unaware_uuid { nil }

    after(:build) do |finding|
      finding.project_id ||= finding.scan&.project_id
    end

    transient do
      false_positive { false }
    end

    transient do
      solution { 'foo' }
    end

    transient do
      remediation_byte_offsets { [] }
    end

    transient do
      location do
        { report_type: "coverage_fuzzing", crash_type: "Heap-buffer-overflow\nREAD 1",
          crash_address: "0x602000001573", stacktrace_snippet: "INFO: Seed: 3415817494\nINFO: Loaded 1 modules" }
      end
    end

    transient do
      assets { [{ name: "Test Postman Collection", type: "postman", url: "http://localhost/test.collection" }] }
    end

    transient do
      evidence do
        {
          summary: 'Credit card detected',
          request: {
            headers: [{ name: 'Accept', value: '*/*' }],
            method: 'GET',
            url: 'http://goat:8080/WebGoat/logout',
            body: nil
          },
          response: {
            headers: [{ name: 'Content-Length', value: '0' }],
            reason_phrase: 'OK',
            status_code: 200,
            body: [{ user_id: 1, user: "admin", first: "Joe", last: "Smith", password: "Password!" }]
          },
          source: {
            id: 'assert:Response Body Analysis',
            name: 'Response Body Analysis',
            url: 'htpp://hostname/documentation'
          },
          supporting_messages: [
            {
              name: 'Origional',
              request: {
                headers: [{ name: 'Accept', value: '*/*' }],
                method: 'GET',
                url: 'http://goat:8080/WebGoat/logout',
                body: [{ user_id: 1, user: "admin", first: "Joe", last: "Smith", password: "Password!" }]
              }
            },
            {
              name: 'Recorded',
              request: {
                headers: [{ name: 'Accept', value: '*/*' }],
                method: 'GET',
                url: 'http://goat:8080/WebGoat/logout',
                body: [{ user_id: 1, user: "admin", first: "Joe", last: "Smith", password: "Password!" }]
              },
              response: {
                headers: [{ name: 'Content-Length', value: '0' }],
                reason_phrase: 'OK',
                status_code: 200,
                body: [{ user_id: 1, user: "admin", first: "Joe", last: "Smith", password: "Password!" }]
              }
            }
          ]
        }
      end
    end

    transient do
      identifiers do
        [
          create(:ci_reports_security_identifier).to_hash,
          create(:ci_reports_security_identifier, :cwe).to_hash
        ]
      end
    end

    trait :with_token_data do
      transient do
        token_type_value { 'AWS' }
        token_value_data { 'AKIAIOSFODNN7EXAMPLE' }
      end

      identifiers do
        [
          { external_type: 'gitleaks_rule_id', external_id: token_type_value }
        ]
      end
    end

    trait :with_finding_data do
      finding_data do
        {
          name: 'Test finding',
          description: 'The cipher does not provide data integrity update 1',
          solution: solution,
          identifiers: identifiers,
          links: [
            {
              name: 'Cipher does not check for integrity first?',
              url: 'https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first'
            }
          ],
          false_positive?: false_positive,
          location: location,
          evidence: evidence,
          assets: assets,
          details: {},
          raw_source_code_extract: 'AES/ECB/NoPadding',
          remediation_byte_offsets: remediation_byte_offsets
        }
      end
    end

    trait :with_token_status do
      transient do
        token_status { :unknown } # Default to unknown, but can be overridden
      end

      after(:create) do |finding, evaluator|
        finding.create_token_status(status: evaluator.token_status)
      end
    end
  end
end
