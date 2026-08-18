# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Virtual Registries Packages Maven', :api, :js, feature_category: :virtual_registry do
  include_context 'file upload requests helpers'
  include_context 'with a server running the dependency proxy'

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

  let_it_be(:external_server) do
    handler = ->(env) do
      if env['REQUEST_PATH'] == '/com/test/package/1.2.3/package-1.2.3.pom' # rubocop:disable RSpec/AvoidConditionalStatements -- This is a lambda for the external server
        [200, { 'Content-Type' => 'text/plain', 'ETag' => '"etag"' }, ['File contents']]
      else
        [404, {}, []]
      end
    end

    run_server(handler)
  end

  let(:api_path) { "/virtual_registries/packages/maven/#{registry.id}/com/test/package/1.2.3/package-1.2.3.pom" }
  let(:url) { capybara_url(api(api_path)) }
  let(:authorization) do
    ActionController::HttpAuthentication::Basic.encode_credentials(user.username, personal_access_token.token)
  end

  subject(:request) { HTTParty.get(url, headers: { authorization: authorization }) }

  before do
    upstream.update_column(:url, external_server.base_url) # avoids guard that rejects local urls
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)
    allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!)
      .and_wrap_original do |original, url, **kwargs|
        original.call(url, **kwargs.merge(allow_localhost: true, allow_local_network: true))
      end
  end

  context 'with no cache entry' do
    it 'returns the file contents and create the cache entry' do
      expect { request }.to change { upstream.cache_entries.count }.by(1)
      expect_headers(request)
    end

    context 'with multiple upstreams' do
      let_it_be(:upstream2, freeze: false) do
        create(:virtual_registries_packages_maven_upstream, registries: [registry])
      end

      let_it_be(:external_server2) do
        handler = ->(env) do
          if env['REQUEST_PATH'] == '/com/test/package/1.2.4/package-1.2.4.pom' # rubocop:disable RSpec/AvoidConditionalStatements -- This is a lambda for the external server
            [200, { 'Content-Type' => 'text/plain', 'ETag' => '"etag"' }, ['File contents 2']]
          else
            [404, {}, []]
          end
        end

        run_server(handler)
      end

      let(:api_path) { "/virtual_registries/packages/maven/#{registry.id}/com/test/package/1.2.4/package-1.2.4.pom" }

      before do
        upstream2.update_column(:url, external_server2.base_url) # avoids guard that rejects local urls
      end

      it 'returns the file contents and create the cache entry' do
        expect { request }.to change { upstream2.cache_entries.count }.by(1)
          .and not_change { upstream.cache_entries.count }
        expect(request.body).to eq('File contents 2')
        expect_headers(request)
      end
    end
  end

  context 'with a cache entry' do
    let_it_be_with_reload(:cache_entry) do
      create(
        :virtual_registries_packages_maven_cache_remote_entry,
        :upstream_checked,
        upstream: upstream,
        relative_path: '/com/test/package/1.2.3/package-1.2.3.pom',
        content_type: 'text/plain',
        upstream_etag: '"etag"'
      )
    end

    it 'returns the file contents from the cache' do
      expect(::Gitlab::HTTP).not_to receive(:head)
      expect { request }.not_to change { upstream.cache_entries.count }
      expect(request.headers[::API::VirtualRegistries::Packages::Maven::Endpoints::SHA1_CHECKSUM_HEADER])
        .to be_an_instance_of(String)
      expect(request.headers[::API::VirtualRegistries::Packages::Maven::Endpoints::MD5_CHECKSUM_HEADER])
        .to be_an_instance_of(String)
      expect_headers(request)
    end

    context 'with a stale cache entry' do
      before do
        cache_entry.update_column(:upstream_checked_at, 2.days.ago)
      end

      it 'returns the file contents and refresh the cache entry' do
        expect(::Gitlab::HTTP).to receive(:head).and_call_original

        expect { request }.to not_change { upstream.cache_entries.count }
          .and change { cache_entry.reload.upstream_checked_at }
        expect_headers(request)
      end

      context 'with a wrong etag' do
        before do
          cache_entry.update_column(:upstream_etag, 'wrong')
        end

        it 'returns the file contents and updates the cache entry' do
          expect(::Gitlab::HTTP).to receive(:head).and_call_original

          expect { request }.to not_change { upstream.cache_entries.count }
            .and change { cache_entry.reload.upstream_checked_at }
            .and change { cache_entry.reload.upstream_etag }.from('wrong').to('"etag"')
          expect_headers(request)
        end
      end
    end
  end

  def expect_headers(request)
    expect(request.headers['Content-Security-Policy'])
      .to eq("sandbox; default-src 'none'; require-trusted-types-for 'script'")
    expect(request.headers['X-Content-Type-Options']).to eq('nosniff')
    expect(request.headers['Content-Disposition']).to include('attachment')
  end
end
