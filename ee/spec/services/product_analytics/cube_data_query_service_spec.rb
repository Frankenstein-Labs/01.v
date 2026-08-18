# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::CubeDataQueryService, feature_category: :product_analytics do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:current_user) { create(:user) }
  let(:cube_api_load_url) { "http://cube.dev/cubejs-api/v1/load" }
  let(:cube_api_dry_run_url) { "http://cube.dev/cubejs-api/v1/dry-run" }
  let(:cube_api_meta_url) { "http://cube.dev/cubejs-api/v1/meta" }
  let(:query) { { query: { measures: ['TrackedEvents.count'] }, queryType: 'multi' } }
  let(:cube_data) { '{ "results": [] }' }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }
  let(:allow_local_requests) { false }

  let(:request_meta) do
    described_class.new(container: project, current_user: current_user, params: { path: 'meta' }).execute
  end

  before do
    project.add_owner(current_user)
    stub_feature_flags(product_analytics_billing: false, product_analytics_billing_override: false)
  end

  shared_examples 'a not found error' do
    it 'load returns a 404' do
      response = request_load(false)

      expect(response.reason).to eq(:not_found)
    end

    it 'dry-run returns a 404' do
      response = request_load(true)

      expect(response.reason).to eq(:not_found)
    end

    it 'meta returns a 404' do
      response = request_meta

      expect(response.reason).to eq(:not_found)
    end
  end

  shared_examples 'does basics of a cube query' do |is_dry_run: false|
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(product_analytics_features: false)
      end

      it_behaves_like 'a not found error'
    end

    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(product_analytics: false)
      end

      it_behaves_like 'a not found error'
    end

    context 'when product analytics billing is enabled' do
      before do
        stub_feature_flags(product_analytics_billing: project.root_ancestor)
      end

      context 'when product_analytics add on is not purchased' do
        it 'returns an unauthorized error' do
          response = request_load(is_dry_run)

          expect(response.reason).to eq(:unauthorized)
        end
      end

      context 'when product_analytics add on has been purchased' do
        before do
          create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: group, add_on: add_on)
        end

        it 'allows the query' do
          response = request_load(is_dry_run)
          expect(response.success?).to be_truthy
        end
      end

      context 'when user brings their own cluster' do
        before do
          stub_application_setting(product_analytics_data_collector_host: 'https://my-data-collector.customer-xyz.com')
        end

        it 'allows the query' do
          response = request_load(is_dry_run)
          expect(response.success?).to be_truthy
        end
      end
    end

    context 'when current user has guest project access' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_guest(current_user)
      end

      it 'returns an unauthorized error' do
        response = request_load(is_dry_run)

        expect(response.reason).to eq(:unauthorized)
      end
    end

    context 'when current user is a project developer' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_developer(current_user)
      end

      it 'returns a 200' do
        response = request_load(is_dry_run)

        expect(response.success?).to be_truthy
      end

      context 'when a query param is unsupported' do
        let(:query) { { query: { measures: ['TrackedEvents.count'] }, queryType: 'multi', badParam: 1 } }

        it 'ignores the unsupported param' do
          response = request_load(is_dry_run)

          expect(response.success?).to be_truthy
        end
      end

      context 'when invalid JSON is returned' do
        let(:cube_data) { "INVALID JSON" }

        it 'returns an error' do
          response = request_load(is_dry_run)

          expect(response.reason).to eq(:bad_gateway)
        end
      end
    end
  end

  shared_examples 'no resource access token is generated' do
    it 'does not generate any project access tokens' do
      expect(::ResourceAccessTokens::CreateService).not_to receive(:new)
      request_load(false)
    end
  end

  shared_examples 'a resource access token is generated' do
    it 'generates a project access tokens' do
      expect(::ResourceAccessTokens::CreateService).to receive(:new).once.and_call_original
      request_load(false)
    end
  end

  shared_examples 'correctly handles local URLs' do |is_dry_run: false|
    let(:cube_api_load_url) { "http://localhost/cubejs-api/v1/load" }
    let(:cube_api_dry_run_url) { "http://localhost/cubejs-api/v1/dry-run" }

    before do
      stub_application_setting(allow_local_requests_from_web_hooks_and_services: allow_local_requests)
      stub_ee_application_setting(cube_api_base_url: 'http://localhost')
    end

    context 'when the admin setting does not allow local requests' do
      let(:allow_local_requests) { false }

      before do
        allow(Gitlab::HTTP_V2::UrlBlocker)
          .to receive(:validate!)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
      end

      it 'returns an error' do
        expect { request_load(is_dry_run) }.to raise_error(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
      end
    end

    context 'when the admin setting allows local requests' do
      let(:allow_local_requests) { true }

      before do
        allow(Gitlab::HTTP_V2::UrlBlocker)
          .to receive(:validate!)
          .and_return(
            [
              Addressable::URI.parse('http://localhost/cubejs-api/v1/load'),
              'http://localhost/cubejs-api/v1/load'
            ]
          )
      end

      it_behaves_like 'does basics of a cube query', is_dry_run: is_dry_run
    end
  end

  describe 'POST projects/:id/product_analytics/request/load' do
    before do
      stub_cube_proxy_setup
    end

    context 'when using a local URL' do
      before do
        stub_cube_load
      end

      it_behaves_like 'correctly handles local URLs', is_dry_run: false
    end

    context 'when Cube API is not responding' do
      before do
        stub_cube_not_connected
      end

      it 'returns connection refused' do
        response = request_load(false)

        expect(response.reason).to eq(:bad_gateway)
        expect(response.message).to include("Connection refused")
      end
    end

    context 'when querying a database that does not exist' do
      before do
        stub_cube_load_no_db
      end

      it 'returns a 404' do
        response = request_load(false)

        expect(response.reason).to eq(:not_found)
        expect(response.message).to eq("404 Clickhouse Database Not Found")
      end
    end

    context 'when querying with an invalid query' do
      before do
        stub_cube_load_invalid_query
      end

      it 'returns an error' do
        response = request_load(false)

        expect(response.reason).to eq(:bad_request)
        expect(response.message).to eq("Query is invalid")
      end
    end

    context 'when querying an existing database' do
      before do
        stub_cube_load
      end

      it_behaves_like 'does basics of a cube query', is_dry_run: false
      it_behaves_like 'no resource access token is generated'
    end

    context 'when requesting a project with a resource access token' do
      before do
        stub_cube_load
      end

      it_behaves_like 'a resource access token is generated' do
        let(:query) { { query: { measures: ['TrackedEvents.count'] }, queryType: 'multi', include_token: true } }
      end
    end

    context 'when querying a long running query' do
      before do
        stub_cube_load_continue_wait
      end

      it 'returns success and continue wait' do
        response = request_load(false)

        expect(response.success?).to be_truthy
        expect(response.message).to eq('Continue wait')
      end
    end
  end

  describe 'POST projects/:id/product_analytics/request/dry-run' do
    before do
      stub_cube_dry_run
      stub_cube_proxy_setup
    end

    it_behaves_like 'does basics of a cube query', is_dry_run: true
    it_behaves_like 'correctly handles local URLs', is_dry_run: true
  end

  describe 'POST projects/:id/product_analytics/request/meta' do
    before do
      stub_cube_meta
      stub_cube_proxy_setup
    end

    context 'when current user has guest project access' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_guest(current_user)
      end

      it 'returns an unauthorized error' do
        response = request_meta

        expect(response.reason).to eq(:unauthorized)
      end
    end

    context 'when current user is a project developer' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_developer(current_user)
      end

      it 'returns a 200' do
        response = request_meta

        expect(response.success?).to be_truthy
      end

      context 'when using a local URL' do
        let(:cube_api_meta_url) { "http://localhost/cubejs-api/v1/meta" }

        before do
          stub_ee_application_setting(cube_api_base_url: 'http://localhost')
        end

        context 'when the admin setting does not allow local requests' do
          before do
            allow(Gitlab::HTTP_V2::UrlBlocker)
              .to receive(:validate!)
              .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
          end

          it 'returns an error' do
            expect { request_meta }.to raise_error(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
          end
        end

        context 'when the admin setting allows local requests' do
          let(:allow_local_requests) { true }

          before do
            stub_application_setting(allow_local_requests_from_web_hooks_and_services: allow_local_requests)

            allow(Gitlab::HTTP_V2::UrlBlocker)
              .to receive(:validate!)
              .and_return(
                [
                  Addressable::URI.parse('http://localhost/cubejs-api/v1/meta'),
                  'http://localhost/cubejs-api/v1/meta'
                ]
              )
          end

          it 'returns a 200' do
            response = request_meta

            expect(response.success?).to be_truthy
          end
        end
      end
    end
  end

  private

  def request_load(is_dry_run)
    params = query.merge(path: is_dry_run ? 'dry-run' : 'load')
    described_class.new(container: project, current_user: current_user, params: params).execute
  end

  def stub_cube_proxy_setup
    stub_licensed_features(product_analytics: true)
    stub_ee_application_setting(product_analytics_enabled: true)
    stub_ee_application_setting(cube_api_key: 'testtest')
    stub_ee_application_setting(cube_api_base_url: 'http://cube.dev')
  end

  def allow_cube_api_post_request(expected_uri, return_body)
    allow(Gitlab::HTTP).to receive(:post) do |uri, options|
      expect(uri).to eq(URI.parse(expected_uri.to_s))
      expect(options[:allow_local_requests]).to eq(allow_local_requests)
      expect(options[:headers].keys).to match_array(%i[Content-Type Authorization])
      expect(options[:body]).to eq({ query: query[:query], queryType: query[:queryType] }.to_json)

      return_body
    end
  end

  def stub_cube_load
    allow_cube_api_post_request(
      cube_api_load_url,
      instance_double(
        HTTParty::Response,
        code: 201,
        success?: true,
        body: cube_data
      )
    )
  end

  def stub_cube_load_no_db
    msg = '{ "error": "Error: Code: 81. DB::Exception: Database gitlab_project_12 doesn\'t exist.' \
          '(UNKNOWN_DATABASE) (version 22.10.2.11 (official build))\n" }'

    allow_cube_api_post_request(
      cube_api_load_url,
      instance_double(
        HTTParty::Response,
        code: 400,
        success?: false,
        body: msg
      )
    )
  end

  def stub_cube_load_invalid_query
    allow_cube_api_post_request(
      cube_api_load_url,
      instance_double(
        HTTParty::Response,
        code: 200,
        success?: true,
        body: '{"error": "Query is invalid"}'
      )
    )
  end

  def stub_cube_load_continue_wait
    allow_cube_api_post_request(
      cube_api_load_url,
      instance_double(
        HTTParty::Response,
        code: 200,
        success?: true,
        body: '{"error": "Continue wait"}'
      )
    )
  end

  def stub_cube_dry_run
    allow_cube_api_post_request(
      cube_api_dry_run_url,
      instance_double(
        HTTParty::Response,
        code: 201,
        success?: true,
        body: cube_data
      )
    )
  end

  def stub_cube_meta
    allow(Gitlab::HTTP).to receive(:get) do |uri, options|
      expect(uri).to eq(URI.parse(cube_api_meta_url.to_s))
      expect(options[:allow_local_requests]).to eq(allow_local_requests)
      expect(options[:headers]).to be_a(Hash)
      instance_double(
        HTTParty::Response,
        code: 201,
        success?: true,
        body: cube_data
      )
    end
  end

  def stub_cube_not_connected
    allow(Gitlab::HTTP).to receive(:post).and_raise(Errno::ECONNREFUSED)
  end
end
