# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::AmazonQ::EndToEndProbe, feature_category: :duo_setting do
  let_it_be(:organization) { create(:organization) }
  let_it_be_with_reload(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:oauth_app) { create(:doorkeeper_application) }

  let(:probe) { described_class.new(user) }

  describe '#execute' do
    let(:status) { 200 }
    let(:body) { {}.to_json }

    before do
      ::Ai::Setting.for_organization(organization).update!(
        amazon_q_role_arn: 'role-arn',
        amazon_q_service_account_user_id: service_account.id,
        amazon_q_oauth_application_id: oauth_app.id
      )

      allow(Doorkeeper::OAuth::Helpers::UniqueToken).to receive(:generate).and_return('1234')
      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application/verify")
        .with(body: {
          role_arn: 'role-arn',
          code: '1234'
        }.to_json).to_return(body: body, status: status, headers: { 'Content-Type' => "application/json" })
    end

    context 'when the user is provided and an unknown error occurs' do
      let(:status) { 403 }
      let(:body) { nil }

      it 'returns a failure result with a connectivity check failed unknown error message' do
        result = probe.execute

        expect(result.first.success).to be false
        expect(result.first.message).to match("Amazon Q connectivity check failed: Unknown error")
      end
    end

    context 'when the user is not provided' do
      let(:user) { nil }

      it 'returns a failure result with a user not provided message' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.errors.full_messages).to include('User not provided')
      end
    end

    context 'when the user is provided and the connectivity check fails' do
      let(:status) { 403 }
      let(:body) { { 'detail' => 'API error' }.to_json }

      it 'returns a failure result with the connectivity check failed message' do
        result = probe.execute

        expect(result.first.success).to be false
        expect(result.first.message).to match("Amazon Q connectivity check failed: API error")
      end
    end

    context 'when the credential check fails and the connectivity check succeeds' do
      let(:status) { 200 }
      let(:body) do
        {
          'GITLAB_INSTANCE_REACHABILITY' => { 'status' => 'PASSED' },
          'GITLAB_CREDENTIAL_VALIDITY' => { 'status' => 'FAILED', 'message' => 'Invalid credentials' },
          'GITLAB_OTHER_STATUS' => { 'status' => 'INCOMPLETE' }
        }.to_json
      end

      it 'returns a success result for the passed check' do
        result = probe.execute

        expect(result.length).to eq(2)
        expect(result.first.success).to be true
        expect(result.first.message).to match(
          'Amazon Q successfully received the callback request from your GitLab instance.'
        )
        expect(result.second.success).to be false
        expect(result.second.message).to match(
          'The GitLab instance can be reached but the credentials stored in Amazon Q are not valid. ' \
            'Please disconnect and start over.'
        )
      end
    end

    context 'when the credential check succeeds and the connectivity check fails' do
      let(:status) { 200 }
      let(:body) do
        {
          'GITLAB_INSTANCE_REACHABILITY' => { 'status' => 'FAILED', 'message' => 'unreachable' },
          'GITLAB_CREDENTIAL_VALIDITY' => { 'status' => 'PASSED' },
          'GITLAB_OTHER_STATUS' => { 'status' => 'INCOMPLETE' }
        }.to_json
      end

      it 'returns a success result for the passed check' do
        result = probe.execute

        expect(result.length).to eq(2)
        expect(result.first.success).to be false
        expect(result.first.message).to match('Amazon Q could not call your GitLab instance. ' \
          'Please review your configuration and try again. Detail: unreachable')
        expect(result.second.success).to be true
        expect(result.second.message).to match(
          'Credentials stored in Amazon Q are valid and functioning correctly.'
        )
      end
    end
  end
end
