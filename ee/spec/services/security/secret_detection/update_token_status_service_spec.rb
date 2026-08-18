# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::UpdateTokenStatusService, feature_category: :secret_detection do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:pipeline) { create(:ci_pipeline, :success, project: project) }
  let_it_be_with_reload(:finding) do
    create(
      :vulnerabilities_finding,
      :with_secret_detection_pat,
      pipeline: pipeline,
      token_value: "glpat-10000000000000000000"
    )
  end

  shared_examples 'does not create vulnerability finding token status' do
    it 'does not run' do
      expect { execute }.not_to change { Vulnerabilities::FindingTokenStatus.count }
    end
  end

  shared_examples 'does not create security finding token status' do
    it 'does not create security finding token status' do
      expect { execute }.not_to change { Security::FindingTokenStatus.count }
    end
  end

  describe '#execute_for_vulnerability_pipeline' do
    subject(:execute) { described_class.new.execute_for_vulnerability_pipeline(pipeline.id) }

    shared_examples 'creates a finding token status' do |expected_status|
      it "creates FindingTokenStatus with \"#{expected_status}\" status" do
        expect { execute }.to change { Vulnerabilities::FindingTokenStatus.count }.by(1)

        finding.reload
        expect(finding.finding_token_status).to be_present
        expect(finding.finding_token_status.status).to eq(expected_status)
      end
    end

    context 'when validity checks is disabled for the project' do
      before do
        project.security_setting.update!(validity_checks_enabled: false)
      end

      it_behaves_like 'does not create vulnerability finding token status'
    end

    context 'when validity checks is enabled for the project' do
      before do
        project.security_setting.update!(validity_checks_enabled: true)
      end

      it 'calls PartnerTokenService.process_finding_async with the findings batch' do
        expect(
          Security::SecretDetection::Vulnerabilities::PartnerTokenService
        ).to receive(:process_finding_async).once

        execute
      end

      it 'tracks number_of_tokens_processed_by_token_status_service event' do
        expect { execute }
          .to trigger_internal_events('number_of_tokens_processed_by_token_status_service')
          .with(
            project: project,
            additional_properties: {
              label: 'vulnerability',
              value: 1
            }
          )
      end

      it 'tracks secret_detection_token_verified event for each finding' do
        expect { execute }
          .to trigger_internal_events('secret_detection_token_verified')
          .with(
            project: project,
            namespace: project.namespace,
            additional_properties: {
              label: 'gitlab_personal_access_token',
              property: 'unknown'
            }
          )
      end

      context 'when there are no findings' do
        let(:empty_pipeline) { create(:ci_pipeline, :success, project: project) }

        subject(:execute) { described_class.new.execute_for_vulnerability_pipeline(empty_pipeline.id) }

        it_behaves_like 'does not create vulnerability finding token status'
      end

      context 'when finding exists with no token' do
        before do
          parsed_metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          parsed_metadata.delete('raw_source_code_extract')
          finding.update!(raw_metadata: parsed_metadata.to_json)
        end

        it_behaves_like 'does not create vulnerability finding token status'
      end

      context 'when finding exists with blank token' do
        before do
          parsed_metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          parsed_metadata['raw_source_code_extract'] = ''
          finding.update!(raw_metadata: parsed_metadata.to_json)
        end

        it_behaves_like 'does not create vulnerability finding token status'
      end

      context 'when a token is not found' do
        it_behaves_like 'creates a finding token status', 'unknown'
      end

      context 'when multiple findings have the same token' do
        let!(:second_finding) do
          create(
            :vulnerabilities_finding,
            :with_secret_detection_pat,
            pipeline: pipeline,
            token_value: token_value
          )
        end

        let!(:third_finding) do
          create(
            :vulnerabilities_finding,
            :with_secret_detection_pat,
            pipeline: pipeline,
            token_value: token_value
          )
        end

        let(:token_value) { 'same_token_value' }
        let(:token_sha) { Gitlab::CryptoHelper.sha256(token_value) }
        let(:mock_token) { instance_double(PersonalAccessToken, active?: true, token_digest: token_sha) }

        before do
          parsed_metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          parsed_metadata['raw_source_code_extract'] = token_value
          finding.update!(raw_metadata: parsed_metadata.to_json)

          allow(PersonalAccessToken)
            .to receive(:with_token_digests)
            .and_return([mock_token])
        end

        it 'creates token status for all findings with the same token' do
          expect { execute }.to change { Vulnerabilities::FindingTokenStatus.count }.by(3)
          [finding, second_finding, third_finding].each do |f|
            f.reload
            expect(f.finding_token_status.status).to eq('active')
          end
        end
      end

      context 'when upsert fails' do
        before do
          allow(Vulnerabilities::FindingTokenStatus)
            .to receive(:upsert_all)
            .and_raise(ActiveRecord::StatementInvalid.new("test exception"))
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
          allow(Gitlab::AppLogger).to receive(:error)
        end

        it 'tracks the exception and logs an error' do
          expect { execute }.to raise_error(ActiveRecord::StatementInvalid)
          expect(Gitlab::ErrorTracking).to have_received(:track_exception)
          expect(Gitlab::AppLogger).to have_received(:error)
        end
      end

      context 'when the token lookup service raises an error' do
        let(:token_lookup) { instance_double(Security::SecretDetection::TokenLookupService) }

        subject(:execute) { described_class.new(token_lookup).execute_for_vulnerability_pipeline(pipeline.id) }

        before do
          allow(token_lookup).to receive(:find).and_raise(StandardError.new("Token lookup error"))
          allow(Gitlab::AppLogger).to receive(:warn)
        end

        it 'logs a warning and does not raise' do
          expect { execute }.not_to raise_error
          expect(Gitlab::AppLogger).to have_received(:warn).with(
            hash_including(
              message: /Failed to lookup tokens for type/,
              exception: "StandardError",
              exception_message: "Token lookup error"
            )
          )
        end
      end

      context 'when token is found' do
        before do
          raw_token = token.token
          metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          metadata['raw_source_code_extract'] = raw_token
          metadata['identifiers'].first['value'] = "gitlab_personal_access_token"
          finding.update!(raw_metadata: metadata.to_json)
        end

        describe 'when a token is active' do
          let(:token) { create(:personal_access_token) }

          it_behaves_like 'creates a finding token status', 'active'

          it 'tracks secret_detection_token_verified event with active status' do
            expect { execute }
              .to trigger_internal_events('secret_detection_token_verified')
              .with(
                project: project,
                namespace: project.namespace,
                additional_properties: {
                  label: 'gitlab_personal_access_token',
                  property: 'active'
                }
              )
          end
        end

        describe 'when a token is inactive' do
          let(:token) { create(:personal_access_token, :expired) }

          it 'tracks secret_detection_token_verified event with inactive status' do
            expect { execute }
              .to trigger_internal_events('secret_detection_token_verified')
              .with(
                project: project,
                namespace: project.namespace,
                additional_properties: {
                  label: 'gitlab_personal_access_token',
                  property: 'inactive'
                }
              )
          end

          describe 'when finding has no status' do
            it_behaves_like 'creates a finding token status', 'inactive'
          end

          describe 'when finding has a status of active' do
            before do
              create(:finding_token_status, status: 'active', finding: finding)
            end

            it 'updates existing finding token status to inactive' do
              original_created_at = Vulnerabilities::FindingTokenStatus.first.created_at
              original_updated_at = Vulnerabilities::FindingTokenStatus.first.updated_at
              original_last_verified_at = Vulnerabilities::FindingTokenStatus.first.last_verified_at

              expect(Vulnerabilities::FindingTokenStatus.count).to eq(1)
              expect(finding.reload.finding_token_status.status).to eq('active')
              expect { execute }.not_to change { Vulnerabilities::FindingTokenStatus.count }
              finding.reload

              expect(finding.finding_token_status.created_at).to eq(original_created_at)
              expect(finding.finding_token_status.updated_at).to be > original_updated_at
              expect(finding.finding_token_status.last_verified_at).to be > original_last_verified_at
              expect(finding.finding_token_status.status).to eq('inactive')
            end
          end
        end
      end

      context 'when there are multiple kinds of token' do
        let(:token_test_cases) do
          [
            {
              factory: [:personal_access_token],
              identifier: 'gitlab_personal_access_token'
            },
            {
              factory: [:personal_access_token],
              identifier: 'gitlab_personal_access_token_routable'
            },
            {
              factory: [:personal_access_token],
              identifier: 'gitlab_personal_access_token_routable_versioned'
            },
            {
              factory: [:deploy_token],
              identifier: 'gitlab_deploy_token'
            },
            {
              factory: [:ci_runner],
              identifier: 'gitlab_runner_auth_token'
            },
            {
              factory: [:ci_runner, :project, { projects: [project] }],
              identifier: 'gitlab_runner_auth_token_routable'
            },
            {
              factory: [:cluster_agent_token, :with_plaintext_token],
              identifier: 'gitlab_kubernetes_agent_token'
            },
            {
              factory: [:group_scim_auth_access_token],
              identifier: 'gitlab_scim_oauth_token'
            },
            {
              factory: [:ci_build],
              identifier: 'gitlab_ci_build_token'
            },
            {
              factory: [:user],
              model_token_method: :incoming_email_token,
              identifier: 'gitlab_incoming_email_token'
            },
            {
              factory: [:user],
              model_token_method: :feed_token,
              identifier: 'gitlab_feed_token_v2'
            },
            {
              factory: [:ci_trigger, { project: project }],
              identifier: 'gitlab_pipeline_trigger_token'
            },
            {
              factory: [:oauth_application],
              identifier: 'gitlab_oauth_app_secret',
              model_token_method: 'plaintext_secret'
            }
          ]
        end

        let(:tokens_and_findings) do
          token_test_cases.map do |test_case|
            {
              token: create(*test_case[:factory]), # rubocop:disable Rails/SaveBang -- Splat operator causes false positive
              model_token_method: test_case[:model_token_method] || 'token',
              finding: create(:vulnerabilities_finding, :with_secret_detection, pipeline: pipeline),
              identifier: test_case[:identifier]
            }
          end
        end

        before do
          tokens_and_findings.each do |item|
            metadata = ::Gitlab::Json.parse(item[:finding].raw_metadata)
            metadata['raw_source_code_extract'] = item[:token].public_send(item[:model_token_method])
            metadata['identifiers'].first['value'] = item[:identifier]
            item[:finding].update!(raw_metadata: metadata.to_json)
          end
        end

        it 'updates each token with the appropriate status' do
          execute
          tokens_and_findings.each do |item|
            expect(item[:finding].reload.finding_token_status.status).to eq('active')
          end
        end
      end

      context 'when there is an unsupported secret type' do
        let_it_be_with_reload(:unsupported_secret_type_finding) do
          create(:vulnerabilities_finding, :with_secret_detection, pipeline: pipeline)
        end

        before do
          # Update finding
          metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          metadata['identifiers'].first['value'] = "unsupported_secret_type"
          unsupported_secret_type_finding.update!(raw_metadata: metadata.to_json)
        end

        it 'does not update finding status' do
          execute
          expect(unsupported_secret_type_finding.reload.finding_token_status).to be_nil
        end
      end

      context 'when finding metadata does not include secret type' do
        let_it_be_with_reload(:unsupported_secret_type_finding) do
          create(:vulnerabilities_finding, :with_secret_detection, pipeline: pipeline)
        end

        context 'when gitleaks_rule_id is missing' do
          before do
            # Update finding
            metadata = ::Gitlab::Json.parse(finding.raw_metadata)
            metadata['identifiers'].first.delete('type')
            unsupported_secret_type_finding.update!(raw_metadata: metadata.to_json)
          end

          it 'does not update finding status' do
            execute
            expect(unsupported_secret_type_finding.reload.finding_token_status).to be_nil
          end
        end

        context 'when gitleaks_rule_id is missing the value attribute' do
          before do
            metadata = ::Gitlab::Json.parse(finding.raw_metadata)
            metadata['identifiers'].first.delete('value')
            unsupported_secret_type_finding.update!(raw_metadata: metadata.to_json)
          end

          it 'does not update finding status' do
            execute
            expect(unsupported_secret_type_finding.reload.finding_token_status).to be_nil
          end
        end
      end

      context 'when processing multiple findings' do
        let_it_be_with_reload(:many_findings) do
          create_list(:vulnerabilities_finding, 5, :with_secret_detection, pipeline: pipeline)
        end

        before do
          many_findings.each_with_index do |finding, index|
            metadata = ::Gitlab::Json.parse(finding.raw_metadata)
            metadata['raw_source_code_extract'] = "glpat-0000000000000000000#{index}"
            metadata['identifiers'].first['value'] = "gitlab_personal_access_token"
            finding.update!(raw_metadata: metadata.to_json)
          end
        end

        it 'processes all findings in batches' do
          expect { execute }.to change {
            Vulnerabilities::FindingTokenStatus.count
          }.by(6)
        end

        it 'processes findings in batches' do
          stub_const("#{described_class}::DEFAULT_BATCH_SIZE", 1)
          expect_next_instance_of(described_class) do |instance|
            expect(instance).to receive(:process_findings_batch)
              .exactly(many_findings.size + 1).times
              .and_call_original
          end

          execute
        end

        it 'calls process_finding_async for each batch' do
          stub_const("#{described_class}::DEFAULT_BATCH_SIZE", 2)

          expect(Security::SecretDetection::Vulnerabilities::PartnerTokenService).to receive(:process_finding_async)
            .exactly(3).times

          execute
        end

        it 'does not perform N+1 queries' do
          # Set a batch size that ensures all findings are processed in a single batch
          stub_const("#{described_class}::DEFAULT_BATCH_SIZE", 20)
          findings = create_list(:vulnerabilities_finding, 3, :with_secret_detection, pipeline: pipeline)

          findings.each do |finding|
            metadata = ::Gitlab::Json.parse(finding.raw_metadata)
            metadata['identifiers'].first['value'] = 'gitlab_personal_access_token'
            finding.update!(raw_metadata: metadata.to_json)
            finding.clear_memoization(:metadata)
          end
          # Count queries when processing all findings
          query_count = ActiveRecord::QueryRecorder.new do
            execute
          end.count

          # We expect exactly 10 queries:
          # 1. Query to fetch the pipeline
          # 2. Query to fetch the project
          # 3. Query to fetch security_setting
          # 4. Batch start boundary query (find first record)
          # 5. Batch end boundary query (check for more records)
          # 6. Query to check if findings batch is empty
          # 7. Query to fetch all findings in the batch
          # 8. Query to fetch tokens
          # 9. Query to insert/update statuses
          # 10. Query to fetch the namespace (for the secret_detection_token_verified event)
          expect(query_count).to eq(10)
        end
      end

      context 'when process_findings_batch receives invalid finding type' do
        it 'raises ArgumentError for unknown finding type' do
          service = described_class.new

          allow(service).to receive(:process_findings_batch)
            .and_wrap_original do |original_method, findings, _finding_type|
            original_method.call(findings, :invalid_type)
          end

          allow(service).to receive_messages(build_token_status_attributes_by_raw_token: { 'glpat-test' => [{
            project_id: project.id,
            vulnerability_occurrence_id: finding.id,
            status: 'unknown',
            created_at: Time.current,
            updated_at: Time.current,
            last_verified_at: Time.current
          }] }, get_tokens_by_raw_token_value: {})

          expect { service.execute_for_vulnerability_pipeline(pipeline.id) }
            .to raise_error(ArgumentError, 'Unknown finding type: invalid_type')
        end
      end
    end

    context 'when elasticsearch synchronization' do
      before do
        project.security_setting.update!(validity_checks_enabled: true)
      end

      it_behaves_like 'it syncs vulnerabilities with ES', -> { [finding.vulnerability_id] }

      context 'when no findings exist' do
        let(:empty_pipeline) { create(:ci_pipeline, project: project) }

        subject(:execute) { described_class.new.execute_for_vulnerability_pipeline(empty_pipeline.id) }

        it_behaves_like 'does not sync with ES when no vulnerabilities'
      end
    end
  end

  describe '#execute_for_vulnerability_finding' do
    subject(:execute) { described_class.new.execute_for_vulnerability_finding(finding.id) }

    shared_examples 'creates a finding token status for single finding' do |expected_status|
      it "creates FindingTokenStatus with \"#{expected_status}\" status" do
        expect { execute }.to change { Vulnerabilities::FindingTokenStatus.count }.by(1)

        finding.reload
        expect(finding.finding_token_status).to be_present
        expect(finding.finding_token_status.status).to eq(expected_status)
      end
    end

    context 'when finding does not exist' do
      subject(:execute) { described_class.new.execute_for_vulnerability_finding(non_existing_record_id) }

      it_behaves_like 'does not create vulnerability finding token status'
    end

    context 'when validity checks is disabled for the project' do
      before do
        project.security_setting.update!(validity_checks_enabled: false)
      end

      it_behaves_like 'does not create vulnerability finding token status'
    end

    context 'when validity checks is enabled for the project' do
      before do
        project.security_setting.update!(validity_checks_enabled: true)
      end

      it 'calls PartnerTokenService.process_partner_finding with the findings batch' do
        expect(
          Security::SecretDetection::Vulnerabilities::PartnerTokenService
        ).to receive(:process_partner_finding).once

        execute
      end

      context 'when finding exists with no token' do
        before do
          parsed_metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          parsed_metadata.delete('raw_source_code_extract')
          finding.update!(raw_metadata: parsed_metadata.to_json)
        end

        it_behaves_like 'does not create vulnerability finding token status'
      end

      context 'when finding exists with blank token' do
        before do
          parsed_metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          parsed_metadata['raw_source_code_extract'] = ''
          finding.update!(raw_metadata: parsed_metadata.to_json)
        end

        it_behaves_like 'does not create vulnerability finding token status'
      end

      context 'when a token is not found' do
        it_behaves_like 'creates a finding token status for single finding', 'unknown'
      end

      context 'when token is found' do
        before do
          raw_token = token.token
          metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          metadata['raw_source_code_extract'] = raw_token
          metadata['identifiers'].first['value'] = "gitlab_personal_access_token"
          finding.update!(raw_metadata: metadata.to_json)
        end

        describe 'when a token is active' do
          let(:token) { create(:personal_access_token) }

          it_behaves_like 'creates a finding token status for single finding', 'active'
        end

        describe 'when a token is inactive' do
          let(:token) { create(:personal_access_token, :expired) }

          describe 'when finding has no status' do
            it_behaves_like 'creates a finding token status for single finding', 'inactive'
          end

          describe 'when finding has a status of active' do
            before do
              create(:finding_token_status, status: 'active', finding: finding)
            end

            it 'updates existing finding token status to inactive' do
              original_created_at = Vulnerabilities::FindingTokenStatus.first.created_at
              original_updated_at = Vulnerabilities::FindingTokenStatus.first.updated_at
              original_last_verified_at = Vulnerabilities::FindingTokenStatus.first.last_verified_at

              expect(Vulnerabilities::FindingTokenStatus.count).to eq(1)
              expect(finding.reload.finding_token_status.status).to eq('active')
              expect { execute }.not_to change { Vulnerabilities::FindingTokenStatus.count }
              finding.reload

              expect(finding.finding_token_status.created_at).to eq(original_created_at)
              expect(finding.finding_token_status.updated_at).to be > original_updated_at
              expect(finding.finding_token_status.last_verified_at).to be > original_last_verified_at
              expect(finding.finding_token_status.status).to eq('inactive')
            end
          end
        end
      end

      context 'when the token lookup service raises an error' do
        let(:token_lookup) { instance_double(Security::SecretDetection::TokenLookupService) }

        subject(:execute) { described_class.new(token_lookup).execute_for_vulnerability_finding(finding.id) }

        before do
          allow(token_lookup).to receive(:find).and_raise(StandardError.new("Token lookup error"))
          allow(Gitlab::AppLogger).to receive(:warn)
        end

        it 'logs a warning and does not raise' do
          expect { execute }.not_to raise_error
          expect(Gitlab::AppLogger).to have_received(:warn).with(
            hash_including(
              message: /Failed to lookup tokens for type/,
              exception: "StandardError",
              exception_message: "Token lookup error"
            )
          )
        end
      end

      context 'when upsert fails' do
        before do
          allow(Vulnerabilities::FindingTokenStatus)
            .to receive(:upsert_all)
            .and_raise(ActiveRecord::StatementInvalid.new("test exception"))
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
          allow(Gitlab::AppLogger).to receive(:error)
        end

        it 'tracks the exception and logs an error' do
          expect { execute }.to raise_error(ActiveRecord::StatementInvalid)
          expect(Gitlab::ErrorTracking).to have_received(:track_exception)
          expect(Gitlab::AppLogger).to have_received(:error)
        end
      end

      context 'when there is an unsupported secret type' do
        before do
          metadata = ::Gitlab::Json.parse(finding.raw_metadata)
          metadata['identifiers'].first['value'] = "unsupported_secret_type"
          finding.update!(raw_metadata: metadata.to_json)
        end

        it 'does not update finding status' do
          execute
          expect(finding.reload.finding_token_status).to be_nil
        end
      end

      context 'when processing a single finding uses batching' do
        it 'processes the finding using the batch mechanism' do
          expect_next_instance_of(described_class) do |instance|
            expect(instance).to receive(:process_findings_batch).once.and_call_original
          end

          execute
        end
      end
    end
  end

  describe '#execute_for_security_pipeline' do
    let_it_be_with_reload(:build) { create(:ci_build, pipeline: pipeline) }

    let_it_be_with_reload(:security_scan) do
      create(:security_scan, project: project, pipeline: pipeline, build: build, scan_type: :secret_detection)
    end

    let_it_be_with_reload(:security_finding) do
      create(:security_finding,
        scan: security_scan,
        uuid: SecureRandom.uuid,
        finding_data: {
          'name' => 'GitLab personal access token',
          'identifiers' => [
            {
              'external_type' => 'gitleaks_rule_id',
              'external_id' => 'gitlab_personal_access_token',
              'name' => 'Gitleaks rule ID gitlab_personal_access_token'
            }
          ],
          'raw_source_code_extract' => 'glpat-test_token_value'
        }
      )
    end

    subject(:execute) { described_class.new.execute_for_security_pipeline(pipeline.id) }

    context 'when validity checks are disabled for the project' do
      before do
        project.security_setting.update!(validity_checks_enabled: false)
      end

      it_behaves_like 'does not create security finding token status'
    end

    context 'when validity checks is enabled for the project' do
      before do
        project.security_setting.update!(validity_checks_enabled: true)
      end

      it 'calls PartnerTokenService.process_finding_async with the findings batch' do
        expect(
          Security::SecretDetection::Security::PartnerTokenService
        ).to receive(:process_finding_async).once

        execute
      end

      it 'tracks number_of_tokens_processed_by_token_status_service event' do
        expect { execute }
          .to trigger_internal_events('number_of_tokens_processed_by_token_status_service')
          .with(
            project: project,
            additional_properties: {
              label: 'security',
              value: 1
            }
          )
      end

      it 'creates security finding token status' do
        expect { execute }.to change { Security::FindingTokenStatus.count }.by(1)

        security_finding.reload
        expect(security_finding.token_status).to be_present
        expect(security_finding.token_status.status).to eq('unknown')
      end
    end
  end

  describe '#execute_for_security_finding' do
    let_it_be_with_reload(:security_scan) do
      create(:security_scan, project: project, pipeline: pipeline, scan_type: :secret_detection)
    end

    let_it_be_with_reload(:security_finding) do
      create(:security_finding, scan: security_scan, finding_data: {
        'name' => 'GitLab personal access token',
        'identifiers' => [
          {
            'external_type' => 'gitleaks_rule_id',
            'external_id' => 'gitlab_personal_access_token',
            'name' => 'Gitleaks rule ID gitlab_personal_access_token'
          }
        ],
        'raw_source_code_extract' => 'glpat-test_token_value'
      })
    end

    subject(:execute) { described_class.new.execute_for_security_finding(security_finding.id) }

    it 'calls PartnerTokenService.process_partner_finding with the findings batch' do
      expect(
        Security::SecretDetection::Security::PartnerTokenService
      ).to receive(:process_partner_finding).once

      execute
    end

    context 'when validity checks is disabled for the project' do
      before do
        project.security_setting.update!(validity_checks_enabled: false)
      end

      it_behaves_like 'does not create security finding token status'

      context 'when validity checks is enabled for the project' do
        before do
          project.security_setting.update!(validity_checks_enabled: true)
        end

        context 'when security finding has no raw_source_code_extract' do
          let_it_be_with_reload(:finding_without_extract) do
            create(:security_finding,
              scan: security_scan,
              uuid: SecureRandom.uuid,
              finding_data: {
                'name' => 'GitLab personal access token',
                'identifiers' => [
                  {
                    'external_type' => 'gitleaks_rule_id',
                    'external_id' => 'gitlab_personal_access_token',
                    'name' => 'Gitleaks rule ID gitlab_personal_access_token'
                  }
                ]
              }
            )
          end

          subject(:execute) { described_class.new.execute_for_security_finding(finding_without_extract.id) }

          it 'skips the finding and does not create token status' do
            expect { execute }.not_to change { Security::FindingTokenStatus.count }

            expect(finding_without_extract.reload.token_status).to be_nil
          end
        end

        context 'when security finding has no gitleaks_rule_id identifier' do
          let_it_be_with_reload(:finding_without_identifier) do
            create(:security_finding,
              scan: security_scan,
              uuid: SecureRandom.uuid,
              finding_data: {
                'name' => 'Some other finding',
                'identifiers' => [
                  {
                    'external_type' => 'other_type',
                    'external_id' => 'other_id',
                    'name' => 'Other identifier'
                  }
                ],
                'raw_source_code_extract' => 'some-value'
              }
            )
          end

          subject(:execute) { described_class.new.execute_for_security_finding(finding_without_identifier.id) }

          it 'skips the finding and does not create token status' do
            expect { execute }.not_to change { Security::FindingTokenStatus.count }

            expect(finding_without_identifier.reload.token_status).to be_nil
          end
        end

        it 'creates security finding token status' do
          expect { execute }.to change { Security::FindingTokenStatus.count }.by(1)

          security_finding.reload
          expect(security_finding.token_status).to be_present
          expect(security_finding.token_status.status).to eq('unknown')
        end

        context 'when multiple security findings have same UUID' do
          let_it_be_with_reload(:another_scan) do
            create(:security_scan, project: project, pipeline: pipeline, scan_type: :secret_detection)
          end

          let_it_be_with_reload(:second_security_finding) do
            create(:security_finding,
              scan: another_scan,
              uuid: security_finding.uuid,
              finding_data: {
                'name' => 'GitLab personal access token',
                'identifiers' => [
                  {
                    'external_type' => 'gitleaks_rule_id',
                    'external_id' => 'gitlab_personal_access_token',
                    'name' => 'Gitleaks rule ID gitlab_personal_access_token'
                  }
                ],
                'raw_source_code_extract' => 'glpat-test_token_value'
              }
            )
          end

          it 'processes all findings with the same UUID' do
            expect { execute }.to change { Security::FindingTokenStatus.count }.by(2)

            [security_finding, second_security_finding].each do |finding|
              finding.reload
              expect(finding.token_status).to be_present
            end
          end
        end

        context 'when security finding has an associated vulnerability finding' do
          let_it_be_with_reload(:vulnerability) { create(:vulnerability, project: project) }
          let_it_be_with_reload(:vulnerability_finding) do
            create(:vulnerabilities_finding,
              vulnerability: vulnerability,
              uuid: security_finding.uuid,
              project: project,
              raw_metadata: {
                'name' => 'GitLab personal access token',
                'identifiers' => [
                  {
                    'type' => 'gitleaks_rule_id',
                    'value' => 'gitlab_personal_access_token',
                    'name' => 'Gitleaks rule ID gitlab_personal_access_token'
                  }
                ],
                'raw_source_code_extract' => 'glpat-test_token_value'
              }.to_json
            )
          end

          before do
            security_finding.update!(vulnerability_finding: vulnerability_finding)
          end

          it 'creates token status for both security finding and vulnerability finding' do
            expect { execute }.to change { Security::FindingTokenStatus.count }.by(1)
                            .and change { Vulnerabilities::FindingTokenStatus.count }.by(1)

            security_finding.reload
            vulnerability_finding.reload

            expect(security_finding.token_status).to be_present
            expect(security_finding.token_status.status).to eq('unknown')

            expect(vulnerability_finding.finding_token_status).to be_present
            expect(vulnerability_finding.finding_token_status.status).to eq('unknown')
          end

          context 'when token is found and active' do
            let_it_be_with_reload(:pat_token) { create(:personal_access_token) }

            before do
              security_finding.update!(
                finding_data: security_finding.finding_data.merge(
                  'raw_source_code_extract' => pat_token.token
                )
              )
              vulnerability_finding.update!(
                raw_metadata: ::Gitlab::Json.parse(vulnerability_finding.raw_metadata).merge(
                  'raw_source_code_extract' => pat_token.token
                ).to_json
              )
            end

            it 'marks both findings as active' do
              execute

              security_finding.reload
              vulnerability_finding.reload

              expect(security_finding.token_status.status).to eq('active')
              expect(vulnerability_finding.finding_token_status.status).to eq('active')
            end
          end
        end
      end
    end
  end
end
