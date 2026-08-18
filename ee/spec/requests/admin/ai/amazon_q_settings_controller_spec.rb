# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::AmazonQSettingsController, :enable_admin_mode, feature_category: :ai_abstraction_layer do
  # Ultimate license is needed for service account creation available set check
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:active_token) { create(:service_access_token, :active, token: JWT.encode({ sub: 'abc123' }, nil, 'none')) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }

  let(:admin) { create(:admin, organizations: [organization]) }
  let(:amazon_q_ready) { false }
  let(:connected) { true }

  let(:actual_view_model) do
    Gitlab::Json.parse(
      Nokogiri::HTML(response.body).css('#js-amazon-q-settings').first['data-view-model']
    )
  end

  before do
    stub_licensed_features(amazon_q: true)
    allow(::Ai::AmazonQ).to receive(:connected?).and_return(connected)

    stub_ee_application_setting(duo_availability: 'default_on')

    # NOTE: Updating this singleton in the top-level before each for increasing predictability with tests
    Ai::Setting.for_organization(organization).update!(
      amazon_q_ready: amazon_q_ready,
      amazon_q_role_arn: 'test-arn',
      amazon_q_service_account_user_id: nil,
      amazon_q_oauth_application_id: nil
    )

    allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive_messages(
        credits_available?: true,
        show_duo_entry_point?: true,
        agentic_mode_available?: false,
        classic_chat_available?: false
      )
    end

    sign_in(admin)
  end

  shared_examples 'returns 404 when feature is unavailable' do
    before do
      stub_licensed_features(amazon_q: false)
    end

    it 'returns 404' do
      perform_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'success when there is a valid token' do
    before do
      allow(::CloudConnector::Tokens).to receive(:get).with(
        unit_primitive: :amazon_q_integration,
        resource: :instance).and_return(active_token.token)
    end

    it 'renders the frontend entrypoint with view model' do
      perform_request

      expect(actual_view_model).to eq({
        "amazonQSettings" => {
          "availability" => "default_on",
          "ready" => amazon_q_ready,
          "roleArn" => 'test-arn'
        },
        "submitUrl" => admin_ai_amazon_q_settings_path,
        "disconnectUrl" => disconnect_admin_ai_amazon_q_settings_path,
        "identityProviderPayload" => {
          "aws_audience" => "gitlab-cc-abc123",
          "aws_provider_url" => "https://auth.token.gitlab.com/cc/oidc/abc123",
          "instance_uid" => "abc123"
        }
      })
    end
  end

  describe 'GET #index' do
    let(:perform_request) { get admin_ai_amazon_q_settings_path }

    it_behaves_like 'returns 404 when feature is unavailable'

    it_behaves_like 'success when there is a valid token'

    context 'when Amazon Q is ready' do
      let(:amazon_q_ready) { true }

      it_behaves_like 'success when there is a valid token'
    end

    context 'when there is a problem retrieving the token' do
      before do
        allow(::CloudConnector::Tokens).to receive(:get).with(
          unit_primitive: :amazon_q_integration,
          resource: :instance).and_return(nil)
      end

      it 'renders alert and empty identityProviderPayload' do
        perform_request

        expect(actual_view_model).to include("identityProviderPayload" => {})
        expect(flash[:alert]).to include(s_('AmazonQ|Something went wrong retrieving the identity provider payload.'))
      end
    end
  end

  describe 'POST #create' do
    using RSpec::Parameterized::TableSyntax

    let(:params) do
      {
        role_arn: 'a',
        availability: 'default_off',
        auto_review_enabled: 'false',
        organization_id: organization.id
      }
    end

    let(:perform_request) { post admin_ai_amazon_q_settings_path, params: params }

    it_behaves_like 'returns 404 when feature is unavailable'

    where(:amazon_q_ready, :service, :service_response, :message) do
      true  | ::Ai::AmazonQ::UpdateService | ServiceResponse.success | { notice: s_('AmazonQ|Amazon Q Settings have been saved.') }
      true  | ::Ai::AmazonQ::UpdateService | ServiceResponse.error(message: nil) | { alert: s_('AmazonQ|Something went wrong saving Amazon Q settings.') }
      false | ::Ai::AmazonQ::CreateService | ServiceResponse.success | { notice: s_('AmazonQ|Amazon Q Settings have been saved.') }
      false | ::Ai::AmazonQ::CreateService | ServiceResponse.error(message: 'Doh!') | { alert: 'Doh!' }
    end

    with_them do
      it 'triggers the expected service' do
        expect_next_instance_of(service, admin, ActionController::Parameters.new(params).permit!) do |service|
          expect(service).to receive(:execute).and_return(service_response)
        end

        perform_request

        expect(response).to redirect_to(edit_admin_application_settings_integration_path(:amazon_q))
      end
    end

    context 'when not ready' do
      it 'creates new amazon q integration' do
        stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application").and_return(status: 200,
          body: 'success')
        expect(::Ai::AmazonQ::CreateService).to receive(:new).and_call_original

        perform_request

        expect(flash[:alert]).to be_nil
        expect(response).to redirect_to(edit_admin_application_settings_integration_path(:amazon_q))
      end
    end
  end

  describe 'POST #disconnect' do
    let(:perform_request) { post disconnect_admin_ai_amazon_q_settings_path }

    it_behaves_like 'returns 404 when feature is unavailable'

    context 'when not connected' do
      let(:connected) { false }

      it 'returns unprocessable entity response' do
        perform_request

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
      end
    end

    context 'when connected' do
      let(:service_response) { ServiceResponse.success }

      it 'calls ::Ai::AmazonQ::DestroyService.execute and returns OK response' do
        expect_next_instance_of(::Ai::AmazonQ::DestroyService, admin) do |destroy_service|
          expect(destroy_service).to receive(:execute).and_return(service_response)
        end

        perform_request

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when ::Ai::AmazonQ::DestroyService.execute returns error response' do
        let(:service_response) { ServiceResponse.error(message: 'Oops') }

        it 'returns unprocessable entity response with corresponding message' do
          expect_next_instance_of(::Ai::AmazonQ::DestroyService, admin) do |destroy_service|
            expect(destroy_service).to receive(:execute).and_return(service_response)
          end

          perform_request

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to eq({ 'error_type' => 'generic', 'message' => 'Oops' })
        end
      end

      context 'when ::Ai::AmazonQ::DestroyService.execute returns UUID mismatch error' do
        let(:service_response) do
          ServiceResponse.error(
            message: 'GitLab instance UUID does not match the registered Identity Provider UUID in AWS'
          )
        end

        it 'returns unprocessable entity response with uuid_mismatch error type' do
          expect_next_instance_of(::Ai::AmazonQ::DestroyService, admin) do |destroy_service|
            expect(destroy_service).to receive(:execute).and_return(service_response)
          end

          perform_request

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to eq({
            'message' => 'GitLab instance UUID does not match the registered Identity Provider UUID in AWS',
            'error_type' => 'uuid_mismatch'
          })
        end
      end
    end
  end
end
