# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Security::Parsers::Sarif, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let(:report) { Gitlab::Ci::Reports::Security::Report.new('sarif', pipeline, nil) }
  let(:validate) { false }
  let(:typed_reports) { described_class.parse!(json_data, report, validate: validate) }
  let(:typed_report) { typed_reports.first }

  # Build a minimal SARIF JSON string around the provided results array.
  # Use this instead of duplicating the outer envelope in every context.
  def sarif_doc(results:, tool_name: 'TestTool', rules: [])
    {
      'version' => '2.1.0',
      'runs' => [{
        'tool' => { 'driver' => { 'name' => tool_name, 'rules' => rules } },
        'results' => results
      }]
    }.to_json
  end

  # A result that will be accepted: has ruleId and physicalLocation.
  def valid_result(rule_id: 'R1', file: 'app/foo.rb', line: 1, **overrides)
    {
      'ruleId' => rule_id,
      'locations' => [{
        'physicalLocation' => {
          'artifactLocation' => { 'uri' => file },
          'region' => { 'startLine' => line }
        }
      }]
    }.merge(overrides)
  end

  # A result that will be skipped: has ruleId but no physicalLocation.
  def invalid_result(rule_id: 'R1-invalid')
    { 'ruleId' => rule_id }
  end

  describe '.parse!' do
    context 'with a minimal valid SARIF document' do
      let(:json_data) { fixture_file('security_reports/sarif/minimal.sarif.json', dir: 'ee') }

      it 'adds findings to the report' do
        expect(typed_report.findings).not_to be_empty
      end

      it 'sets the scanner name from tool.driver.name' do
        expect(typed_report.scanner.name).to eq('Semgrep')
      end

      it 'sets the scanner external_id as a downcased slug' do
        expect(typed_report.scanner.external_id).to eq('semgrep')
      end

      it 'returns an array of Security::Report objects' do
        expect(typed_reports).to all(be_a(Gitlab::Ci::Reports::Security::Report))
      end
    end

    context 'with a full valid SARIF document' do
      let(:json_data) { fixture_file('security_reports/sarif/valid.sarif.json', dir: 'ee') }

      it 'parses all findings' do
        expect(typed_report.findings.length).to eq(2)
      end

      it 'uses rule shortDescription as the finding name' do
        expect(typed_report.findings.first.name).to eq('Potential SQL injection vulnerability')
      end

      it 'sets description from result.message.text' do
        expected = 'User input is used directly in a SQL query without sanitization.'
        expect(typed_report.findings.first.description).to eq(expected)
      end

      it 'sets file_path from artifactLocation.uri' do
        expect(typed_report.findings.first.location.file_path).to eq('app/models/user.rb')
      end

      it 'sets start_line and end_line from region' do
        location = typed_report.findings.first.location
        expect(location.start_line).to eq(42)
        expect(location.end_line).to eq(42)
      end

      it 'stores location_data with file/start_line/end_line keys for persistence' do
        location_data = typed_report.findings.first.location_data
        expect(location_data).to eq({
          'file' => 'app/models/user.rb',
          'start_line' => 42,
          'end_line' => 42
        })
      end

      it 'creates a primary identifier scoped to the tool name' do
        primary = typed_report.findings.first.identifiers.first
        expect(primary.external_type).to eq('semgrep')
        expect(primary.external_id).to eq('sql-injection')
      end

      it 'extracts CWE tags as secondary identifiers' do
        cwe_id = typed_report.findings.first.identifiers.find { |i| i.external_type == 'cwe' }
        expect(cwe_id).not_to be_nil
        expect(cwe_id.external_id).to eq('89')
        expect(cwe_id.url).to eq('https://cwe.mitre.org/data/definitions/89.html')
      end
    end

    context 'with a CVE tag on the rule' do
      let(:json_data) do
        sarif_doc(
          rules: [{ 'id' => 'R1', 'properties' => { 'tags' => ['CVE-2021-44228'] } }],
          results: [valid_result]
        )
      end

      it 'extracts CVE tags as secondary identifiers' do
        cve_id = typed_report.findings.first.identifiers.find { |i| i.external_type == 'cve' }
        expect(cve_id).not_to be_nil
        expect(cve_id.external_id).to eq('2021-44228')
        expect(cve_id.url).to eq('https://www.cve.org/CVERecord?id=CVE-2021-44228')
      end
    end

    context 'with a descriptive CVE tag on the rule' do
      let(:json_data) do
        sarif_doc(
          rules: [{ 'id' => 'R1', 'properties' => { 'tags' => ['CVE-2021-44228: Log4Shell'] } }],
          results: [valid_result]
        )
      end

      it 'extracts CVE tags as secondary identifiers without the trailing description' do
        cve_id = typed_report.findings.first.identifiers.find { |i| i.external_type == 'cve' }
        expect(cve_id).not_to be_nil
        expect(cve_id.external_id).to eq('2021-44228')
        expect(cve_id.url).to eq('https://www.cve.org/CVERecord?id=CVE-2021-44228')
      end
    end

    describe 'suppression' do
      context 'with suppressions' do
        using RSpec::Parameterized::TableSyntax

        where(:status, :expected_count) do
          nil           | 0  # no status = accepted suppression by default
          'accepted'    | 0  # explicitly accepted
          'underReview' | 1  # contested - include the finding
          'rejected'    | 1  # contested - include the finding
        end

        with_them do
          let(:json_data) do
            suppression = { 'kind' => 'inSource', 'status' => status }
            sarif_doc(results: [valid_result('suppressions' => [suppression])])
          end

          it 'includes or skips the finding based on suppression status' do
            expect(typed_report.findings.length).to eq(expected_count)
          end

          it 'emits no ingestion warning or error' do
            typed_reports
            ingestion_msgs = (report.warnings + report.errors).select { |m| m[:type] == 'Ingestion' }
            expect(ingestion_msgs).to be_empty
          end
        end
      end

      context 'with a mix of suppressed, valid, and dropped results' do
        # 1 suppressed + 1 valid + 1 dropped = 1 of 2. (50%, at threshold).
        let(:json_data) do
          sarif_doc(results: [
            valid_result(rule_id: 'R1', 'suppressions' => [{ 'kind' => 'inSource', 'status' => 'accepted' }]),
            valid_result(rule_id: 'R2'),
            { 'ruleId' => 'R3' }
          ])
        end

        before do
          allow(Gitlab::AppLogger).to receive(:info)
        end

        it 'excludes suppressed from the drop count and lists only non-suppressed causes' do
          expect(typed_report.warnings).to include(
            a_hash_including(
              type: 'Ingestion',
              message: include('1 of 2 result(s) were skipped during ingestion. ' \
                'Causes: missing physicalLocation (1).')
            )
          )
        end
      end

      context 'without suppressions' do
        let(:json_data) { sarif_doc(results: [valid_result]) }

        it 'includes findings' do
          expect(typed_report.findings.length).to eq(1)
        end
      end
    end

    context 'with severity from rule.properties.security-severity' do
      let(:json_data) do
        sarif_doc(
          rules: [{ 'id' => 'R1', 'properties' => { 'security-severity' => '9.1' } }],
          results: [valid_result]
        )
      end

      it 'maps rule.properties.security-severity 9.1 (x10 = 91.0) to critical' do
        expect(typed_report.findings.first.severity).to eq('critical')
      end
    end

    context 'with rule.properties.security-severity taking precedence over result.properties' do
      let(:json_data) do
        sarif_doc(
          rules: [{ 'id' => 'R1', 'properties' => { 'security-severity' => '2.0' } }],
          results: [valid_result('properties' => { 'security-severity' => '9.9' })]
        )
      end

      it 'uses rule.properties (2.0 -> low) over result.properties (9.9 -> critical)' do
        expect(typed_report.findings.first.severity).to eq('low')
      end
    end

    context 'with fullDescription as name and description fallback' do
      let(:json_data) do
        sarif_doc(
          rules: [{ 'id' => 'R1', 'fullDescription' => { 'text' => 'A detailed description of the rule.' } }],
          results: [valid_result]
        )
      end

      it 'uses fullDescription.text as the finding name when no shortDescription or message' do
        expect(typed_report.findings.first.name).to eq('A detailed description of the rule.')
      end

      it 'uses fullDescription.text as the description when no message.text' do
        expect(typed_report.findings.first.description).to eq('A detailed description of the rule.')
      end
    end

    context 'with severity from level field' do
      using RSpec::Parameterized::TableSyntax

      where(:level, :expected_severity) do
        'error'   | 'high'
        'warning' | 'medium'
        'note'    | 'low'
        'none'    | 'info'
      end

      with_them do
        let(:json_data) { sarif_doc(results: [valid_result('level' => level)]) }

        it "maps level '#{params[:level]}' to '#{params[:expected_severity]}'" do
          expect(typed_report.findings.first.severity).to eq(expected_severity)
        end
      end
    end

    context 'with severity from rank field' do
      using RSpec::Parameterized::TableSyntax

      where(:rank, :expected_severity) do
        0.0   | 'info'
        9.9   | 'info'
        10.0  | 'low'
        39.9  | 'low'
        40.0  | 'medium'
        69.9  | 'medium'
        70.0  | 'high'
        89.9  | 'high'
        90.0  | 'critical'
        100.0 | 'critical'
      end

      with_them do
        let(:json_data) { sarif_doc(results: [valid_result('rank' => rank, 'level' => 'error')]) }

        it "maps rank #{params[:rank]} to '#{params[:expected_severity]}'" do
          expect(typed_report.findings.first.severity).to eq(expected_severity)
        end
      end
    end

    context 'with severity from result.properties.security-severity (fallback)' do
      let(:json_data) { sarif_doc(results: [valid_result('properties' => { 'security-severity' => '7.5' })]) }

      it 'maps result.properties security-severity 7.5 (x10 = 75.0) to high when no rule.properties present' do
        expect(typed_report.findings.first.severity).to eq('high')
      end
    end

    context 'with rank taking precedence over level and security-severity' do
      let(:json_data) do
        sarif_doc(results: [valid_result('rank' => 5.0, 'level' => 'error',
          'properties' => { 'security-severity' => '9.9' })])
      end

      it 'uses rank (5.0 -> info) over level (error -> high) and security-severity (9.9 -> critical)' do
        expect(typed_report.findings.first.severity).to eq('info')
      end
    end

    context 'with uriBaseId resolution' do
      let(:json_data) do
        {
          'version' => '2.1.0',
          'runs' => [{
            'tool' => { 'driver' => { 'name' => 'TestTool' } },
            'originalUriBaseIds' => { 'SRCROOT' => { 'uri' => 'file:///workspace/' } },
            'results' => [{
              'ruleId' => 'R1',
              'locations' => [{
                'physicalLocation' => {
                  'artifactLocation' => { 'uri' => 'src/main.rb', 'uriBaseId' => 'SRCROOT' },
                  'region' => { 'startLine' => 1 }
                }
              }]
            }]
          }]
        }.to_json
      end

      it 'resolves the full file path' do
        expect(typed_report.findings.first.location.file_path).to eq('/workspace/src/main.rb')
      end
    end

    context 'with multiple runs' do
      let(:json_data) { fixture_file('security_reports/sarif/multi_run.sarif.json', dir: 'ee') }

      it 'includes findings from all runs' do
        expect(typed_reports.flat_map(&:findings).length).to eq(2)
      end

      it 'emits one typed report per run' do
        expect(typed_reports.size).to eq(2)
      end

      it 'registers each run scanner in its own typed report' do
        expect(typed_reports.map { |r| r.scanner.external_id }).to match_array(%w[semgrep eslint])
      end

      it 'attributes each finding to its own run scanner' do
        all_findings = typed_reports.flat_map(&:findings)
        semgrep_finding = all_findings.find { |f| f.location.file_path == 'app/models/user.rb' }
        eslint_finding  = all_findings.find { |f| f.location.file_path == 'app/javascript/utils.js' }

        expect(semgrep_finding.scanner.external_id).to eq('semgrep')
        expect(eslint_finding.scanner.external_id).to eq('eslint')
      end
    end

    context 'with missing ruleId' do
      # A result that has a physical location and a message but no ruleId/rule.id.
      def result_without_rule_id(overrides = {})
        base = valid_result('message' => { 'text' => 'A finding with no rule association' })
          .except('ruleId')
          .merge(overrides)
        sarif_doc(results: [base])
      end

      context 'when neither ruleId nor rule.id is present' do
        let(:json_data) { result_without_rule_id }

        before do
          allow(Gitlab::AppLogger).to receive(:info)
          typed_reports
        end

        it 'skips the finding' do
          expect(typed_report.findings).to be_empty
        end

        it 'logs an info message for the skipped finding' do
          expect(Gitlab::AppLogger).to have_received(:info).with(
            a_hash_including(
              message: "SARIF finding skipped: ruleId absent",
              result_message: include('A finding with no rule association')
            )
          )
        end

        it 'adds a drop count error when all results are skipped (100% > 50% threshold)' do
          expect(typed_report.errors).to include(
            a_hash_including(type: 'Ingestion', message: /1 of 1 result\(s\) could not be ingested/)
          )
        end

        it 'does not add any warnings for the drop' do
          expect(typed_report.warnings).to be_empty
        end
      end

      context 'when ruleId is absent but rule.id is present' do
        let(:json_data) { result_without_rule_id('rule' => { 'id' => 'R1' }) }

        it 'accepts the finding using rule.id as the rule identifier' do
          expect(typed_report.findings.length).to eq(1)
        end

        it 'sets the primary identifier from rule.id' do
          primary = typed_report.findings.first.identifiers.first
          expect(primary.external_type).to eq('testtool')
          expect(primary.external_id).to eq('R1')
        end

        it 'does not add any warnings' do
          expect(typed_report.warnings).to be_empty
        end
      end

      context 'when both ruleId and rule.id are present and equal' do
        let(:json_data) { result_without_rule_id('ruleId' => 'R1', 'rule' => { 'id' => 'R1' }) }

        it 'accepts the finding' do
          expect(typed_report.findings.length).to eq(1)
        end

        it 'uses ruleId as the primary identifier' do
          expect(typed_report.findings.first.identifiers.first.external_id).to eq('R1')
        end
      end
    end

    context 'when validating limits' do
      shared_examples 'logs message' do
        before do
          allow(Gitlab::AppLogger).to receive(:warn)
          typed_reports
        end

        it 'logs the message with project and pipeline context' do
          expect(Gitlab::AppLogger).to have_received(:warn).with(
            a_hash_including(
              message: include(expected_log_message),
              project_id: project.id,
              pipeline_id: pipeline.id
            )
          )
        end
      end

      shared_examples 'records an ingestion warning' do
        it 'adds an ingestion warning to the report' do
          typed_reports
          expect(report.warnings).to include(
            a_hash_including(type: 'Ingestion', message: include(expected_log_message))
          )
        end
      end

      def build_run(tool_name, rule_id, file_path)
        {
          'tool' => { 'driver' => { 'name' => tool_name } },
          'results' => [{
            'ruleId' => rule_id,
            'locations' => [{
              'physicalLocation' => {
                'artifactLocation' => { 'uri' => file_path },
                'region' => { 'startLine' => 1 }
              }
            }]
          }]
        }
      end

      context 'when runs count equals MAX_RUNS' do
        let(:json_data) do
          runs = Array.new(described_class::MAX_RUNS) { |i| build_run("Tool#{i}", "R#{i}", "app/file#{i}.rb") }
          { 'version' => '2.1.0', 'runs' => runs }.to_json
        end

        it 'parses successfully without errors' do
          expect(typed_reports.flat_map(&:errors)).to be_empty
        end

        it 'adds findings from all runs' do
          expect(typed_reports.flat_map(&:findings).length).to eq(described_class::MAX_RUNS)
        end
      end

      context 'when runs count exceeds MAX_RUNS' do
        let(:json_data) do
          runs = Array.new(described_class::MAX_RUNS + 1) { |i| build_run("Tool#{i}", "R#{i}", "app/file#{i}.rb") }
          { 'version' => '2.1.0', 'runs' => runs }.to_json
        end

        it 'adds an error to the report' do
          typed_reports
          expect(report.errors).to include(
            a_hash_including(
              type: 'Ingestion',
              message: include("exceeds the maximum of #{described_class::MAX_RUNS}")
            )
          )
        end

        it 'returns no findings' do
          typed_reports
          expect(report.findings).to be_empty
        end

        it 'returns the envelope wrapped in an array' do
          expect(typed_reports).to eq([report])
        end
      end

      context 'with too many results per run' do
        before do
          stub_const("#{described_class}::MAX_RESULTS_PER_RUN", 3)
        end

        let(:limit) { described_class::MAX_RESULTS_PER_RUN }

        context 'when results count equals the limit' do
          let(:json_data) do
            results = Array.new(limit) { |i| valid_result(rule_id: "R#{i}", file: "app/file#{i}.rb") }
            sarif_doc(results: results)
          end

          it 'ingests every result with no warning' do
            expect(typed_report.findings.length).to eq(limit)
            expect(report.warnings).to be_empty
          end
        end

        context 'when results count exceeds the limit' do
          let(:expected_log_message) { "contains #{limit + 1} results, which exceeds the maximum of #{limit}" }
          let(:json_data) do
            results = Array.new(limit + 1) { |i| valid_result(rule_id: "R#{i}", file: "app/file#{i}.rb") }
            sarif_doc(results: results)
          end

          it 'truncates and ingests up to the limit' do
            expect(typed_report.findings.length).to eq(limit)
          end

          it_behaves_like 'records an ingestion warning'
          it_behaves_like 'logs message'
        end
      end

      context 'with too many rules per run' do
        before do
          stub_const("#{described_class}::MAX_RULES_PER_RUN", 3)
        end

        let(:limit) { described_class::MAX_RULES_PER_RUN }
        let(:expected_log_message) { "contains #{limit + 1} rules, which exceeds the maximum of #{limit}" }
        let(:json_data) do
          rules = Array.new(limit + 1) { |i| { 'id' => "R#{i}", 'name' => "rule#{i}" } }
          sarif_doc(rules: rules, results: [valid_result(rule_id: 'R0')])
        end

        it 'ingests results whose ruleId falls inside the limit' do
          expect(typed_report.findings.length).to eq(1)
        end

        it_behaves_like 'records an ingestion warning'
        it_behaves_like 'logs message'
      end

      context 'with too many tags per rule' do
        before do
          stub_const("#{described_class}::MAX_TAGS_PER_RULE", 2)
        end

        let(:limit) { described_class::MAX_TAGS_PER_RULE }
        let(:expected_log_message) { "1 rule had more than #{limit} tags" }
        let(:json_data) do
          tags = Array.new(limit) { |i| "tag-#{i}" } + ['CWE-123']
          sarif_doc(
            rules: [{ 'id' => 'R1', 'properties' => { 'tags' => tags } }],
            results: [valid_result(rule_id: 'R1')]
          )
        end

        it 'drops tags beyond the limit so the trailing CWE is not extracted' do
          cwe_ids = typed_report.findings.first.identifiers.select { |i| i.external_type == 'cwe' }
          expect(cwe_ids).to be_empty
        end

        it_behaves_like 'records an ingestion warning'
        it_behaves_like 'logs message'
      end

      context 'with multiple rules each exceeding the tag limit' do
        before do
          stub_const("#{described_class}::MAX_TAGS_PER_RULE", 2)
        end

        let(:limit) { described_class::MAX_TAGS_PER_RULE }
        let(:rule_count) { 2 }

        let(:json_data) do
          tags = Array.new(limit + 1) { |i| "tag-#{i}" }
          rules = Array.new(rule_count) { |i| { 'id' => "R#{i}", 'properties' => { 'tags' => tags } } }
          sarif_doc(rules: rules, results: [valid_result(rule_id: 'R0')])
        end

        it 'aggregates the warning into a single line' do
          typed_reports
          tag_warnings = report.warnings.select { |w| w[:message].include?('tags') }
          expect(tag_warnings.size).to eq(1)
          expect(tag_warnings.first[:message]).to include("#{rule_count} rules")
        end
      end

      context 'with oversized string fields' do
        before do
          stub_const("#{described_class}::MAX_CHARS", {
            rule_name: 5,
            short_description: 5,
            full_description: 5,
            message: 5,
            help_uri: 5
          }.freeze)
        end

        let(:limits) { described_class::MAX_CHARS }

        shared_examples 'skips the result and warns about the oversize field' do |field|
          let(:expected_log_message) { "Result skipped: `#{field}` exceeded the #{limits[field]}-character limit." }

          it 'skips the result' do
            expect(typed_report.findings).to be_empty
          end

          it_behaves_like 'records an ingestion warning'
          it_behaves_like 'logs message'
        end

        context 'when message.text exceeds its limit' do
          let(:json_data) do
            sarif_doc(results: [valid_result('message' => { 'text' => 'x' * (limits[:message] + 1) })])
          end

          it_behaves_like 'skips the result and warns about the oversize field', :message
        end

        context 'when rule name exceeds its limit' do
          let(:json_data) do
            sarif_doc(
              rules: [{ 'id' => 'R1', 'name' => 'x' * (limits[:rule_name] + 1) }],
              results: [valid_result(rule_id: 'R1')]
            )
          end

          it_behaves_like 'skips the result and warns about the oversize field', :rule_name
        end

        context 'when rule shortDescription.text exceeds its limit' do
          let(:json_data) do
            sarif_doc(
              rules: [{ 'id' => 'R1', 'shortDescription' => { 'text' => 'x' * (limits[:short_description] + 1) } }],
              results: [valid_result(rule_id: 'R1')]
            )
          end

          it_behaves_like 'skips the result and warns about the oversize field', :short_description
        end

        context 'when rule fullDescription.text exceeds its limit' do
          let(:json_data) do
            sarif_doc(
              rules: [{ 'id' => 'R1', 'fullDescription' => { 'text' => 'x' * (limits[:full_description] + 1) } }],
              results: [valid_result(rule_id: 'R1')]
            )
          end

          it_behaves_like 'skips the result and warns about the oversize field', :full_description
        end

        context 'when rule helpUri exceeds its limit' do
          let(:json_data) do
            oversized = 'h' * (limits[:help_uri] + 1)
            sarif_doc(
              rules: [{ 'id' => 'R1', 'helpUri' => oversized }],
              results: [valid_result(rule_id: 'R1')]
            )
          end

          it_behaves_like 'skips the result and warns about the oversize field', :help_uri
        end

        context 'with many results triggering the same oversize field' do
          let(:json_data) do
            oversized = 'x' * (limits[:message] + 1)
            results = Array.new(5) { valid_result('message' => { 'text' => oversized }) }
            sarif_doc(results: results)
          end

          it 'warns only once per oversize field' do
            typed_reports
            message_warnings = report.warnings.select { |w| w[:message].include?('`message`') }
            expect(message_warnings.size).to eq(1)
          end
        end

        context 'when a single result has multiple oversize fields' do
          let(:json_data) do
            sarif_doc(
              rules: [{ 'id' => 'R1', 'name' => 'x' * (limits[:rule_name] + 1) }],
              results: [valid_result(rule_id: 'R1', 'message' => { 'text' => 'x' * (limits[:message] + 1) })]
            )
          end

          it 'skips the result' do
            expect(typed_report.findings).to be_empty
          end

          it 'emits a warning for every oversize field, not just the first' do
            typed_reports
            messages = report.warnings.map { |w| w[:message] }
            expect(messages).to include(a_string_matching(/`rule_name`/))
            expect(messages).to include(a_string_matching(/`message`/))
          end
        end
      end
    end

    context 'with invalid JSON' do
      let(:json_data) { 'not json {{{' }

      it 'raises SecurityReportParserError' do
        expect { typed_reports }
          .to raise_error(Gitlab::Ci::Parsers::ParserError, /parsing failed/i)
      end
    end

    context 'with validate: true and a schema-invalid document' do
      let(:json_data) { { 'version' => '2.1.0' }.to_json }
      let(:validate) { true }

      it 'adds schema errors to the report and returns no findings' do
        typed_reports

        expect(report.findings).to be_empty
        expect(report.errors).not_to be_empty
      end

      it 'returns the envelope wrapped in an array' do
        expect(typed_reports).to eq([report])
      end
    end

    context 'with validate: true and an unsupported version' do
      let(:json_data) { { 'version' => '1.0.0', 'runs' => [] }.to_json }
      let(:validate) { true }

      it 'adds a version error and returns no findings' do
        typed_reports

        expect(report.findings).to be_empty
        expect(report.errors.pluck(:message).join).to match(/Unsupported SARIF version/)
      end
    end

    context 'with no_locations fixture' do
      let(:json_data) { fixture_file('security_reports/sarif/no_locations.sarif.json', dir: 'ee') }

      before do
        allow(Gitlab::AppLogger).to receive(:info)
        typed_reports
      end

      it 'accepts the result with a physical location but no region' do
        expect(typed_report.findings.length).to eq(1)
        expect(typed_report.findings.first.location.file_path).to eq('app/models/user.rb')
      end

      it 'sets nil lines for the no-region result' do
        location = typed_report.findings.first.location
        expect(location.start_line).to be_nil
        expect(location.end_line).to be_nil
      end

      it 'logs info messages for the two skipped results' do
        expect(Gitlab::AppLogger).to have_received(:info).with(
          a_hash_including(message: "SARIF finding skipped: no physicalLocation", rule_id: 'rule-no-locations')
        )
        expect(Gitlab::AppLogger).to have_received(:info).with(
          a_hash_including(message: "SARIF finding skipped: no physicalLocation", rule_id: 'rule-logical-only')
        )
      end

      it 'adds a drop count error when the drop rate exceeds the 50% threshold (2/3 = 66.7%)' do
        expect(typed_report.errors).to include(
          a_hash_including(type: 'Ingestion', message: /2 of 3 result\(s\) could not be ingested/)
        )
      end

      it 'does not add an Ingestion warning' do
        expect(typed_report.warnings).to be_empty
      end
    end

    describe 'ingestion failure threshold' do
      before do
        allow(Gitlab::AppLogger).to receive(:info)
        typed_reports
      end

      context 'when drop rate is 0% (all results valid)' do
        let(:json_data) { sarif_doc(results: [valid_result(rule_id: 'R1'), valid_result(rule_id: 'R2')]) }

        it 'emits no Ingestion warning' do
          expect(typed_report.warnings).to be_empty
        end

        it 'emits no Ingestion error' do
          expect(typed_report.errors).to be_empty
        end

        it 'ingests all findings' do
          expect(typed_report.findings.length).to eq(2)
        end
      end

      context 'when drop rate is 50% (at threshold, partial ingestion)' do
        let(:json_data) { sarif_doc(results: [valid_result, invalid_result]) }

        it 'emits an Ingestion warning with the drop count' do
          expect(typed_report.warnings).to include(
            a_hash_including(type: 'Ingestion', message: /1 of 2 result\(s\) were skipped/)
          )
        end

        it 'emits no Ingestion error' do
          expect(typed_report.errors.map { |e| e[:type] }).not_to include('Ingestion')
        end

        it 'ingests only the valid findings' do
          expect(typed_report.findings.length).to eq(1)
        end
      end

      context 'when drop rate is 67% (above threshold, scan aborted)' do
        let(:json_data) do
          sarif_doc(results: [valid_result, invalid_result(rule_id: 'R-inv-1'), invalid_result(rule_id: 'R-inv-2')])
        end

        it 'emits an Ingestion error with the drop count' do
          expect(typed_report.errors).to include(
            a_hash_including(type: 'Ingestion', message: /2 of 3 result\(s\) could not be ingested/)
          )
        end

        it 'emits no Ingestion warning' do
          expect(typed_report.warnings.map { |w| w[:type] }).not_to include('Ingestion')
        end

        it 'ingests only the valid findings' do
          expect(typed_report.findings.length).to eq(1)
        end
      end

      context 'when drop rate is 100% (all results invalid, scan aborted)' do
        let(:json_data) { sarif_doc(results: [invalid_result]) }

        it 'emits an Ingestion error with the drop count' do
          expect(typed_report.errors).to include(
            a_hash_including(type: 'Ingestion', message: /1 of 1 result\(s\) could not be ingested/)
          )
        end

        it 'emits no Ingestion warning' do
          expect(typed_report.warnings.map { |w| w[:type] }).not_to include('Ingestion')
        end

        it 'ingests no findings' do
          expect(typed_report.findings).to be_empty
        end
      end
    end

    describe 'ingestion summary breakdown' do
      before do
        allow(Gitlab::AppLogger).to receive(:info)
      end

      context 'when results are dropped for a single cause (oversized field)' do
        before do
          stub_const("#{described_class}::MAX_CHARS",
            { rule_name: 5, short_description: 5, full_description: 5, message: 5, help_uri: 5 }.freeze)
        end

        let(:json_data) do
          oversized = 'x' * 10
          sarif_doc(results: [
            valid_result(rule_id: 'R1', 'message' => { 'text' => oversized }),
            valid_result(rule_id: 'R2', 'message' => { 'text' => oversized }),
            valid_result(rule_id: 'R3')
          ])
        end

        it 'lists only the firing cause with its count' do
          expect(typed_report.errors).to include(
            a_hash_including(
              type: 'Ingestion',
              message: include('Causes: text field exceeded length limit (2).')
            )
          )
        end
      end

      context 'when results are dropped for multiple causes' do
        # One missing ruleId + one missing physicalLocation + two valid = 50%
        let(:json_data) do
          sarif_doc(results: [
            valid_result(rule_id: 'R1'),
            valid_result(rule_id: 'R2'),
            { 'ruleId' => 'R3' },                        # missing physicalLocation
            { 'locations' => [{ 'physicalLocation' => {  # missing ruleId
              'artifactLocation' => { 'uri' => 'f.rb' },
              'region' => { 'startLine' => 1 }
            } }] }
          ])
        end

        it 'lists causes with individual count' do
          expect(typed_report.warnings).to include(
            a_hash_including(
              type: 'Ingestion',
              message: match(/missing ruleId \(1\).*missing physicalLocation \(1\)/m)
            )
          )
        end
      end
    end

    context 'with a CWE identifier mapping to SAST' do
      let(:json_data) do
        sarif_doc(
          tool_name: 'Semgrep',
          # CWE-89 (SQL Injection) maps to sast
          rules: [{ 'id' => 'R1', 'properties' => { 'tags' => ['CWE-89'] } }],
          results: [valid_result(rule_id: 'R1')]
        )
      end

      it 'emits a single sast typed report' do
        expect(typed_reports.map(&:type)).to eq(['sast'])
      end

      it 'sets scanner_external_id from tool.driver.name' do
        expect(typed_report.scanner_external_id).to eq('semgrep')
      end

      it 'tags the finding with the inferred report type' do
        expect(typed_report.findings.first.report_type.to_sym).to eq(:sast)
      end
    end

    context 'with a CWE identifier mapping to secret detection' do
      let(:json_data) do
        sarif_doc(
          # CWE-798 (Hardcoded Credentials) maps to secret_detection
          rules: [{ 'id' => 'R1', 'properties' => { 'tags' => ['CWE-798'] } }],
          results: [valid_result(rule_id: 'R1')]
        )
      end

      it 'emits a single secret detection typed report' do
        expect(typed_reports.map(&:type)).to eq(['secret_detection'])
      end
    end

    context 'with a CVE in ruleId' do
      let(:json_data) do
        sarif_doc(
          tool_name: 'Trivy',
          # CVE in ruleId maps to dependency_scanning.
          rules: [{ 'id' => 'CVE-2021-44228' }],
          results: [valid_result(rule_id: 'CVE-2021-44228')]
        )
      end

      it 'emits a single dependency scanning typed report' do
        expect(typed_reports.map(&:type)).to eq(['dependency_scanning'])
      end

      it 'sets scanner_external_id from tool.driver.name' do
        expect(typed_report.scanner_external_id).to eq('trivy')
      end

      it 'persists a cve secondary identifier extracted from the ruleId' do
        cve_id = typed_report.findings.first.identifiers.find { |i| i.external_type == 'cve' }
        expect(cve_id.external_id).to eq('2021-44228')
      end
    end

    context 'with results spanning multiple inferred types in one run' do
      # Two rules in one Semgrep run: CWE-89 (SAST) and CWE-798 (secret detection).
      let(:json_data) do
        sarif_doc(
          tool_name: 'Semgrep',
          rules: [
            { 'id' => 'R-SAST',   'properties' => { 'tags' => ['CWE-89'] } },
            { 'id' => 'R-SECRET', 'properties' => { 'tags' => ['CWE-798'] } }
          ],
          results: [
            valid_result(rule_id: 'R-SAST', file: 'app/a.rb', line: 1),
            valid_result(rule_id: 'R-SECRET', file: 'app/b.rb', line: 2)
          ]
        )
      end

      it 'emits one typed report per inferred type' do
        expect(typed_reports.map(&:type)).to contain_exactly('sast', 'secret_detection')
      end

      it 'shares scanner_external_id across typed reports from the same run' do
        expect(typed_reports.map(&:scanner_external_id).uniq).to eq(['semgrep'])
      end

      it 'does not assign sarif to any finding' do
        types = typed_reports.flat_map(&:findings).map { |f| f.report_type.to_s }
        expect(types).not_to include('sarif')
      end
    end

    context 'with a Flawfinder-style SARIF using rule.relationships for CWE' do
      let(:json_data) { fixture_file('security_reports/sarif/flawfinder_relationships.sarif.json', dir: 'ee') }

      it 'emits a single sast typed report' do
        expect(typed_reports.size).to eq(1)
        expect(typed_report.type).to eq('sast')
      end

      it 'sets scanner_external_id from tool.driver.name' do
        expect(typed_report.scanner_external_id).to eq('flawfinder')
      end

      it 'persists a cwe secondary identifier extracted from rule.relationships' do
        cwe_id = typed_report.findings.first.identifiers.find { |i| i.external_type == 'cwe' }
        expect(cwe_id.external_id).to eq('119')
      end
    end
  end

  describe '#calculate_uuid' do
    let(:json_data) { fixture_file('security_reports/sarif/minimal.sarif.json', dir: 'ee') }
    let(:finding_instance_double) { instance_double(::Gitlab::Ci::Reports::Security::Finding) }

    context 'when primary_identifier is nil' do
      it 'logs an info message and returns nil' do
        allow(::Gitlab::Ci::Reports::Security::Finding).to receive(:new).and_return(finding_instance_double)
        allow(finding_instance_double).to receive(:uuid).and_return(nil)

        expect(Gitlab::AppLogger).to receive(:info).with(
          a_hash_including(message: "SARIF finding skipped: nil UUID components")
        )

        typed_reports
      end
    end
  end

  describe '.rank_to_severity' do
    using RSpec::Parameterized::TableSyntax

    where(:rank, :expected) do
      0.0   | 'info'
      9.9   | 'info'
      10.0  | 'low'
      39.9  | 'low'
      40.0  | 'medium'
      69.9  | 'medium'
      70.0  | 'high'
      89.9  | 'high'
      90.0  | 'critical'
      100.0 | 'critical'
    end

    with_them do
      it "maps rank #{params[:rank]} to #{params[:expected]}" do
        expect(described_class.rank_to_severity(rank)).to eq(expected)
      end
    end
  end
end
