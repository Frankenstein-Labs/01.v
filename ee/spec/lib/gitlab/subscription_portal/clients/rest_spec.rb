# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::Clients::Rest, :without_license, feature_category: :subscription_management do
  let(:client) { Gitlab::SubscriptionPortal::Client }
  let(:message) { nil }
  let(:http_method) { :post }
  let(:response) { nil }
  let(:parsed_response) { nil }
  let(:response_headers) { nil }
  let(:gitlab_http_response) do
    instance_double(
      HTTParty::Response,
      code: response.code,
      response: response,
      body: {},
      parsed_response: parsed_response,
      headers: response_headers
    )
  end

  let(:headers) do
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'X-Admin-Email' => 'gl_com_api@gitlab.com',
      'X-Admin-Token' => 'customer_admin_token',
      'User-Agent' => "GitLab/#{Gitlab::VERSION}"
    }
  end

  before do
    # `namespace_trial_types` is stubbed globally and therefore needs to be un-stubbed in here
    allow(Gitlab::SubscriptionPortal::Client).to receive(:namespace_trial_types).and_call_original
  end

  shared_examples 'when response is successful' do
    let(:response) { Net::HTTPSuccess.new(1.0, '201', 'OK') }

    it 'has a successful status' do
      url = "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/#{route_path}"
      allow(Gitlab::HTTP).to receive(http_method)
        .with(url, instance_of(Hash))
        .and_return(gitlab_http_response)

      expect(subject[:success]).to be(true)
    end

    context 'when response body is not available' do
      let(:parsed_response) { nil }

      it 'has a successful status' do
        allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

        expect(subject[:success]).to be(true)
        expect(subject[:data]).to be_nil
      end
    end
  end

  shared_examples 'when http call raises an exception' do
    let(:message) { 'Our team has been notified. Please try again.' }

    it 'overrides the error message' do
      exception = Gitlab::HTTP::HTTP_ERRORS.first.new
      allow(Gitlab::HTTP).to receive(http_method).and_raise(exception)

      expect(subject[:success]).to be(false)
      expect(subject[:data][:errors]).to eq(message)
    end
  end

  shared_examples 'when response code is 422' do
    let(:response) { Net::HTTPUnprocessableEntity.new(1.0, '422', 'Error') }
    let(:message) { 'Email has already been taken' }
    let(:reason) { 'invalid_email' }
    let(:error_attribute_map) { { "email" => ["taken"] } }
    let(:parsed_response) { { errors: message, error_attribute_map: error_attribute_map }.stringify_keys }

    it 'has a unprocessable entity status' do
      allow(Gitlab::ErrorTracking).to receive(:log_exception)
      allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

      expect(subject[:success]).to be(false)

      expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
        instance_of(::Gitlab::SubscriptionPortal::Client::ResponseError),
        { status: response.code, errors: parsed_response }
      )
    end

    it 'returns the error message along with the error_attribute_map' do
      allow(Gitlab::ErrorTracking).to receive(:log_exception)
      allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

      expect(subject[:success]).to be(false)
      expect(subject[:data][:errors]).to eq(message)
      expect(subject[:data][:error_attribute_map]).to eq(error_attribute_map)
    end

    context "when response body is not available" do
      let(:parsed_response) { nil }

      it 'returns the unprocessable entity status' do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

        expect(subject[:success]).to be(false)
        expect(subject[:data][:errors]).to eq("HTTP status code: 422")

        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
          instance_of(::Gitlab::SubscriptionPortal::Client::ResponseError),
          { status: response.code, errors: "HTTP status code: 422" }
        )
      end
    end
  end

  shared_examples 'when response code is 500' do
    let(:response) { Net::HTTPServerError.new(1.0, '500', 'Error') }

    it 'has a server error status' do
      allow(Gitlab::ErrorTracking).to receive(:log_exception)
      allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

      expect(subject[:success]).to be(false)

      expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
        instance_of(::Gitlab::SubscriptionPortal::Client::ResponseError),
        { status: response.code, errors: "HTTP status code: #{response.code}" }
      )
    end
  end

  shared_examples 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header' do
    let(:response) { Net::HTTPSuccess.new(1.0, '201', 'OK') }

    context 'when subscription portal URL does not match staging URL' do
      before do
        allow(::Gitlab::Routing.url_helpers).to receive_messages(
          subscription_portal_url: 'https://customers.gitlab.com',
          subscription_portal_staging_url: 'https://customers.staging.gitlab.com'
        )
      end

      it 'sends the default User-Agent' do
        expect(Gitlab::HTTP).to receive(http_method).with(anything,
          hash_including(headers: headers)).and_return(gitlab_http_response)

        subject
      end
    end

    context 'when subscription portal URL matches staging URL' do
      before do
        allow(::Gitlab::Routing.url_helpers).to receive_messages(
          subscription_portal_url: 'https://customers.staging.gitlab.com',
          subscription_portal_staging_url: 'https://customers.staging.gitlab.com'
        )
      end

      it 'sends GITLAB_QA_USER_AGENT env variable value in the "User-Agent" header' do
        expected_headers = headers.merge({ 'User-Agent' => 'GitLab/QA' })

        stub_env('GITLAB_QA_USER_AGENT', 'GitLab/QA')

        expect(Gitlab::HTTP).to receive(http_method).with(anything,
          hash_including(headers: expected_headers)).and_return(gitlab_http_response)

        subject
      end
    end
  end

  shared_examples 'when request is disabled' do
    let(:message) { 'Subscription portal requests disabled for non-SaaS.' }

    it 'returns disabled error message' do
      allow(Gitlab::HTTP).to receive(http_method)

      expect(Gitlab::HTTP).not_to receive(http_method)
      expect(subject[:success]).to be(false)
      expect(subject[:data][:errors]).to eq(message)
    end
  end

  describe 'request methods - non saas environment' do
    let(:headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'X-License-Token' => License.current.checksum,
        'User-Agent' => "GitLab/#{Gitlab::VERSION}"
      }
    end

    before_all do
      TestLicense.init
    end

    describe '#generate_trial' do
      subject do
        client.generate_trial({})
      end

      let(:route_path) { 'trials' }

      it_behaves_like 'when request is disabled'
    end

    describe '#generate_trial_lead' do
      subject do
        client.generate_trial_lead({})
      end

      let(:route_path) { 'leads/gitlab_com/ultimates' }

      it_behaves_like 'when request is disabled'
    end

    describe '#generate_addon_trial' do
      subject do
        client.generate_addon_trial({})
      end

      let(:route_path) { 'trials/create_addon' }

      it_behaves_like 'when request is disabled'
    end

    describe '#generate_lead' do
      subject do
        client.generate_lead({})
      end

      let(:route_path) { 'leads/gitlab_com/hand_raises' }

      it_behaves_like 'when request is disabled'
    end

    describe '#generate_iterable' do
      subject do
        client.generate_iterable({})
      end

      let(:route_path) { 'trials/create_iterable' }

      it_behaves_like 'when request is disabled'
    end

    describe '#generate_self_managed_ultimate_trial' do
      subject do
        client.generate_self_managed_ultimate_trial(trial_params)
      end

      let(:headers) do
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }
      end

      let(:trial_params) do
        {
          name: 'John Doe',
          company: 'ACME Corp',
          email: 'john@example.com',
          language: 'en'
        }
      end

      let(:route_path) { 'trials/self_managed/ultimates' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'

      it 'passes params directly without nesting' do
        expect(client).to receive(:http_post).with(
          'trials/self_managed/ultimates',
          anything,
          trial_params
        )

        client.generate_self_managed_ultimate_trial(trial_params)
      end
    end

    describe '#create_self_managed_welcome_contact' do
      subject do
        client.create_self_managed_welcome_contact(lead_params)
      end

      let(:headers) do
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }
      end

      let(:lead_params) do
        {
          lead: {
            first_name: 'Jane',
            last_name: 'Doe',
            email: 'jane@example.com',
            company_name: 'Acme Corp',
            product_interaction: 'SM Welcome Flow No Trial Contact'
          }
        }
      end

      let(:route_path) { 'leads/self_managed/welcome_contacts' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'

      it 'passes params directly without nesting' do
        expect(client).to receive(:http_post).with(
          'leads/self_managed/welcome_contacts',
          anything,
          lead_params
        )

        client.create_self_managed_welcome_contact(lead_params)
      end
    end

    describe '#namespace_eligible_trials' do
      subject do
        client.namespace_eligible_trials(namespace_ids: ['1'])
      end

      let(:http_method) { :get }
      let(:route_path) { 'api/v1/gitlab/namespaces/trials/eligibility' }

      it_behaves_like 'when request is disabled'
    end

    describe '#namespace_trial_types' do
      subject do
        client.namespace_trial_types
      end

      let(:http_method) { :get }
      let(:route_path) { 'api/v1/gitlab/namespaces/trials/trial_types' }

      it_behaves_like 'when request is disabled'
    end

    describe '#verify_usage_quota' do
      subject(:verify_usage_quota_request) { client.verify_usage_quota(params) }

      let(:params) do
        {
          event_type: 'ai_request',
          feature_qualified_name: 'duo_chat',
          realm: 'self-managed',
          user_id: 1,
          unique_instance_id: "00000000-0000-0000-0000-000000000000"
        }
      end

      let(:http_method) { :head }
      let(:route_path) { 'api/v1/consumers/resolve' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'

      context 'when response code is 402' do
        let(:response) { Net::HTTPPaymentRequired.new(1.0, '402', 'Payment Required') }

        it 'returns the "Payment required" error' do
          allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

          expect(verify_usage_quota_request[:success]).to be(false)
          expect(verify_usage_quota_request[:data][:errors]).to eq("HTTP status code: 402")
        end
      end

      context 'when response code is 403' do
        let(:response) { Net::HTTPForbidden.new(1.0, '403', 'Forbidden') }

        it 'returns the "Forbidden" error' do
          allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

          expect(verify_usage_quota_request[:success]).to be(false)
          expect(verify_usage_quota_request[:data][:errors]).to eq("HTTP status code: 403")
        end
      end

      describe 'cache_ttl from response headers' do
        let(:response) { Net::HTTPSuccess.new(1.0, '200', 'OK') }

        before do
          allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)
        end

        context 'when Cache-Control header contains max-age' do
          let(:response_headers) { { 'cache-control' => 'max-age=300' } }

          it 'extracts the cache TTL' do
            expect(verify_usage_quota_request[:cache_ttl]).to eq(300)
          end
        end

        context 'when Cache-Control header contains max-age with other directives' do
          let(:response_headers) { { 'cache-control' => 'public, max-age=3600, must-revalidate' } }

          it 'extracts the cache TTL' do
            expect(verify_usage_quota_request[:cache_ttl]).to eq(3600)
          end
        end

        context 'when Cache-Control header is missing' do
          let(:response_headers) { nil }

          it 'returns nil cache_ttl' do
            expect(verify_usage_quota_request[:cache_ttl]).to be_nil
          end
        end

        context 'when Cache-Control header has no max-age' do
          let(:response_headers) { { 'cache-control' => 'no-cache' } }

          it 'returns nil cache_ttl' do
            expect(verify_usage_quota_request[:cache_ttl]).to be_nil
          end
        end
      end

      describe 'url' do
        let(:expected_url) { "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/#{route_path}" }
        let(:response) { Net::HTTPSuccess.new(1.0, '201', 'OK') }

        before do
          allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)
          stub_feature_flags(use_mock_dot_api_for_usage_quota: false)
        end

        it 'uses SUBSCRIPTION_PORTAL_URL' do
          verify_usage_quota_request
          expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
        end

        context 'when in development mode' do
          before do
            stub_rails_env('development')
          end

          it 'uses SUBSCRIPTION_PORTAL_URL' do
            verify_usage_quota_request
            expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
          end
        end

        context 'when feature flag is set' do
          before do
            stub_feature_flags(use_mock_dot_api_for_usage_quota: true)
          end

          it 'uses SUBSCRIPTION_PORTAL_URL' do
            verify_usage_quota_request
            expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
          end
        end

        context 'when in development mode and feature flag is set' do
          before do
            stub_feature_flags(use_mock_dot_api_for_usage_quota: true)
            stub_rails_env('development')
          end

          let(:expected_url) { "http://localhost:4567/#{route_path}" }

          it 'uses mock server url' do
            verify_usage_quota_request
            expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
          end

          context 'when env variable is set' do
            before do
              stub_env('MOCK_CUSTOMER_DOT_PORTAL_SERVER_URL', 'http://another-url.com')
            end

            let(:expected_url) { "http://another-url.com/#{route_path}" }

            it 'uses env mock server url' do
              verify_usage_quota_request
              expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
            end
          end
        end
      end
    end
  end

  describe 'request methods', :saas do
    describe '#generate_trial' do
      subject do
        client.generate_trial({})
      end

      let(:route_path) { 'trials/gitlab_com/ultimates' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'

      it "nests in the trial_user param if needed" do
        expect(client).to receive(:http_post).with('trials/gitlab_com/ultimates', anything,
          { trial_user: { foo: 'bar' } })

        client.generate_trial(foo: 'bar')
      end
    end

    describe '#generate_trial_lead' do
      subject do
        client.generate_trial_lead({})
      end

      let(:route_path) { 'leads/gitlab_com/ultimates' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'

      it 'passes trial_user param' do
        expect(client).to receive(:http_post).with(route_path, anything, { trial_user: { foo: 'bar' } })

        client.generate_trial_lead(trial_user: { foo: 'bar' })
      end

      it 'nests in the trial_user param if needed' do
        expect(client).to receive(:http_post).with(route_path, anything, { trial_user: { foo: 'bar' } })

        client.generate_trial_lead(foo: 'bar')
      end
    end

    describe '#generate_addon_trial_lead' do
      let(:route_path) { 'leads/gitlab_com/addons' }

      subject do
        client.generate_addon_trial_lead({})
      end

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'

      it 'passes trial_user param' do
        expect(client).to receive(:http_post).with(route_path, anything, { trial_user: { foo: 'bar' } })

        client.generate_addon_trial_lead(trial_user: { foo: 'bar' })
      end

      it 'nests in the trial_user param if needed' do
        expect(client).to receive(:http_post).with(route_path, anything, { trial_user: { foo: 'bar' } })

        client.generate_addon_trial_lead(foo: 'bar')
      end
    end

    describe '#generate_addon_trial' do
      subject do
        client.generate_addon_trial({})
      end

      let(:route_path) { 'trials/gitlab_com/addons' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'

      it 'passes trial_user param' do
        expect(client).to receive(:http_post).with(route_path, anything, { trial_user: { foo: 'bar' } })

        client.generate_addon_trial(trial_user: { foo: 'bar' })
      end

      it 'nests in the trial_user param if needed' do
        expect(client).to receive(:http_post).with(route_path, anything, { trial_user: { foo: 'bar' } })

        client.generate_addon_trial(foo: 'bar')
      end
    end

    describe '#generate_lead' do
      subject do
        client.generate_lead({})
      end

      let(:route_path) { 'leads/gitlab_com/hand_raises' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
    end

    describe '#generate_iterable' do
      subject do
        client.generate_iterable({})
      end

      let(:route_path) { 'trials/create_iterable' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
    end

    describe '#opt_in_lead' do
      subject do
        client.opt_in_lead({})
      end

      let(:route_path) { 'api/marketo_leads/opt_in' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
    end

    describe '#payment_form_params' do
      subject do
        client.payment_form_params('cc', 123)
      end

      let(:http_method) { :get }
      let(:route_path) { 'payment_forms/cc' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
    end

    describe '#validate_payment_method' do
      subject do
        client.validate_payment_method('test_payment_method_id', {})
      end

      let(:http_method) { :post }
      let(:route_path) { 'api/payment_methods/test_payment_method_id/validate' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
    end

    describe '#create_seat_link' do
      subject do
        seat_link_data = Gitlab::SeatLinkData.new(
          timestamp: Time.current,
          key: 'license_key',
          max_users: 5,
          billable_users_count: 4)

        client.create_seat_link(seat_link_data)
      end

      let(:http_method) { :post }
      let(:route_path) { 'api/v1/seat_links' }
      let(:headers) do
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => "GitLab/#{Gitlab::VERSION}"
        }
      end

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
    end

    describe '#namespace_eligible_trials' do
      subject do
        client.namespace_eligible_trials(namespace_ids: ['1'])
      end

      let(:http_method) { :get }
      let(:route_path) { 'api/v1/gitlab/namespaces/trials/eligibility' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
    end

    describe '#namespace_trial_types' do
      subject do
        client.namespace_trial_types
      end

      let(:http_method) { :get }
      let(:route_path) { 'api/v1/gitlab/namespaces/trials/trial_types' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
    end

    describe '#verify_usage_quota' do
      subject(:verify_usage_quota_request) { client.verify_usage_quota(params) }

      let(:params) do
        {
          event_type: 'ai_request',
          feature_qualified_name: 'duo_chat',
          realm: 'saas',
          user_id: 1,
          root_namespace_id: 1
        }
      end

      let(:http_method) { :head }
      let(:route_path) { 'api/v1/consumers/resolve' }

      it_behaves_like 'when response is successful'
      it_behaves_like 'when response code is 422'
      it_behaves_like 'when response code is 500'
      it_behaves_like 'when http call raises an exception'
      it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'

      context 'when response code is 402' do
        let(:response) { Net::HTTPPaymentRequired.new(1.0, '402', 'Payment Required') }

        it 'returns the "Payment required" error' do
          allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

          expect(verify_usage_quota_request[:success]).to be(false)
          expect(verify_usage_quota_request[:data][:errors]).to eq("HTTP status code: 402")
        end
      end

      context 'when response code is 403' do
        let(:response) { Net::HTTPForbidden.new(1.0, '403', 'Forbidden') }

        it 'returns the "Forbidden" error' do
          allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

          expect(verify_usage_quota_request[:success]).to be(false)
          expect(verify_usage_quota_request[:data][:errors]).to eq("HTTP status code: 403")
        end
      end

      describe 'url' do
        let(:expected_url) { "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/#{route_path}" }
        let(:response) { Net::HTTPSuccess.new(1.0, '201', 'OK') }

        before do
          allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)
          stub_feature_flags(use_mock_dot_api_for_usage_quota: false)
        end

        it 'uses SUBSCRIPTION_PORTAL_URL' do
          verify_usage_quota_request
          expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
        end

        context 'when in development mode' do
          before do
            stub_rails_env('development')
          end

          it 'uses SUBSCRIPTION_PORTAL_URL' do
            verify_usage_quota_request
            expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
          end
        end

        context 'when feature flag is set' do
          before do
            stub_feature_flags(use_mock_dot_api_for_usage_quota: true)
          end

          it 'uses SUBSCRIPTION_PORTAL_URL' do
            verify_usage_quota_request
            expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
          end
        end

        context 'when in development mode and feature flag is set' do
          before do
            stub_feature_flags(use_mock_dot_api_for_usage_quota: true)
            stub_rails_env('development')
          end

          let(:expected_url) { "http://localhost:4567/#{route_path}" }

          it 'uses mock server url' do
            verify_usage_quota_request
            expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
          end

          context 'when env variable is set' do
            before do
              stub_env('MOCK_CUSTOMER_DOT_PORTAL_SERVER_URL', 'http://another-url.com')
            end

            let(:expected_url) { "http://another-url.com/#{route_path}" }

            it 'uses env mock server url' do
              verify_usage_quota_request
              expect(Gitlab::HTTP).to have_received(http_method).with(expected_url, anything)
            end
          end
        end
      end
    end

    describe '#secrets_manager_trial', :request_store do
      let(:namespace_id) { 42 }
      let(:instance_id) { '00000000-0000-0000-0000-000000000000' }
      let(:expected_url) { "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/api/v1/billing/usage/trials" }
      let(:http_response) do
        instance_double(
          HTTParty::Response, code: response_code, parsed_response: parsed_response, headers: response_headers
        )
      end

      let(:response_code) { 200 }
      let(:starts_at) { '2026-06-01T08:00:00Z' }
      let(:expires_at) { 1.month.from_now.iso8601 }
      let(:eligible_to_start_new_trial) { false }
      let(:current_balance) { '500.0' }
      let(:opt_in_paid) { true }
      let(:trials) { [{ 'starts_at' => starts_at, 'expires_at' => expires_at, 'initial_credit_amount' => '500.0' }] }
      let(:parsed_response) do
        {
          'success' => true,
          'trial_info' => {
            'secrets_manager' => {
              'current_balance' => current_balance,
              'trials' => trials,
              'opt_in_paid' => opt_in_paid,
              'eligible_to_start_new_trial' => eligible_to_start_new_trial
            }
          }
        }
      end

      before do
        allow(Gitlab::HTTP).to receive(:get).and_return(http_response)
      end

      context 'when called from a CDot-connected install' do
        context 'with namespace_id (gitlab.com SaaS)', :saas do
          subject(:secrets_manager_trial) { client.secrets_manager_trial(namespace_id: namespace_id) }

          it 'sends X-Admin-Token, root_namespace_id, and realm', :aggregate_failures do
            secrets_manager_trial

            expect(Gitlab::HTTP).to have_received(:get).with(
              expected_url,
              query: { root_namespace_id: namespace_id, realm: 'saas' },
              headers: hash_including(
                'X-Gitlab-Version' => ::Gitlab::VERSION,
                'X-Admin-Token' => ::Gitlab::SubscriptionPortal::SUBSCRIPTION_PORTAL_ADMIN_TOKEN
              )
            )
          end

          context 'with HTTP 200' do
            it 'returns a typed value object with trial dates, quota fields, and a derived :trial state',
              :aggregate_failures do
              result = secrets_manager_trial

              expect(result).to be_a(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse)
              expect(result.state).to eq(:trial)
              expect(result.trial_started_at).to eq(Time.zone.parse(starts_at))
              expect(result.trial_expires_at).to eq(Time.zone.parse(expires_at))
              expect(result.credits_remaining).to eq(500)
              expect(result.credits_total).to eq(500)
              expect(result.on_demand_enabled).to be true
            end

            context 'with an expired trial (expires_at in the past)' do
              let(:expires_at) { 1.day.ago.iso8601 }

              it 'derives :expired and preserves the dates', :aggregate_failures do
                result = secrets_manager_trial

                expect(result.state).to eq(:expired)
                expect(result.trial_started_at).to eq(Time.zone.parse(starts_at))
                expect(result.trial_expires_at).to eq(Time.zone.parse(expires_at))
              end
            end

            context 'with opt_in_paid: false and fractional credit amounts' do
              let(:opt_in_paid) { false }
              let(:current_balance) { '249.5' }
              let(:trials) do
                [{ 'starts_at' => starts_at, 'expires_at' => expires_at, 'initial_credit_amount' => '500.5' }]
              end

              it 'reflects the quota fields on the PORO', :aggregate_failures do
                result = secrets_manager_trial

                expect(result.on_demand_enabled).to be false
                expect(result.credits_remaining).to eq(249)
                expect(result.credits_total).to eq(500)
              end
            end

            context 'with no trials yet' do
              let(:trials) { [] }

              context 'and eligible_to_start_new_trial: true' do
                let(:eligible_to_start_new_trial) { true }

                it 'derives :trial_eligible with nil dates and nil credits_total', :aggregate_failures do
                  result = secrets_manager_trial

                  expect(result.state).to eq(:trial_eligible)
                  expect(result.trial_started_at).to be_nil
                  expect(result.trial_expires_at).to be_nil
                  expect(result.credits_total).to be_nil
                end
              end

              context 'and eligible_to_start_new_trial: false' do
                it 'derives :ineligible' do
                  expect(secrets_manager_trial.state).to eq(:ineligible)
                end
              end
            end

            context 'when the payload has no secrets_manager block' do
              let(:parsed_response) { { 'success' => true, 'trial_info' => {} } }

              it 'fails closed to :ineligible with nil dates', :aggregate_failures do
                result = secrets_manager_trial

                expect(result.state).to eq(:ineligible)
                expect(result.trial_started_at).to be_nil
                expect(result.trial_expires_at).to be_nil
              end
            end

            context 'when the secrets_manager block is not a Hash' do
              let(:parsed_response) { { 'success' => true, 'trial_info' => { 'secrets_manager' => nil } } }

              it 'fails closed to :ineligible' do
                expect(secrets_manager_trial.state).to eq(:ineligible)
              end
            end
          end

          context 'with a non-200 status from CDot' do
            # CDot's TrialsController#index returns 200 / 400 / 401 / 422 / 500.
            # "No record" is signalled by a 200 with an absent secrets_manager
            # block (covered above), so every non-200 is a protocol / deployment
            # error: raise and let the Resolver fail closed.
            [400, 401, 422, 500, 503].each do |code|
              context "with HTTP #{code}" do
                let(:response_code) { code }

                it 'raises SecretsManagerTrialResponse::Error with the status' do
                  expect { secrets_manager_trial }.to raise_error(
                    ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, /HTTP #{code}/
                  )
                end
              end
            end
          end

          context 'when the HTTP layer raises a network error' do
            before do
              allow(Gitlab::HTTP).to receive(:get).and_raise(Errno::ECONNREFUSED.new('boom'))
            end

            it 'raises SecretsManagerTrialResponse::Error' do
              expect { secrets_manager_trial }.to raise_error(
                ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, /boom/
              )
            end
          end

          describe 'per-request memoization' do
            it 'calls CDot only once per (namespace_id) within a request' do
              2.times { client.secrets_manager_trial(namespace_id: namespace_id) }

              expect(Gitlab::HTTP).to have_received(:get).once
            end

            it 'distinguishes between different namespace_ids' do
              client.secrets_manager_trial(namespace_id: namespace_id)
              client.secrets_manager_trial(namespace_id: namespace_id + 1)

              expect(Gitlab::HTTP).to have_received(:get).twice
            end
          end

          describe 'per-call timeout' do
            it 'forwards a provided timeout to Gitlab::HTTP' do
              client.secrets_manager_trial(namespace_id: namespace_id, timeout: 0.25)

              expect(Gitlab::HTTP).to have_received(:get)
                .with(expected_url, hash_including(timeout: 0.25))
            end

            it 'sets no timeout by default, leaving the Gitlab::HTTP defaults in place' do
              secrets_manager_trial

              expect(Gitlab::HTTP).to have_received(:get)
                .with(expected_url, hash_excluding(:timeout))
            end
          end

          describe 'cross-request caching', :use_clean_rails_memory_store_caching do
            # The request store memoizes within one request; clearing it
            # simulates the next request hitting the same process.
            def call_in_new_request
              RequestStore.clear!
              client.secrets_manager_trial(namespace_id: namespace_id)
            end

            it 'serves repeat requests from the cache' do
              2.times { call_in_new_request }

              expect(Gitlab::HTTP).to have_received(:get).once
            end

            context "with a Cache-Control max-age from CDot" do
              let(:response_headers) { { 'cache-control' => 'private, max-age=300' } }

              it 'exposes the parsed TTL on the response object' do
                expect(call_in_new_request.cache_ttl).to eq(300)
              end

              it 'stays cached beyond the fallback TTL but within max-age' do
                call_in_new_request

                travel_to(299.seconds.from_now) { call_in_new_request }

                expect(Gitlab::HTTP).to have_received(:get).once
              end

              it 'expires after max-age' do
                call_in_new_request

                travel_to(301.seconds.from_now) { call_in_new_request }

                expect(Gitlab::HTTP).to have_received(:get).twice
              end
            end

            context 'without a Cache-Control max-age' do
              it 'falls back to the default TTL of 120 seconds' do
                call_in_new_request

                travel_to(119.seconds.from_now) { call_in_new_request }
                travel_to(121.seconds.from_now) { call_in_new_request }

                expect(Gitlab::HTTP).to have_received(:get).twice
              end
            end

            context 'with Cache-Control max-age=0' do
              let(:response_headers) { { 'cache-control' => 'max-age=0' } }

              it 'does not cache at all' do
                2.times { call_in_new_request }

                expect(Gitlab::HTTP).to have_received(:get).twice
              end
            end

            context 'when the CDot call fails' do
              it 'does not cache the failure' do
                allow(Gitlab::HTTP).to receive(:get).and_raise(Errno::ECONNREFUSED.new('boom'))
                RequestStore.clear!

                expect { client.secrets_manager_trial(namespace_id: namespace_id) }.to raise_error(
                  ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error
                )

                allow(Gitlab::HTTP).to receive(:get).and_return(http_response)

                expect(call_in_new_request.state).to eq(:trial)
              end
            end
          end
        end

        context 'with instance_id (self-managed online cloud license)' do
          subject(:secrets_manager_trial) { client.secrets_manager_trial(instance_id: instance_id) }

          let(:license) { instance_double(::License, checksum: 'checksum-deadbeef') }

          before do
            allow(::Gitlab).to receive(:com?).and_return(false)
            allow(::License).to receive(:current).and_return(license)
          end

          it 'sends X-License-Token (not X-Admin-Token), instance_id, and realm', :aggregate_failures do
            secrets_manager_trial

            expect(Gitlab::HTTP).to have_received(:get).with(
              expected_url,
              query: { instance_id: instance_id, realm: 'self-managed' },
              headers: hash_including(
                'X-Gitlab-Version' => ::Gitlab::VERSION,
                'X-License-Token' => 'checksum-deadbeef'
              )
            )

            expect(Gitlab::HTTP).not_to have_received(:get).with(
              anything,
              hash_including(headers: hash_including('X-Admin-Token'))
            )
          end

          it 'returns the typed value object for HTTP 200' do
            expect(secrets_manager_trial).to be_a(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse)
          end
        end
      end
    end

    describe '#start_secrets_manager_trial' do
      let(:namespace_id) { 42 }
      let(:instance_id) { '00000000-0000-0000-0000-000000000000' }
      let(:expected_url) { "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/api/v1/billing/usage/trials" }
      let(:response_code) { 201 }
      let(:parsed_response) { {} }
      let(:http_response) do
        instance_double(HTTParty::Response, code: response_code, parsed_response: parsed_response)
      end

      before do
        allow(Gitlab::HTTP).to receive(:post).and_return(http_response)
      end

      context 'with namespace_id (gitlab.com SaaS)', :saas do
        subject(:start_trial) { client.start_secrets_manager_trial(namespace_id: namespace_id) }

        it 'POSTs X-Admin-Token, root_namespace_id, realm, and trial_type', :aggregate_failures do
          start_trial

          expect(Gitlab::HTTP).to have_received(:post).with(
            expected_url,
            body: { root_namespace_id: namespace_id, realm: 'saas', trial_type: 'secrets_manager' }.to_json,
            headers: hash_including(
              'X-Gitlab-Version' => ::Gitlab::VERSION,
              'X-Admin-Token' => ::Gitlab::SubscriptionPortal::SUBSCRIPTION_PORTAL_ADMIN_TOKEN
            )
          )
        end

        context 'with HTTP 201' do
          it 'returns a successful result', :aggregate_failures do
            result = start_trial

            expect(result).to be_a(::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse)
            expect(result).to be_success
          end
        end

        context 'with HTTP 200' do
          let(:response_code) { 200 }

          it 'returns a successful result' do
            expect(start_trial).to be_success
          end
        end

        context 'with HTTP 409 (already trialing)' do
          let(:response_code) { 409 }

          it 'returns a :trial_already_active failure', :aggregate_failures do
            expect(start_trial).not_to be_success
            expect(start_trial.error_code).to eq(:trial_already_active)
          end
        end

        context 'with HTTP 422 (ineligible)' do
          let(:response_code) { 422 }
          let(:parsed_response) { { 'errors' => ['Namespace is not eligible'] } }

          it 'returns an :ineligible failure carrying the CDot message', :aggregate_failures do
            expect(start_trial).not_to be_success
            expect(start_trial.error_code).to eq(:ineligible)
            expect(start_trial.error_message).to eq('Namespace is not eligible')
          end
        end

        context 'with HTTP 404 (unknown to CDot)' do
          let(:response_code) { 404 }

          it 'returns a :not_found failure' do
            expect(start_trial.error_code).to eq(:not_found)
          end
        end

        context 'with an unexpected status from CDot' do
          let(:response_code) { 500 }

          it 'raises SecretsManagerStartTrialResponse::Error with the status' do
            expect { start_trial }.to raise_error(
              ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse::Error, /HTTP 500/
            )
          end
        end

        context 'when the HTTP layer raises a network error' do
          before do
            allow(Gitlab::HTTP).to receive(:post).and_raise(Errno::ECONNREFUSED.new('boom'))
          end

          it 'raises SecretsManagerStartTrialResponse::Error' do
            expect { start_trial }.to raise_error(
              ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse::Error, /boom/
            )
          end
        end

        it 'is not memoized (each call hits CDot)' do
          2.times { client.start_secrets_manager_trial(namespace_id: namespace_id) }

          expect(Gitlab::HTTP).to have_received(:post).twice
        end
      end

      context 'with instance_id (self-managed online cloud license)' do
        subject(:start_trial) { client.start_secrets_manager_trial(instance_id: instance_id) }

        let(:license) { instance_double(::License, checksum: 'checksum-deadbeef') }

        before do
          allow(::Gitlab).to receive(:com?).and_return(false)
          allow(::License).to receive(:current).and_return(license)
        end

        it 'POSTs X-License-Token (not X-Admin-Token), instance_id, realm, and trial_type', :aggregate_failures do
          start_trial

          expect(Gitlab::HTTP).to have_received(:post).with(
            expected_url,
            body: { instance_id: instance_id, realm: 'self-managed', trial_type: 'secrets_manager' }.to_json,
            headers: hash_including(
              'X-Gitlab-Version' => ::Gitlab::VERSION,
              'X-License-Token' => 'checksum-deadbeef'
            )
          )
        end
      end
    end

    describe '#secrets_manager_consumer_resolve', :request_store do
      let(:namespace_id) { 42 }
      let(:instance_id) { '00000000-0000-0000-0000-000000000000' }
      let(:user_id) { 7 }
      let(:expected_url) { "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/api/v1/consumers/resolve" }
      let(:http_response) do
        instance_double(
          HTTParty::Response, code: response_code, parsed_response: parsed_response, headers: response_headers
        )
      end

      let(:response_code) { 200 }
      let(:parsed_response) { {} }

      before do
        allow(Gitlab::HTTP).to receive(:get).and_return(http_response)
      end

      context 'when called from a CDot-connected install' do
        context 'with namespace_id (gitlab.com SaaS)', :saas do
          subject(:resolve) { client.secrets_manager_consumer_resolve(namespace_id: namespace_id, user_id: user_id) }

          it 'sends X-Admin-Token + the feature-scoped, version-aware, actor-aware query', :aggregate_failures do
            resolve

            expect(Gitlab::HTTP).to have_received(:get).with(
              expected_url,
              query: {
                root_namespace_id: namespace_id,
                realm: 'saas',
                event_type: 'secrets_read',
                feature_qualified_name: 'secrets_read',
                instance_version: ::Gitlab::VERSION,
                user_id: user_id
              },
              headers: hash_including(
                'X-Gitlab-Version' => ::Gitlab::VERSION,
                'X-Admin-Token' => ::Gitlab::SubscriptionPortal::SUBSCRIPTION_PORTAL_ADMIN_TOKEN
              )
            )
          end

          context 'with HTTP 200 (not blocked)' do
            it 'returns a non-blocked PORO without parsing the body', :aggregate_failures do
              result = resolve

              expect(result).to be_a(::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse)
              expect(result.blocked).to be false
              expect(result.blocked_reason).to be_nil
            end
          end

          context 'with HTTP 402 Payment Required (blocked)' do
            let(:response_code) { 402 }
            let(:parsed_response) { { 'block_reason' => 'credits_exhausted' } }

            it 'parses block_reason from the body', :aggregate_failures do
              result = resolve

              expect(result.blocked).to be true
              expect(result.blocked_reason).to eq(:credits_exhausted)
            end

            context 'with the no_billable_source_error block_reason' do
              let(:parsed_response) { { 'block_reason' => 'no_billable_source_error' } }

              it 'parses it as a blocked response', :aggregate_failures do
                result = resolve

                expect(result.blocked).to be true
                expect(result.blocked_reason).to eq(:no_billable_source_error)
              end
            end

            context 'with an unknown block_reason' do
              let(:parsed_response) { { 'block_reason' => 'below_min_gitlab_version' } }

              it 'raises ArgumentError from the value object validator' do
                expect { resolve }.to raise_error(ArgumentError, /Unknown CDot consumer-resolve blocked_reason/)
              end
            end
          end

          context 'with a non-{200,402} status from CDot' do
            # 200 is the allow signal, 402 is the block signal; any other code
            # is a protocol or deployment problem -- raise so the resolver's
            # rescue fails closed to :ineligible.
            [400, 401, 422, 500, 503].each do |code|
              context "with HTTP #{code}" do
                let(:response_code) { code }

                it 'raises SecretsManagerConsumerResolveResponse::Error with the status' do
                  expect { resolve }.to raise_error(
                    ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse::Error, /HTTP #{code}/
                  )
                end
              end
            end
          end

          context 'when the HTTP layer raises a network error' do
            before do
              allow(Gitlab::HTTP).to receive(:get).and_raise(Errno::ECONNREFUSED.new('boom'))
            end

            it 'raises SecretsManagerConsumerResolveResponse::Error' do
              expect { resolve }.to raise_error(
                ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse::Error, /boom/
              )
            end
          end

          describe 'per-request memoization' do
            it 'calls CDot only once per (namespace_id) within a request' do
              2.times { client.secrets_manager_consumer_resolve(namespace_id: namespace_id) }

              expect(Gitlab::HTTP).to have_received(:get).once
            end
          end

          describe 'per-call timeout' do
            it 'forwards a provided timeout to Gitlab::HTTP' do
              client.secrets_manager_consumer_resolve(namespace_id: namespace_id, user_id: user_id, timeout: 0.25)

              expect(Gitlab::HTTP).to have_received(:get)
                .with(expected_url, hash_including(timeout: 0.25))
            end
          end

          describe 'cross-request caching', :use_clean_rails_memory_store_caching do
            def call_in_new_request
              RequestStore.clear!
              client.secrets_manager_consumer_resolve(namespace_id: namespace_id, user_id: user_id)
            end

            it 'serves repeat requests from the cache' do
              2.times { call_in_new_request }

              expect(Gitlab::HTTP).to have_received(:get).once
            end

            context 'with a blocked (402) verdict' do
              let(:response_code) { 402 }
              let(:parsed_response) { { 'block_reason' => 'credits_exhausted' } }

              it 'caches the blocked verdict too', :aggregate_failures do
                results = Array.new(2) { call_in_new_request }

                expect(Gitlab::HTTP).to have_received(:get).once
                expect(results).to all(have_attributes(blocked: true, blocked_reason: :credits_exhausted))
              end
            end
          end
        end

        context 'with instance_id (self-managed online cloud license)' do
          subject(:resolve) { client.secrets_manager_consumer_resolve(instance_id: instance_id, user_id: user_id) }

          let(:license) { instance_double(::License, checksum: 'checksum-deadbeef') }

          before do
            allow(::Gitlab).to receive(:com?).and_return(false)
            allow(::License).to receive(:current).and_return(license)
          end

          it 'sends X-License-Token + the query with unique_instance_id and user_id', :aggregate_failures do
            resolve

            expect(Gitlab::HTTP).to have_received(:get).with(
              expected_url,
              query: {
                instance_id: instance_id,
                realm: 'self-managed',
                event_type: 'secrets_read',
                feature_qualified_name: 'secrets_read',
                instance_version: ::Gitlab::VERSION,
                user_id: user_id,
                unique_instance_id: instance_id
              },
              headers: hash_including(
                'X-Gitlab-Version' => ::Gitlab::VERSION,
                'X-License-Token' => 'checksum-deadbeef'
              )
            )
          end
        end
      end
    end

    describe '#expire_secrets_manager_cache', :request_store, :use_clean_rails_memory_store_caching do
      let(:namespace_id) { 42 }
      let(:instance_id) { '00000000-0000-0000-0000-000000000000' }
      let(:trials_url) { "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/api/v1/billing/usage/trials" }
      let(:resolve_url) { "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/api/v1/consumers/resolve" }
      let(:response_headers) { { 'cache-control' => 'private, max-age=300' } }

      let(:trials_response) do
        instance_double(
          HTTParty::Response,
          code: 200,
          headers: response_headers,
          parsed_response: {
            'success' => true,
            'trial_info' => {
              'secrets_manager' => {
                'current_balance' => '0.0',
                'trials' => [],
                'opt_in_paid' => false,
                'eligible_to_start_new_trial' => true
              }
            }
          }
        )
      end

      # A blocked verdict is the entry that actually persists: it carries a
      # max-age, so it is the one that can outlive a trial start.
      let(:resolve_response) do
        instance_double(
          HTTParty::Response,
          code: 402,
          headers: response_headers,
          parsed_response: { 'block_reason' => 'on_demand_disabled' }
        )
      end

      before do
        allow(Gitlab::HTTP).to receive(:get).with(trials_url, anything).and_return(trials_response)
        allow(Gitlab::HTTP).to receive(:get).with(resolve_url, anything).and_return(resolve_response)
      end

      context 'on gitlab.com', :saas do
        def resolve_in_new_request
          RequestStore.clear!
          client.secrets_manager_consumer_resolve(namespace_id: namespace_id)
        end

        def trial_in_new_request
          RequestStore.clear!
          client.secrets_manager_trial(namespace_id: namespace_id)
        end

        it 'makes the next resolve reach CDot instead of the cached verdict' do
          2.times { resolve_in_new_request }
          expect(Gitlab::HTTP).to have_received(:get).with(resolve_url, anything).once

          client.expire_secrets_manager_cache(namespace_id: namespace_id)
          resolve_in_new_request

          expect(Gitlab::HTTP).to have_received(:get).with(resolve_url, anything).twice
        end

        it 'expires the trials entry as well' do
          2.times { trial_in_new_request }
          expect(Gitlab::HTTP).to have_received(:get).with(trials_url, anything).once

          client.expire_secrets_manager_cache(namespace_id: namespace_id)
          trial_in_new_request

          expect(Gitlab::HTTP).to have_received(:get).with(trials_url, anything).twice
        end

        it 'clears the current request memo, not only the cross-request cache' do
          client.secrets_manager_consumer_resolve(namespace_id: namespace_id)
          client.expire_secrets_manager_cache(namespace_id: namespace_id)
          client.secrets_manager_consumer_resolve(namespace_id: namespace_id)

          expect(Gitlab::HTTP).to have_received(:get).with(resolve_url, anything).twice
        end

        it 'leaves other namespaces cached' do
          resolve_in_new_request
          client.expire_secrets_manager_cache(namespace_id: namespace_id + 1)
          resolve_in_new_request

          expect(Gitlab::HTTP).to have_received(:get).with(resolve_url, anything).once
        end
      end

      context 'on self-managed with an online cloud license' do
        let(:license) { instance_double(::License, checksum: 'checksum-deadbeef') }

        before do
          allow(::Gitlab).to receive(:com?).and_return(false)
          allow(::License).to receive(:current).and_return(license)
        end

        it 'expires the instance-keyed entry' do
          2.times do
            RequestStore.clear!
            client.secrets_manager_consumer_resolve(instance_id: instance_id)
          end
          expect(Gitlab::HTTP).to have_received(:get).with(resolve_url, anything).once

          client.expire_secrets_manager_cache(instance_id: instance_id)
          RequestStore.clear!
          client.secrets_manager_consumer_resolve(instance_id: instance_id)

          expect(Gitlab::HTTP).to have_received(:get).with(resolve_url, anything).twice
        end
      end
    end

    describe 'secrets_manager_* identifier env contract' do
      shared_examples 'rejects off-env identifiers on gitlab.com' do |method|
        it 'raises when no identifier is given' do
          expect { client.public_send(method) }
            .to raise_error(ArgumentError, /gitlab\.com requires namespace_id/)
        end

        it 'raises when only instance_id is given' do
          expect { client.public_send(method, instance_id: 'x') }
            .to raise_error(ArgumentError, /gitlab\.com requires namespace_id/)
        end

        it 'raises when both identifiers are given' do
          expect { client.public_send(method, namespace_id: 1, instance_id: 'x') }
            .to raise_error(ArgumentError, /gitlab\.com requires namespace_id/)
        end
      end

      shared_examples 'rejects off-env identifiers on self-managed' do |method|
        before do
          allow(::Gitlab).to receive(:com?).and_return(false)
          allow(::License).to receive(:current).and_return(
            instance_double(::License, checksum: 'checksum-deadbeef')
          )
        end

        it 'raises when no identifier is given' do
          expect { client.public_send(method) }
            .to raise_error(ArgumentError, /self-managed requires instance_id/)
        end

        it 'raises when only namespace_id is given' do
          expect { client.public_send(method, namespace_id: 1) }
            .to raise_error(ArgumentError, /self-managed requires instance_id/)
        end

        it 'raises when both identifiers are given' do
          expect { client.public_send(method, namespace_id: 1, instance_id: 'x') }
            .to raise_error(ArgumentError, /self-managed requires instance_id/)
        end
      end

      it_behaves_like 'rejects off-env identifiers on gitlab.com', :secrets_manager_trial
      it_behaves_like 'rejects off-env identifiers on gitlab.com', :secrets_manager_consumer_resolve
      it_behaves_like 'rejects off-env identifiers on self-managed', :secrets_manager_trial
      it_behaves_like 'rejects off-env identifiers on self-managed', :secrets_manager_consumer_resolve
    end
  end
end
