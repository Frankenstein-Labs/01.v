# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::Upstream, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }

  subject(:upstream) do
    build(
      :virtual_registries_container_upstream,
      username: 'testuser',
      password: 'testpassword',
      url: 'https://registry-1.docker.io',
      group: group
    )
  end

  describe 'associations', :aggregate_failures do
    it 'has many registry upstreams' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Container::RegistryUpstream')
        .inverse_of(:upstream)
        .autosave(true)
    end

    it 'has many registries' do
      is_expected.to have_many(:registries)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Container::Registry')
    end
  end

  describe 'validations', :aggregate_failures do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_length_of(:username).is_at_most(2048) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_length_of(:password).is_at_most(2048) }

    it { is_expected.to validate_length_of(:auth_url).is_at_most(512) }
    it { is_expected.not_to allow_value('').for(:auth_url) }

    # Use 172.21.11.1 (from the rarely-used 172.16.0.0/12 range)
    # to avoid matching a developer's machine IP and getting classified
    # as "localhost" instead of "local network" by the URL blocker
    describe '#auth_url validations' do
      where(:auth_url, :valid, :error_message) do
        'http://localhost:8080'        | false | 'Auth url is blocked: Requests to localhost are not allowed'
        'http://172.21.11.1'           | false | 'Auth url is blocked: Requests to the local network are not allowed'
        'https://example.com/<img src=x>'   | false | 'Auth url is blocked: HTML/CSS/JS tags are not allowed'
        'https://registry.example.com/auth' | true  | nil
      end

      with_them do
        subject(:upstream) { build(:virtual_registries_container_upstream, auth_url: auth_url) }

        if params[:valid]
          it { is_expected.to be_valid }
        else
          it 'has invalid errors' do
            is_expected.not_to be_valid
            expect(upstream.errors).to contain_exactly(error_message)
          end
        end
      end
    end

    context 'for credentials' do
      # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands -- false positive
      where(:username, :password, :valid, :error_message) do
        'user'      | 'password'   | true  | nil
        ''          | ''           | true  | nil
        ''          | nil          | true  | nil
        nil         | ''           | true  | nil
        nil         | 'password'   | false | "Username can't be blank"
        'user'      | nil          | false | "Password can't be blank"
        ''          | 'password'   | false | "Username can't be blank"
        'user'      | ''           | false | "Password can't be blank"
        ('a' * 2049) | 'password'    | false | 'Username is too long (maximum is 2048 characters)'
        'user'       | ('a' * 2049)  | false | 'Password is too long (maximum is 2048 characters)'
      end
      # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands

      with_them do
        before do
          upstream.username = username
          upstream.password = password
        end

        if params[:valid]
          it { is_expected.to be_valid }
        else
          it { is_expected.to be_invalid.and have_attributes(errors: match_array(Array.wrap(error_message))) }
        end
      end

      context 'when url is updated' do
        where(:new_url, :new_user, :new_pwd, :expected_user, :expected_pwd) do
          'http://original_url.test' | 'test' | 'test' | 'test' | 'test'
          'http://update_url.test'   | 'test' | 'test' | 'test' | 'test'
          'http://update_url.test'   | :none  | :none  | nil    | nil
          'http://update_url.test'   | 'test' | :none  | nil    | nil
          'http://update_url.test'   | :none  | 'test' | nil    | nil
        end

        with_them do
          before do
            upstream.update!(url: 'http://original_url.test', username: 'original_user', password: 'original_pwd')
          end

          it 'resets the username and the password when necessary' do
            new_attributes = { url: new_url, username: new_user, password: new_pwd }.select { |_, v| v != :none }
            upstream.update!(new_attributes)

            expect(upstream.reload).to have_attributes(
              url: new_url,
              username: expected_user,
              password: expected_pwd
            )
          end
        end
      end
    end

    describe '#credentials_uniqueness_for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group2) { create(:group) }
      let_it_be(:existing_upstream) do
        create(
          :virtual_registries_container_upstream,
          group: group,
          url: 'https://example.com',
          username: 'user',
          password: 'pass'
        )
      end

      where(:test_group, :url, :username, :password, :valid, :description) do
        ref(:group)  | 'https://example.com'   | 'user'      | 'pass'      | false | 'same group, same credentials'
        ref(:group)  | 'https://example.com'   | 'user'      | 'different' | true  | 'same group, different password'
        ref(:group)  | 'https://example.com'   | 'different' | 'pass'      | true  | 'same group, different username'
        ref(:group)  | 'https://different.com' | 'user'      | 'pass'      | true  | 'same group, different URL'
        ref(:group2) | 'https://example.com'   | 'user'      | 'pass'      | true  | 'different group, same credentials'
      end

      with_them do
        context 'when creating new upstream' do
          subject do
            build(
              :virtual_registries_container_upstream,
              group: test_group,
              url: url,
              username: username,
              password: password
            )
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              is_expected.to be_invalid
                .and have_attributes(errors: match_array(['Group already has an upstream with the same credentials']))
            end
          end
        end

        context 'when updating existing upstream' do
          let_it_be(:updated_upstream, freeze: false) do
            create(
              :virtual_registries_container_upstream,
              group: group,
              url: 'https://example2.com',
              username: 'user',
              password: 'pass'
            )
          end

          subject { updated_upstream }

          before do
            updated_upstream.assign_attributes(group: test_group, url: url, username: username, password: password)
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when updating to #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              is_expected.to be_invalid
                .and have_attributes(errors: match_array(['Group already has an upstream with the same credentials']))
            end
          end
        end
      end
    end
  end

  describe 'scopes' do
    describe '.search_by_name' do
      let(:query) { 'abc' }
      let_it_be(:name) { 'name-abc' }
      let_it_be(:upstream, freeze: false) { create(:virtual_registries_container_upstream, name: name) }
      let_it_be(:other_upstream) { create(:virtual_registries_container_upstream) }

      subject { described_class.search_by_name(query) }

      it { is_expected.to eq([upstream]) }
    end
  end

  it_behaves_like 'virtual registry upstream scopes',
    registry_factory: :virtual_registries_container_registry,
    upstream_factory: :virtual_registries_container_upstream

  describe '#as_json' do
    subject { upstream.as_json }

    it { is_expected.not_to include('password') }
    it { is_expected.not_to include('auth_url') }
  end

  describe '#object_storage_key' do
    let_it_be(:upstream) { build_stubbed(:virtual_registries_container_upstream) }

    it_behaves_like 'virtual registries: has object storage key', key_prefix: 'container'
  end

  it_behaves_like 'virtual registry upstream common behavior'

  describe '#local?' do
    subject { upstream.local? }

    it { is_expected.to be false }
  end

  describe '#remote?' do
    subject { upstream.remote? }

    it { is_expected.to be true }
  end

  describe '#url_for' do
    subject { upstream.url_for(path) }

    where(:path, :expected_url) do
      'library/alpine/manifests/latest'     | 'https://registry-1.docker.io/v2/library/alpine/manifests/latest'
      'nginx/nginx/tags/list'               | 'https://registry-1.docker.io/v2/nginx/nginx/tags/list'
      ''                                    | 'https://registry-1.docker.io/v2/'
      '/library/alpine/manifests/latest'    | 'https://registry-1.docker.io/v2/library/alpine/manifests/latest'
      '/project/app/blobs/sha256:abc123'    | 'https://registry-1.docker.io/v2/project/app/blobs/sha256:abc123'
    end

    with_them do
      before do
        upstream.url = 'https://registry-1.docker.io'
      end

      it { is_expected.to eq(expected_url) }
    end

    context 'with URL edge cases' do
      where(:registry_url, :path, :expected_url) do
        'https://registry.example.com/'    | 'alpine/manifests/latest' | 'https://registry.example.com/v2/alpine/manifests/latest'
        'https://registry.example.com/v2'  | 'alpine/manifests/latest' | 'https://registry.example.com/v2/alpine/manifests/latest'
        'https://registry.example.com/v2/' | 'alpine/manifests/latest' | 'https://registry.example.com/v2/alpine/manifests/latest'
      end

      with_them do
        before do
          upstream.url = registry_url
        end

        it { is_expected.to eq(expected_url) }
      end
    end
  end

  describe '#headers' do
    let_it_be_with_reload(:upstream) do
      create(:virtual_registries_container_upstream,
        group: group,
        url: 'https://registry-1.docker.io',
        username: 'testuser',
        password: 'testpassword'
      )
    end

    let(:basis_auth_header) { { 'Authorization' => 'Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk' } }
    let(:path) { 'library/alpine/manifests/latest' }

    subject(:headers) { upstream.headers(path) }

    shared_examples 'handle blank path' do
      where(:path) do
        [
          [nil],
          ['']
        ]
      end

      with_them do
        let(:request_auth_url) { 'https://auth.docker.io/token?service=registry.docker.io' }
        let(:auth_url) { 'https://auth.docker.io/token?service=registry.docker.io' }

        before do
          # Stub the authentication discovery request (Layer 1 discovery)
          stub_request(:head, "#{upstream.url}/v2")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io"'
            }
          )

          # Stub the token exchange request (Layer 1 authentication)
          stub_request(:get, request_auth_url)
            .to_return(
              status: 200,
              body: '{"token": "successful_bearer_token_123"}'
            )
        end

        it { is_expected.to eq(with_accept_headers({ 'Authorization' => 'Bearer successful_bearer_token_123' })) }
      end
    end

    shared_examples 'update auth_url' do
      it 'updates auth_url' do
        headers

        expect(upstream.auth_url).to eq(auth_url)
      end

      context 'when auth_url has existed' do
        before do
          upstream.update!(auth_url: auth_url)
        end

        it_behaves_like 'does not update auth_url'
      end
    end

    shared_examples 'does not update auth_url' do
      it 'does not update auth_url' do
        expect { headers }.not_to change { upstream.auth_url }
      end
    end

    shared_examples 'returns Accept-only headers' do
      it { is_expected.to eq(with_accept_headers({})) }
    end

    shared_examples 'reset auth_url' do
      context 'when saved auth_url responses with not found' do
        let(:saved_auth_url) { 'https://auth-saved.docker.io/token?service=registry.docker.io' }
        let(:retry_auth_url) { 'https://auth-retry.docker.io/token?service=registry.docker.io' }

        let(:request_saved_auth_url) { 'https://auth-saved.docker.io/token?scope=repository:library/alpine:pull&service=registry.docker.io' }
        let(:request_retry_auth_url) { 'https://auth-retry.docker.io/token?scope=repository:library/alpine:pull&service=registry.docker.io' }

        before do
          upstream.update!(auth_url: saved_auth_url)

          stub_request(:head, "#{upstream.url}/v2/#{path}")
            .to_return({
              status: 401,
              headers: {
                'www-authenticate' => 'Bearer realm="https://auth-retry.docker.io/token",service="registry.docker.io"'
              }
            })

          stub_request(:get, request_saved_auth_url).to_return(status: 404, body: '{}')
          stub_request(:get, request_retry_auth_url).to_return(
            status: 200, body: '{"token": "successful_bearer_token_123"}'
          )
        end

        it 'updates auth_url with retry_auth_url' do
          headers

          expect(upstream.auth_url).to eq(retry_auth_url)
        end

        context 'when request to retry_auth_url responses with not found' do
          before do
            stub_request(:get, request_retry_auth_url).to_return(status: 404, body: '{}')
          end

          it 'leaves auth_url as nil' do
            headers

            expect(upstream.auth_url).to be_nil
          end
        end

        context 'when fetching auth url failed' do
          before do
            stub_request(:head, "#{upstream.url}/v2/#{path}").to_return({ status: 404 })
          end

          it 'leaves auth_url as nil' do
            headers

            expect(upstream.auth_url).to be_nil
          end
        end
      end
    end

    context 'without credentials' do
      let(:request_auth_url) { 'https://auth.docker.io/token?scope=repository:library/alpine:pull&service=registry.docker.io' }
      let(:auth_url) { 'https://auth.docker.io/token?service=registry.docker.io' }

      # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands -- binary operator is used in parameterized table
      where(:username, :password) do
        nil  |  nil
        ''   |  ''
      end
      # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands

      with_them do
        before do
          upstream.update!(username: username, password: password)

          # Stub the authentication discovery request (Layer 1 discovery)
          stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

          # Stub the token exchange request (Layer 1 authentication)
          stub_request(:get, request_auth_url)
            .to_return(
              status: 200,
              body: '{"token": "successful_bearer_token_123"}'
            )
        end

        it_behaves_like 'update auth_url'
        it_behaves_like 'reset auth_url'
        it_behaves_like 'handle blank path'

        it { is_expected.to eq(with_accept_headers({ 'Authorization' => 'Bearer successful_bearer_token_123' })) }
      end
    end

    context 'with credentials and successful authentication' do
      let(:request_auth_url) { 'https://auth.docker.io/token?scope=repository:library/alpine:pull&service=registry.docker.io' }
      let(:auth_url) { 'https://auth.docker.io/token?service=registry.docker.io' }

      before do
        # Stub the authentication discovery request (Layer 1 discovery)
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

        # Stub the token exchange request (Layer 1 authentication)
        stub_request(:get, request_auth_url).with(headers: basis_auth_header)
          .to_return(
            status: 200,
            body: '{"token": "successful_bearer_token_123"}'
          )
      end

      it_behaves_like 'update auth_url'
      it_behaves_like 'reset auth_url'
      it_behaves_like 'handle blank path'

      it { is_expected.to eq(with_accept_headers({ 'Authorization' => 'Bearer successful_bearer_token_123' })) }
    end

    context 'with non-persisted upstream' do
      let(:upstream) do
        build(:virtual_registries_container_upstream,
          group: group,
          url: 'https://registry-1.docker.io',
          username: 'testuser',
          password: 'testpassword'
        )
      end

      let(:request_auth_url) { 'https://auth.docker.io/token?scope=repository:library/alpine:pull&service=registry.docker.io' }
      let(:auth_url) { 'https://auth.docker.io/token?service=registry.docker.io' }

      before do
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

        stub_request(:get, request_auth_url).with(headers: basis_auth_header)
          .to_return(
            status: 200,
            body: '{"token": "successful_bearer_token_123"}'
          )
      end

      it 'returns correct headers and does not persist auth_url' do
        expect(headers).to eq(with_accept_headers({ 'Authorization' => 'Bearer successful_bearer_token_123' }))
        expect(upstream.auth_url).to be_nil
      end

      context 'when authentication fails' do
        before do
          stub_request(:get, request_auth_url).with(headers: basis_auth_header)
            .to_return(status: 401, body: '{"error": "unauthorized"}')
        end

        it 'returns Accept-only headers and does not persist auth_url' do
          expect(headers).to eq(with_accept_headers({}))
          expect(upstream.auth_url).to be_nil
        end
      end

      context 'when stale auth_url needs retry' do
        let(:upstream) do
          build(:virtual_registries_container_upstream,
            group: group,
            url: 'https://registry-1.docker.io',
            username: 'testuser',
            password: 'testpassword',
            auth_url: 'https://stale-auth.docker.io/token?service=registry.docker.io'
          )
        end

        before do
          stub_request(:get, 'https://stale-auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
            .to_return(status: 404)

          stub_request(:head, "#{upstream.url}/v2/#{path}")
            .to_return(
              status: 401,
              headers: {
                'www-authenticate' => 'Bearer realm="https://fresh-auth.docker.io/token",service="registry.docker.io"'
              }
            )

          stub_request(:get, 'https://fresh-auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
            .to_return(status: 200, body: '{"token": "fresh_token"}')
        end

        it 'retries with fresh auth and leaves auth_url unchanged' do
          expect(headers).to eq(with_accept_headers({ 'Authorization' => 'Bearer fresh_token' }))
          expect(upstream.auth_url).to eq('https://stale-auth.docker.io/token?service=registry.docker.io')
        end
      end
    end

    context 'with credentials but authentication discovery fails' do
      before do
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(status: 200)
      end

      it_behaves_like 'does not update auth_url'
      it_behaves_like 'returns Accept-only headers'
    end

    context 'with credentials but token exchange fails' do
      before do
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

        stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
          .with(headers: basis_auth_header)
          .to_return(status: 401, body: '{"error": "invalid_credentials"}')
      end

      it_behaves_like 'does not update auth_url'
      it_behaves_like 'returns Accept-only headers'
    end

    context 'with different registry types' do
      let(:request_auth_url) { "#{auth_realm}?scope=#{CGI.escape(scope)}&service=#{service_name}" }
      let(:auth_url) { "#{auth_realm}?service=#{service_name}" }

      let(:scope) { 'repository:library/alpine:pull' }

      # rubocop:disable Layout/LineLength -- have the params in the same line for readability
      where(:registry_url, :auth_realm, :service_name, :expected_token) do
        'https://registry-1.docker.io' | 'https://auth.docker.io/token'      | 'registry.docker.io'  | 'dockerhub_bearer_token'
        'https://gcr.io'               | 'https://gcr.io/v2/token'           | 'gcr.io'              | 'gcr_bearer_token'
        'https://public.ecr.aws'       | 'https://public.ecr.aws/token'      | 'public.ecr.aws'      | 'ecr_bearer_token'
        'https://quay.io'              | 'https://quay.io/v2/auth'           | 'quay.io'             | 'quay_bearer_token'
        'https://harbor.example.com'   | 'https://harbor.example.com/service/token' | 'harbor.example.com' | 'harbor_bearer_token'
      end
      # rubocop:enable Layout/LineLength

      with_them do
        before do
          upstream.update_column(:url, registry_url)

          # Stub auth discovery for each registry type
          stub_request(:head, "#{registry_url}/v2/#{path}")
            .to_return(
              status: 401,
              headers: {
                'www-authenticate' => "Bearer realm=\"#{auth_realm}\",service=\"#{service_name}\",scope=\"#{scope}\""
              }
            )

          # Stub token exchange for each registry type
          stub_request(:get, request_auth_url).with(headers: basis_auth_header)
            .to_return(
              status: 200,
              body: "{\"token\": \"#{expected_token}\"}"
            )
        end

        it_behaves_like 'update auth_url'

        it 'successfully authenticates with different registry types' do
          expect(headers).to eq(with_accept_headers({ 'Authorization' => "Bearer #{expected_token}" }))
        end
      end
    end

    context 'with network error scenarios' do
      context 'with auth discovery network errors' do
        before do
          stub_request(:head, "#{upstream.url}/v2/#{path}")
            .to_raise(Errno::ECONNREFUSED.new('Network timeout'))
        end

        it_behaves_like 'does not update auth_url'
        it_behaves_like 'returns Accept-only headers'
      end

      context 'with token exchange network errors' do
        before do
          # Successful auth discovery
          stub_request(:head, "#{upstream.url}/v2/#{path}")
            .to_return(
              status: 401,
              headers: {
                'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
              }
            )

          # Failed token exchange
          stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
            .to_raise(SocketError.new('Auth service unavailable'))
        end

        it_behaves_like 'returns Accept-only headers'
      end

      context 'with invalid JSON token response' do
        before do
          # Successful auth discovery
          stub_request(:head, "#{upstream.url}/v2/#{path}")
            .to_return(
              status: 401,
              headers: {
                'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
              }
            )

          # Token exchange with invalid JSON
          stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
            .to_return(status: 200, body: 'invalid json response')
        end

        it_behaves_like 'returns Accept-only headers'
      end
    end

    context 'with malformed auth challenges' do
      let(:request_auth_url) { 'https://auth.docker.io/token?scope=repository:library/alpine:pull&service=registry.docker.io' }
      let(:auth_url) { 'https://auth.docker.io/token?service=registry.docker.io' }

      before do
        stub_request(:head, "#{upstream.url}/v2/#{path}")
                    .to_return(
                      status: 401,
                      headers: { 'www-authenticate' => auth_header }
                    )

        stub_request(:get, request_auth_url).to_return(status: 200, body: '{"token": "valid_token"}') unless should_fail
      end

      where(:auth_header, :should_fail) do
        'Basic realm="test"' | true
        'Bearer invalid_format'                                | true
        'Bearer realm="https://auth.example.com/token"'        | true  # Missing service
        'Bearer service="registry.example.com"'                | true  # Missing realm
        'Bearer realm="https://auth.docker.io/token",service="registry.docker.io"' | false # Valid
      end

      with_them do
        if params[:should_fail]
          it_behaves_like 'does not update auth_url'
          it_behaves_like 'returns Accept-only headers'
        else
          it_behaves_like 'update auth_url'

          it 'processes valid auth challenges successfully' do
            expect(headers).to eq(with_accept_headers({ 'Authorization' => 'Bearer valid_token' }))
          end
        end
      end
    end

    context 'without scope parameter' do
      let(:request_auth_url) { 'https://auth.docker.io/token?scope=repository:library/alpine:pull&service=registry.docker.io' }
      let(:auth_url) { 'https://auth.docker.io/token?service=registry.docker.io' }

      before do
        # Auth discovery without scope
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io"'
            }
          )

        # Token exchange without scope parameter
        stub_request(:get, request_auth_url).with(headers: basis_auth_header)
          .to_return(
            status: 200,
            body: '{"access_token": "no_scope_token"}'
          )
      end

      it_behaves_like 'update auth_url'

      it 'handles authentication without scope parameter' do
        expect(headers).to eq(with_accept_headers({ 'Authorization' => 'Bearer no_scope_token' }))
      end
    end
  end

  describe 'RESOURCE_SUFFIX_REGEX' do
    subject(:repository_name) { path.sub(described_class::RESOURCE_SUFFIX_REGEX, '') }

    where(:path, :expected_repository) do
      'library/alpine/manifests/latest'                                               | 'library/alpine'
      'library/alpine/blobs/sha256:abc123'                                            | 'library/alpine'
      'library/alpine/tags/list'                                                      | 'library/alpine'
      "library/alpine/referrers/sha256:#{'a' * 64}"                                  | 'library/alpine'
      "project/app/referrers/sha256:#{'b' * 64}"                                     | 'project/app'
    end

    with_them do
      it { is_expected.to eq(expected_repository) }
    end
  end

  describe '#headers with referrers path' do
    let_it_be_with_reload(:upstream) do
      create(:virtual_registries_container_upstream,
        group: group,
        url: 'https://registry-1.docker.io',
        username: 'testuser',
        password: 'testpassword'
      )
    end

    let(:digest) { "sha256:#{'a' * 64}" }
    let(:path) { "library/alpine/referrers/#{digest}" }
    let(:request_auth_url) { 'https://auth.docker.io/token?scope=repository:library/alpine:pull&service=registry.docker.io' }

    before do
      stub_request(:head, "#{upstream.url}/v2/#{path}")
        .to_return(
          status: 401,
          headers: {
            'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
          }
        )

      stub_request(:get, request_auth_url)
        .to_return(status: 200, body: '{"token": "referrers_bearer_token"}')
    end

    it 'produces a correctly scoped token request for referrers paths' do
      result = upstream.headers(path)

      expect(result['Authorization']).to eq('Bearer referrers_bearer_token')
    end
  end

  describe '#default_cache_entries' do
    let_it_be(:upstream, freeze: false) { create(:virtual_registries_container_upstream) }
    let_it_be(:default_cache_entry, freeze: false) do
      create(:virtual_registries_container_cache_remote_entry, upstream:)
    end

    let_it_be(:pending_destruction_cache_entry) do
      create(:virtual_registries_container_cache_remote_entry, :pending_destruction, upstream:)
    end

    subject { upstream.default_cache_entries }

    it { is_expected.to contain_exactly(default_cache_entry) }
  end

  describe '#test' do
    let(:test_url) { upstream.url_for(described_class::TEST_PATH) }
    let(:response) { ActiveSupport::OrderedOptions.new }
    let(:code) { 200 }
    let(:message) { 'OK' }

    subject(:test) { upstream.test }

    before do
      allow(Gitlab::HTTP).to receive(:head) do
        response.code = code
        response.message = message
        response
      end
    end

    it 'makes a HEAD request to the test endpoint' do
      test

      expect(Gitlab::HTTP).to have_received(:head).with(
        test_url,
        headers: upstream.headers(described_class::TEST_PATH),
        follow_redirects: true
      )
    end

    context 'with different HTTP response codes' do
      where(:code, :message, :expected_result) do
        200 | 'OK'                    | { success: true }
        201 | 'Created'               | { success: true }
        299 | 'Misc Success'          | { success: true }
        404 | 'Not Found'             | { success: true }
        400 | 'Bad Request'           | { success: false, result: 'Error: 400 - Bad Request' }
        401 | 'Unauthorized'          | { success: false, result: 'Error: 401 - Unauthorized' }
        403 | 'Forbidden'             | { success: false, result: 'Error: 403 - Forbidden' }
        500 | 'Internal Server Error' | { success: false, result: 'Error: 500 - Internal Server Error' }
      end

      with_them do
        it { is_expected.to eq(expected_result) }
      end
    end

    context 'when HTTP errors occur' do
      where(:error_class, :error_message) do
        Net::OpenTimeout | 'Connection timeout'
        SocketError      | 'getaddrinfo: Name or service not known'
      end

      before do
        allow(Gitlab::HTTP).to receive(:head).and_raise(error_class, error_message)
      end

      with_them do
        it { is_expected.to eq({ success: false, result: "Error: #{error_message}" }) }
      end
    end

    context 'with credentials' do
      context 'with username and password' do
        let(:bearer_headers) { with_accept_headers({ 'Authorization' => 'Bearer test_bearer_token' }) }

        before do
          upstream.assign_attributes(username: 'testuser', password: 'testpass')

          allow(upstream).to receive(:headers).and_call_original
          allow(upstream).to receive(:headers).with(described_class::TEST_PATH).and_return(bearer_headers)
        end

        it 'uses bearer token authentication' do
          test

          expect(Gitlab::HTTP).to have_received(:head).with(
            test_url,
            headers: bearer_headers,
            follow_redirects: true
          )
        end
      end

      context 'without credentials' do
        before do
          upstream.assign_attributes(username: nil, password: nil)
          allow(upstream).to receive(:headers).with(described_class::TEST_PATH).and_return({})
        end

        it 'makes request without authorization header' do
          test

          expect(Gitlab::HTTP).to have_received(:head).with(
            test_url,
            headers: {},
            follow_redirects: true
          )
        end
      end
    end

    context 'with existing upstream cache entries' do
      before do
        upstream.save!
        create(
          :virtual_registries_container_cache_entry,
          upstream: upstream,
          relative_path: 'library/alpine/manifests/latest'
        )
      end

      it 'uses the cache entry relative_path for the HEAD request' do
        test

        expect(Gitlab::HTTP).to have_received(:head).with(
          upstream.url_for('library/alpine/manifests/latest'),
          headers: upstream.headers('library/alpine/manifests/latest'),
          follow_redirects: true
        )
      end
    end
  end

  describe 'callbacks' do
    describe '#reset_auth_url' do
      let_it_be(:upstream, freeze: false) { create(:virtual_registries_container_upstream, :with_auth_url) }

      subject(:update_url) { upstream.update!(url: 'http://test.com/new/url') }

      context 'when url will be updated' do
        it 'resets auth_url' do
          update_url

          expect(upstream.auth_url).to be_nil
        end
      end

      context 'when url will not be updated' do
        it { expect { update_url }.not_to change { upstream.auth_url } }
      end
    end
  end

  def with_accept_headers(headers)
    headers.merge(described_class::REGISTRY_ACCEPT_HEADERS)
  end

  describe '#purge_cache!' do
    let(:upstream) { build_stubbed(:virtual_registries_container_upstream) }

    it 'enqueues the MarkEntriesForDestructionWorker' do
      expect(::VirtualRegistries::Cache::MarkEntriesForDestructionWorker)
        .to receive(:perform_async).with(upstream.to_global_id.to_s)

      upstream.purge_cache!
    end
  end

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), upstream)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end
end
