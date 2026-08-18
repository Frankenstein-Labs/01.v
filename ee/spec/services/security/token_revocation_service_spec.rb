# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::TokenRevocationService, '#execute', feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project) }

  let(:revocation_token_types_url) { 'https://myhost.com/api/v1/token_types' }
  let(:token_revocation_url) { 'https://myhost.com/api/v1/revoke' }
  let(:revocable_keys) do
    [{
      type: 'aws_key_id',
      token: 'AKIASOMEAWSACCESSKEY',
      location: 'https://mywebsite.com/some-repo/blob/abcdefghijklmnop/compromisedfile.java'
    },
      {
        type: 'aws_secret',
        token: 'some_aws_secret_key_some_aws_secret_key_',
        location: 'https://mywebsite.com/some-repo/blob/abcdefghijklmnop/compromisedfile.java'
      },
      {
        type: 'aws_secret',
        token: 'another_aws_secret_key_another_secret_key',
        location: 'https://mywebsite.com/some-repo/blob/abcdefghijklmnop/compromisedfile.java'
      }]
  end

  let(:revocable_external_token_types) do
    { types: %w[aws_key_id aws_secret gcp_key_id gcp_secret] }
  end

  subject(:token_revocation_service) { described_class.new(revocable_keys:, project:).execute }

  before do
    stub_application_setting(secret_detection_revocation_token_types_url: revocation_token_types_url)
    stub_application_setting(secret_detection_token_revocation_token: 'token1')
    stub_application_setting(secret_detection_token_revocation_url: token_revocation_url)
  end

  context 'when revoking a glpat token' do
    let_it_be_with_reload(:glpat_token) { create(:personal_access_token) }
    let_it_be_with_reload(:vulnerability) { create(:vulnerability, project: project) }

    let(:revocable_keys) do
      [
        {
          type: 'gitleaks_rule_id_gitlab_personal_access_token',
          token: glpat_token.token,
          location: 'https://example.com/some-repo/blob/abcdefghijklmnop/compromisedfile1.java#L21',
          vulnerability: vulnerability
        },
        {
          type: 'gitleaks_rule_id_gitlab_personal_access_token',
          token: glpat_token.token,
          location: 'https://example.com/some-repo/blob/abcdefghijklmnop/compromisedfile1.java#L41',
          vulnerability: vulnerability
        }
      ]
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'revoke_leaked_token_after_vulnerability_report_is_ingested' }
      let(:category) { described_class.name }
      let(:additional_properties) { { label: 'gitleaks_rule_id_gitlab_personal_access_token' } }
    end

    it 'returns success' do
      expect(PersonalAccessTokens::RevokeService).to receive(:new).once.and_call_original

      audit_context = {
        name: 'personal_access_token_revoked',
        author: Users::Internal.in_organization(project.organization).security_bot,
        scope: Users::Internal.in_organization(project.organization).security_bot,
        target: glpat_token.user,
        message: "Revoked personal access token with id #{glpat_token.id}",
        additional_details: {
          revocation_source: :secret_detection
        }
      }

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original

      expect(SystemNoteService)
        .to receive(:change_vulnerability_state)
        .with(
          vulnerability,
          Users::Internal.in_organization(project.organization).security_bot,
          s_("TokenRevocation|This personal access token has been automatically revoked on detection. " \
             "Consider investigating and rotating before marking this vulnerability as resolved.")
        )

      expect(subject[:status]).to be(:success)
    end

    context 'when PersonalAccessTokens::RevokeService returns error' do
      before do
        allow_next_instance_of(PersonalAccessTokens::RevokeService) do |service|
          allow(service).to receive(:execute).and_return({ status: :error, message: 'Failed to revoke token' })
        end
      end

      it 'fires internal tracking events' do
        expect { subject }.to trigger_internal_events(
          'leaked_token_unable_to_be_revoked_after_vulnerability_report_is_ingested'
        ).with(
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: 'gitleaks_rule_id_gitlab_personal_access_token',
            property: described_class::ERROR
          }
        ).and increment_usage_metrics(
          'counts.count_total_leaked_tokens_unable_to_be_revoked_due_to_error'
        )
      end
    end

    context 'when vulnerability is missing' do
      before do
        revocable_keys.each do |key|
          key.delete(:vulnerability)
        end
      end

      it 'does not call `SystemNoteService`' do
        expect(SystemNoteService).not_to receive(:change_vulnerability_state)

        subject
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'revoke_leaked_token_after_vulnerability_report_is_ingested' }
        let(:category) { described_class.name }
        let(:additional_properties) { { label: 'gitleaks_rule_id_gitlab_personal_access_token' } }
      end
    end
  end

  context 'when revocation token API returns a response with failure' do
    before do
      stub_application_setting(secret_detection_token_revocation_enabled: true)
      stub_revoke_token_api_with_failure
      stub_revocation_token_types_api_with_success
    end

    it 'returns error' do
      expect(subject[:status]).to be(:error)
      expect(subject[:message]).to eql('Failed to revoke tokens')
    end

    it 'calls log_unable_to_revoke_token with COMM_FAILURE reason for each key' do
      expect { subject }.to trigger_internal_events(
        'leaked_token_unable_to_be_revoked_after_vulnerability_report_is_ingested'
      ).with(
        project: project,
        namespace: project.namespace,
        additional_properties: {
          label: 'aws_key_id',
          property: described_class::COMM_FAILURE
        }
      ).and trigger_internal_events(
        'leaked_token_unable_to_be_revoked_after_vulnerability_report_is_ingested'
      ).with(
        project: project,
        namespace: project.namespace,
        additional_properties: {
          label: 'aws_secret',
          property: described_class::COMM_FAILURE
        }
      ).twice
      .and increment_usage_metrics(
        'counts.count_total_leaked_tokens_unable_to_be_automatically_revoked_due_to_srs_communication_failure'
      ).by(3)
    end

    it 'does not create internal tracking events' do
      expect { subject }.not_to trigger_internal_events('revoke_leaked_token_after_vulnerability_report_is_ingested')
    end
  end

  context 'when revocation token types API returns empty list of types' do
    before do
      stub_application_setting(secret_detection_token_revocation_enabled: true)
      stub_invalid_token_types_api_with_success
    end

    specify { expect(subject).to eql({ status: :success }) }

    context 'with multiple token types in revocable keys' do
      let(:custom_revocable_keys) do
        [
          { type: 'aws_key_id', token: 'aws1', location: 'example.com/1' },
          { type: 'aws_secret', token: 'aws2', location: 'example.com/2' },
          { type: 'gcp_key_id', token: 'gcp1', location: 'example.com/3' }
        ]
      end

      it 'tracks unsupported keys' do
        expect do
          described_class.new(revocable_keys: custom_revocable_keys, project: project).execute
        end.to trigger_internal_events(
          'leaked_token_unable_to_be_revoked_after_vulnerability_report_is_ingested'
        ).with(
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: 'aws_key_id',
            property: described_class::UNSUPPORTED
          }
        ).and trigger_internal_events(
          'leaked_token_unable_to_be_revoked_after_vulnerability_report_is_ingested'
        ).with(
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: 'aws_secret',
            property: described_class::UNSUPPORTED
          }
        ).and trigger_internal_events(
          'leaked_token_unable_to_be_revoked_after_vulnerability_report_is_ingested'
        ).with(
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: 'gcp_key_id',
            property: described_class::UNSUPPORTED
          }
        ).and increment_usage_metrics(
          'counts.count_total_leaked_tokens_unable_to_be_revoked_due_to_being_unsupported'
        ).by(3)
      end
    end
  end

  context 'when external revocation service is disabled' do
    specify { expect(subject).to eql({ status: :success }) }
  end

  context 'when external revocation service is enabled' do
    before do
      stub_application_setting(secret_detection_token_revocation_enabled: true)
      stub_revoke_token_api_with_success
    end

    context 'when some token types are not supported' do
      before do
        stub_revocation_token_types_api_with_success
      end

      let(:revocable_keys) do
        [
          {
            type: 'unsupported_token_type',
            token: 'some_unsupported_token',
            location: 'https://mywebsite.com/some-repo/blob/abcdefghijklmnop/compromisedfile.java'
          },
          {
            type: 'aws_key_id',
            token: 'AKIASOMEAWSACCESSKEY', # gitleaks:allow
            location: 'https://mywebsite.com/some-repo/blob/abcdefghijklmnop/compromisedfile.java'
          }
        ]
      end

      # rubocop:disable Layout/LineLength -- metric names are very long
      it 'tracks internal events for both the supported and unsupported token types' do
        stub_revoke_token_api_with_success([revocable_keys.last])

        expect { subject }.to trigger_internal_events('revoke_leaked_token_after_vulnerability_report_is_ingested')
          .with(project: project, namespace: project.namespace, additional_properties: { label: 'aws_key_id' })
          .and trigger_internal_events('leaked_token_unable_to_be_revoked_after_vulnerability_report_is_ingested').with(
            project: project, namespace: project.namespace, additional_properties: {
              label: 'unsupported_token_type', property: described_class::UNSUPPORTED
            }
          ).and increment_usage_metrics(
            'counts.count_total_leaked_tokens_unable_to_be_revoked_due_to_being_unsupported',
            'redis_hll_counters.count_distinct_label_from_revoke_leaked_token_after_vulnerability_report_is_ingested_monthly',
            'redis_hll_counters.count_distinct_label_from_revoke_leaked_token_after_vulnerability_report_is_ingested_weekly'
          )
      end
      # rubocop:enable Layout/LineLength
    end

    context 'with a list of valid token types' do
      before do
        stub_revocation_token_types_api_with_success
      end

      context 'when no token types match the revocable keys' do
        let(:revocable_keys) do
          [{ type: 'unsupported_type', token: 'foo', location: 'https://example.com' }]
        end

        let(:revocable_external_token_types) { { types: %w[aws_key_id] } }

        it 'returns success' do
          expect(subject[:status]).to be(:success)
        end
      end

      context 'when there is a list of tokens to be revoked' do
        describe 'status is success' do
          specify { expect(described_class.new(revocable_keys:, project:).execute[:status]).to be(:success) }
        end

        # rubocop:disable Layout/LineLength -- metric names are very long
        it 'creates internal tracking event', :clean_gitlab_redis_shared_state do
          expect { described_class.new(revocable_keys:, project:).execute }.to trigger_internal_events(
            'revoke_leaked_token_after_vulnerability_report_is_ingested').with(
              project: project, namespace: project.namespace, additional_properties: { label: 'aws_key_id' }
            ).and trigger_internal_events('revoke_leaked_token_after_vulnerability_report_is_ingested').with(
              project: project, namespace: project.namespace, additional_properties: { label: 'aws_secret' }
            ).twice.and increment_usage_metrics(
              'redis_hll_counters.count_distinct_namespace_id_from_revoke_leaked_token_after_vulnerability_report_is_ingested_monthly',
              'redis_hll_counters.count_distinct_project_id_from_revoke_leaked_token_after_vulnerability_report_is_ingested_monthly',
              'redis_hll_counters.count_distinct_namespace_id_from_revoke_leaked_token_after_vulnerability_report_is_ingested_weekly',
              'redis_hll_counters.count_distinct_project_id_from_revoke_leaked_token_after_vulnerability_report_is_ingested_weekly'
            ).by(1).and increment_usage_metrics(
              'redis_hll_counters.count_distinct_label_from_revoke_leaked_token_after_vulnerability_report_is_ingested_monthly',
              'redis_hll_counters.count_distinct_label_from_revoke_leaked_token_after_vulnerability_report_is_ingested_weekly'
            ).by(2)
        end
        # rubocop:enable Layout/LineLength
      end

      context 'when token_revocation_url is missing' do
        before do
          allow_next_instance_of(described_class) do |token_revocation_service|
            allow(token_revocation_service).to receive(:token_revocation_url).and_return(nil)
          end
        end

        specify { expect(subject).to eql({ message: 'Missing revocation token data', status: :error }) }

        it 'does not call log_unable_to_revoke_token when token data is missing' do
          service = described_class.new(revocable_keys:, project:)

          # log_unable_to_revoke_token shouldn't be called when missing token data
          expect(service).not_to receive(:log_unable_to_revoke_token)

          service.execute
        end

        it 'does not create internal tracking events' do
          expect { subject }.not_to trigger_internal_events(
            'revoke_leaked_token_after_vulnerability_report_is_ingested'
          )
        end
      end

      context 'when token_types_url is missing' do
        before do
          allow_next_instance_of(described_class) do |token_revocation_service|
            allow(token_revocation_service).to receive(:token_types_url).and_return(nil)
          end
        end

        specify { expect(subject).to eql({ message: 'Missing revocation token data', status: :error }) }

        it 'does not create internal tracking events' do
          expect { subject }.not_to trigger_internal_events(
            'revoke_leaked_token_after_vulnerability_report_is_ingested'
          )
        end
      end

      context 'when revocation_api_token is missing' do
        before do
          allow_next_instance_of(described_class) do |token_revocation_service|
            allow(token_revocation_service).to receive(:revocation_api_token).and_return(nil)
          end
        end

        specify { expect(subject).to eql({ message: 'Missing revocation token data', status: :error }) }

        it 'does not create internal tracking events' do
          expect { subject }.not_to trigger_internal_events(
            'revoke_leaked_token_after_vulnerability_report_is_ingested'
          )
        end
      end

      context 'when there is no token to be revoked' do
        let(:revocable_external_token_types) do
          { types: %w[] }
        end

        specify { expect(subject).to eql({ status: :success }) }

        it 'does not create internal tracking events' do
          expect { subject }.not_to trigger_internal_events(
            'revoke_leaked_token_after_vulnerability_report_is_ingested'
          )
        end
      end
    end

    context 'when revocation token types API returns an unsuccessful response' do
      before do
        stub_revocation_token_types_api_with_failure
      end

      specify { expect(subject).to eql({ message: 'Failed to get revocation token types', status: :error }) }

      it 'raises RevocationFailedError without calling log_unable_to_revoke_token' do
        service = described_class.new(revocable_keys:, project:)

        # log_unable_to_revoke_token shouldn't be called in this case
        # as the error happens before we process token types
        expect(service).not_to receive(:log_unable_to_revoke_token)

        service.execute
      end

      it 'does not create internal tracking events' do
        expect { subject }.not_to trigger_internal_events(
          'revoke_leaked_token_after_vulnerability_report_is_ingested'
        )
      end
    end
  end

  def stub_revoke_token_api_with_success(keys = revocable_keys)
    stub_request(:post, token_revocation_url)
      .with(body: keys.to_json)
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {}.to_json
      )
  end

  def stub_revoke_token_api_with_failure
    stub_request(:post, token_revocation_url)
      .with(body: revocable_keys.to_json)
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {}.to_json
      )
  end

  def stub_revocation_token_types_api_with_success
    stub_request(:get, revocation_token_types_url)
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: revocable_external_token_types.to_json
      )
  end

  def stub_invalid_token_types_api_with_success
    stub_request(:get, revocation_token_types_url)
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {}.to_json
      )
  end

  def stub_revocation_token_types_api_with_failure
    stub_request(:get, revocation_token_types_url)
      .to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {}.to_json
      )
  end
end
