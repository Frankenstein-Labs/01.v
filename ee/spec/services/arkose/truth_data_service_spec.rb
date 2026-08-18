# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::TruthDataService, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let(:session_token) { '22612c147bb418c8.2570749403' }
  let(:is_legit) { false }
  let(:service) { described_class.new(user: user, is_legit: is_legit) }
  let(:arkose_risk_band) { 'Low' }
  let(:client_api_status_code) { 200 }

  def add_arkose_custom_attributes
    create(:user_custom_attribute, key: UserCustomAttribute::ARKOSE_SESSION, value: session_token, user: user)
    create(:user_custom_attribute, key: UserCustomAttribute::ARKOSE_RISK_BAND, value: arkose_risk_band, user: user)
  end

  before do
    stub_request(:post, Arkose::TruthDataService::TRUTH_DATA_API_ENDPOINT)
      .with(
        body: /.*/,
        headers: {
          'Accept' => '*/*'
        }
      ).to_return(
        status: client_api_status_code,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    before do
      allow(Arkose::TruthDataAuthorizationService).to receive(:execute).and_return(ServiceResponse.success(payload: {
        token: 'token'
      }))
    end

    shared_examples 'short circuits the API request' do
      let(:log_message) { 'truth data is not applicable for user' }
      let(:result) { 'success' }

      it { is_expected.to be_success }

      it 'does not send API requests' do
        execute

        expect(WebMock).not_to have_requested(:post, Arkose::TruthDataService::TRUTH_DATA_API_ENDPOINT)
      end

      it_behaves_like('logs the outcome')
    end

    shared_examples 'successful API request' do
      let(:log_message) { 'sent arkose truth data' }
      let(:result) { 'success' }

      it { is_expected.to be_success }

      it 'sends the API request' do
        execute

        expect(WebMock).to have_requested(:post, Arkose::TruthDataService::TRUTH_DATA_API_ENDPOINT)
      end

      it_behaves_like 'logs the outcome'
    end

    shared_examples('logs the outcome') do
      specify do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: log_message,
          event: 'Arkose truth data',
          result: result,
          username: user.username,
          arkose_session: session_token,
          arkose_risk_band: arkose_risk_band,
          is_legit: is_legit
        )

        execute
      end
    end

    context 'when Arkose data does not exist for the user' do
      let(:session_token) { 'none' }
      let(:arkose_risk_band) { 'none' }

      it_behaves_like 'short circuits the API request'
    end

    context 'when Arkose data exists for the user' do
      before do
        add_arkose_custom_attributes
      end

      where(:is_legit, :arkose_risk_band, :send_request) do
        true    | 'Low'     | false
        true    | 'Medium'  | true
        true    | 'High'    | true
        false   | 'Low'     | true
        false   | 'Medium'  | true
        false   | 'High'    | false
      end

      with_them do
        if params[:send_request]
          it_behaves_like 'successful API request'
        else
          it_behaves_like 'short circuits the API request'
        end
      end

      context 'when the client API call fails' do
        let(:client_api_status_code) { 500 }
        let(:log_message) { 'Unable to send truth data. Response code: 500' }
        let(:result) { 'failure' }

        it 'is unsuccessful' do
          result = execute

          expect(result).to be_error
          expect(result.message).to eql(log_message)
        end

        it_behaves_like('logs the outcome')
      end

      context 'when the authorization service fails' do
        let(:log_message) { 'oops' }
        let(:result) { 'failure' }

        before do
          allow(Arkose::TruthDataAuthorizationService).to receive(:execute).and_return(
            ServiceResponse.error(message: log_message)
          )
        end

        it 'is unsuccessful' do
          result = execute

          expect(result).to be_error
          expect(result.message).to eql(log_message)
        end

        it_behaves_like('logs the outcome')
      end
    end
  end
end
