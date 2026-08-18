# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Container::Upstreams, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for container virtual registry api setup'

  describe 'GET /api/v4/groups/:id/-/virtual_registries/container/upstreams' do
    let(:group_id) { group.id }
    let(:url) { "/groups/#{group_id}/-/virtual_registries/container/upstreams" }

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)).to contain_exactly(upstream.as_json)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    context 'with valid group_id' do
      it_behaves_like 'successful response'

      it_behaves_like "authorizing granular token permissions", :read_container_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          get api(url, personal_access_token: pat)
        end
      end

      context 'when upstream_name is given' do
        let_it_be(:upstream2) do
          create(:virtual_registries_container_upstream, registries: [registry], name: 'foo-name')
        end

        let(:params) { { upstream_name: 'foo' } }

        subject(:api_request) { get api(url), params: params, headers: headers }

        it 'returns upstreams that have name match to the given upstream name to' do
          api_request

          expect(Gitlab::Json.parse(response.body)).to contain_exactly(upstream2.as_json)
        end

        context 'when no upstream is found' do
          let(:params) { { upstream_name: 'bar' } }

          it 'returns empty array' do
            api_request

            expect(Gitlab::Json.parse(response.body)).to be_empty
          end
        end
      end
    end

    context 'with invalid group_id' do
      where(:group_id, :status) do
        non_existing_record_id | :not_found
        'foo'                  | :not_found
        ''                     | :not_found
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'with a non top level group' do
      let(:group) { create(:group, :nested) }

      before do
        group.parent.add_maintainer(user)
      end

      it_behaves_like 'returning response status', :not_found
    end

    it_behaves_like 'virtual registry not available', :container
    it_behaves_like 'virtual registry non member user access', registry_factory: :virtual_registries_container_registry,
      upstream_factory: :virtual_registries_container_upstream
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'virtual registry custom role read access'
  end

  describe 'POST /api/v4/groups/:id/-/virtual_registries/container/upstreams/test' do
    let(:group_id) { group.id }
    let(:url) { "/groups/#{group_id}/-/virtual_registries/container/upstreams/test" }
    let(:params) { { url: 'http://example.com', username: 'user', password: 'test' } }

    subject(:api_request) { post api(url), params: params, headers: headers }

    it_behaves_like 'virtual registry not available', :container

    context 'for different user roles' do
      where(:user_role, :status) do
        :owner      | :ok
        :maintainer | :ok
        :developer  | :forbidden
        :reporter   | :forbidden
        :guest      | :forbidden
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", user)

          if status == :ok
            allow_next_instance_of(::VirtualRegistries::Container::Upstream) do |instance|
              allow(instance).to receive(:test).and_return({ success: true })
            end
          end
        end

        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'with valid params' do
      before_all do
        group.add_maintainer(user)
      end

      before do
        allow_next_instance_of(::VirtualRegistries::Container::Upstream) do |upstream_instance|
          allow(upstream_instance).to receive(:test).and_return({ success: true })
        end
      end

      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'success' => true })
      end

      it_behaves_like "authorizing granular token permissions", :test_container_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          post api(url, personal_access_token: pat), params: params
        end
      end
    end

    context 'with invalid group_id' do
      where(:group_id, :status) do
        non_existing_record_id | :not_found
        'foo'                  | :not_found
        ''                     | :not_found
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'with a non top level group' do
      let(:group) { create(:group, :nested) }

      before do
        group.parent.add_maintainer(user)
      end

      it_behaves_like 'returning response status', :not_found
    end

    context 'with invalid params' do
      before_all do
        group.add_maintainer(user)
      end

      where(:params, :status) do
        { url: '' }                                     | :bad_request
        { url: 'invalid-url' }                          | :bad_request
        {}                                              | :bad_request
        { username: 'user' }                            | :bad_request
        { password: 'test' }                            | :bad_request
        { url: 'http://example.com', username: 'user' } | :bad_request
        { url: 'http://example.com', password: 'test' } | :bad_request
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'virtual registry non member user access',
      registry_factory: :virtual_registries_container_registry,
      upstream_factory: :virtual_registries_container_upstream
    it_behaves_like 'an authenticated virtual registry REST API' do
      before do
        allow_next_instance_of(::VirtualRegistries::Container::Upstream) do |instance|
          allow(instance).to receive(:test)
        end
      end
    end
  end

  describe 'GET /api/v4/virtual_registries/container/registries/:id/upstreams' do
    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/container/registries/#{registry_id}/upstreams" }
    let(:upstream_as_json) do
      upstream.as_json.merge(
        registry_upstream: upstream.registry_upstreams.take.slice(:id, :registry_id, :position)
      ).as_json
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)).to contain_exactly(upstream_as_json)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    context 'with valid registry' do
      it_behaves_like 'successful response'

      it_behaves_like "authorizing granular token permissions", :read_container_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          get api(url, personal_access_token: pat)
        end
      end
    end

    context 'with invalid registry' do
      where(:registry_id, :status) do
        non_existing_record_id | :not_found
        'foo'                  | :bad_request
        ''                     | :bad_request
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'virtual registry not available', :container
    it_behaves_like 'virtual registry non member user access', registry_factory: :virtual_registries_container_registry,
      upstream_factory: :virtual_registries_container_upstream
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'virtual registry custom role read access'
  end

  describe 'POST /api/v4/virtual_registries/container/registries/:id/upstreams' do
    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/container/registries/#{registry_id}/upstreams" }
    let(:params) { { url: 'http://example.com', name: 'foo', username: 'user', password: 'test' } }
    let(:upstream_as_json) do
      upstream_model.last.as_json.merge(
        registry_upstream: upstream_model.last.registry_upstreams.take.slice(:id, :registry_id, :position)
      ).as_json
    end

    subject(:api_request) { post api(url), headers: headers, params: params }

    shared_examples 'successful response' do
      let(:upstream_model) { ::VirtualRegistries::Container::Upstream }

      it 'returns a successful response' do
        expect { api_request }.to change { upstream_model.count }.by(1)
          .and change { ::VirtualRegistries::Container::RegistryUpstream.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(Gitlab::Json.parse(response.body)).to eq(upstream_as_json)
        expect(upstream_model.last).to have_attributes(
          cache_validity_hours: params[:cache_validity_hours] || upstream_model.new.cache_validity_hours
        )
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :container

    context 'with valid params' do
      where(:user_role, :status) do
        :owner      | :created
        :maintainer | :created
        :developer  | :forbidden
        :reporter   | :forbidden
        :guest      | :forbidden
      end

      with_them do
        before do
          registry.upstreams.each(&:destroy!)
          group.send(:"add_#{user_role}", user)
        end

        if params[:status] == :created
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end

      context 'with maintainer role' do
        before_all do
          group.add_maintainer(user)
        end

        before do
          registry.upstreams.each(&:destroy!)
        end

        it_behaves_like "authorizing granular token permissions", :create_container_virtual_registry_upstream do
          let(:boundary_object) { group }
          let(:request) do
            post api(url, personal_access_token: pat), params: params
          end
        end
      end
    end

    context 'with invalid registry' do
      where(:registry_id, :status) do
        non_existing_record_id | :not_found
        'foo'                  | :bad_request
        ''                     | :not_found
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'for params' do
      let(:params) do
        { url: test_url }.merge(
          name:, description:, username:, password:, cache_validity_hours:
        ).compact
      end

      # rubocop:disable Layout/LineLength -- splitting the table syntax affects readability
      where(:name, :description, :test_url, :username, :password, :cache_validity_hours, :metadata_cache_validity_hours, :status) do
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | 5   | :created
        'foo' | nil   | 'http://example.com' | 'test' | 'test' | nil | 5   | :created
        'foo' | nil   | 'http://example.com' | 'test' | 'test' | nil | nil | :created
        nil   | nil   | ''                   | 'test' | 'test' | nil | nil | :bad_request
        nil   | nil   | 'http://example.com' | 'test' | nil    | nil | nil | :bad_request
        nil   | nil   | 'http://example.com' | 'test' | 'test' | nil | 0   | :bad_request
        nil   | nil   | nil                  | nil    | nil    | nil | nil | :bad_request
      end
      # rubocop:enable Layout/LineLength

      before do
        registry.upstreams.each(&:destroy!)
      end

      before_all do
        group.add_maintainer(user)
      end

      with_them do
        if params[:status] == :created
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end
    end

    context 'with a full registry' do
      before_all do
        group.add_maintainer(user)
        registry.upstreams.delete_all
        build_list(
          :virtual_registries_container_registry_upstream,
          VirtualRegistries::Container::RegistryUpstream::MAX_UPSTREAMS_COUNT,
          registry:
        ).each(&:save!)
      end

      it_behaves_like 'returning response status with message',
        status: :bad_request,
        message: { 'registry_upstreams.position' => ['must be less than or equal to 5'] }
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :created do
      before_all do
        group.add_maintainer(user)
      end

      before do
        registry.upstreams.each(&:destroy!)
      end
    end

    context 'with existing duplicate credentials' do
      before_all do
        group.add_maintainer(user)
        registry.upstreams.delete_all
      end

      before do
        create(:virtual_registries_container_upstream, **params.merge(group:))
      end

      it_behaves_like 'returning response status with message',
        status: :bad_request,
        message: { 'group' => ['already has an upstream with the same credentials'] }
    end
  end

  describe 'GET /api/v4/virtual_registries/container/upstreams/:id' do
    let(:url) { "/virtual_registries/container/upstreams/#{upstream.id}" }
    let(:upstream_as_json) do
      upstream.as_json.merge(
        registry_upstreams: upstream.registry_upstreams.map { |e| e.slice(:id, :registry_id, :position) }
      ).as_json
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)).to eq(upstream_as_json)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    context 'with valid params' do
      it_behaves_like 'successful response'

      it_behaves_like "authorizing granular token permissions", :read_container_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          get api(url, personal_access_token: pat)
        end
      end
    end

    it_behaves_like 'virtual registry not available', :container
    it_behaves_like 'virtual registry non member user access', registry_factory: :virtual_registries_container_registry,
      upstream_factory: :virtual_registries_container_upstream
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'virtual registry custom role read access'
  end

  describe 'PATCH /api/v4/virtual_registries/container/upstreams/:id' do
    let(:url) { "/virtual_registries/container/upstreams/#{upstream.id}" }
    let(:params) { { name: 'foo', description: 'description', url: 'http://example.com', username: 'test', password: 'test' } }

    subject(:api_request) { patch api(url), params: params, headers: headers }

    context 'with valid params' do
      it { is_expected.to have_request_urgency(:low) }

      it_behaves_like 'virtual registry not available', :container

      where(:user_role, :status) do
        :owner      | :ok
        :maintainer | :ok
        :developer  | :forbidden
        :reporter   | :forbidden
        :guest      | :forbidden
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", user)
        end

        it_behaves_like 'returning response status', params[:status]
      end

      context 'with maintainer role' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like "authorizing granular token permissions", :update_container_virtual_registry_upstream do
          let(:boundary_object) { group }
          let(:request) do
            patch api(url, personal_access_token: pat), params: params
          end
        end

        it_behaves_like 'an authenticated virtual registry REST API'
      end
    end

    context 'for params' do
      before_all do
        group.add_maintainer(user)
      end

      let(:params) do
        { url: param_url }.merge(
          name:, description:, username:, password:, cache_validity_hours:
        ).compact
      end

      # -- splitting the table syntax affects readability
      where(:name, :description, :param_url, :username, :password, :cache_validity_hours, :status) do
        nil | 'bar' | 'http://example.com' | 'test' | 'test'   | 3   | :ok
        'foo' | nil   | 'http://example.com' | 'test' | 'test' | 3   | :ok
        'foo' | 'bar' | nil                  | 'test' | 'test' | 3   | :ok
        'foo' | 'bar' | 'http://example.com' | nil    | 'test' | 3   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | nil    | 3   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | nil | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | :ok
        nil   | nil   | nil                  | nil    | nil    | 3   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | :ok
        'foo' | ''    | 'http://example.com' | 'test' | 'test' | 3   | :ok
        ''    | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | :bad_request
        'foo' | 'bar' | ''                   | 'test' | 'test' | 3   | :bad_request
        'foo' | 'bar' | 'http://example.com' | ''     | 'test' | 3   | :bad_request
        'foo' | 'bar' | 'http://example.com' | 'test' | ''     | 3   | :bad_request
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | -1  | :bad_request
        nil   | nil   | nil                  | nil    | nil    | nil | :bad_request
      end
      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'with existing duplicate credentials' do
      let_it_be(:existing_upstream) { create(:virtual_registries_container_upstream, group:) }
      let(:params) { existing_upstream.attributes.slice('url', 'username', 'password') }

      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'returning response status with message',
        status: :bad_request,
        message: { 'group' => ['already has an upstream with the same credentials'] }
    end
  end

  describe 'DELETE /api/v4/virtual_registries/container/upstreams/:id' do
    let(:url) { "/virtual_registries/container/upstreams/#{upstream.id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change { ::VirtualRegistries::Container::Upstream.count }.by(-1)
          .and change { ::VirtualRegistries::Container::RegistryUpstream.count }.by(-1)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :container

    context 'for different user roles' do
      where(:user_role, :status) do
        :owner      | :no_content
        :maintainer | :no_content
        :developer  | :forbidden
        :reporter   | :forbidden
        :guest      | :forbidden
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", user)
        end

        if params[:status] == :no_content
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end

      context 'with maintainer role' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like "authorizing granular token permissions", :delete_container_virtual_registry_upstream do
          let(:boundary_object) { group }
          let(:request) do
            delete api(url, personal_access_token: pat)
          end
        end
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end

    context 'for position sync' do
      let_it_be_with_refind(:upstream_2) { create(:virtual_registries_container_upstream, registries: [registry]) }

      before_all do
        group.add_maintainer(user)
      end

      it 'syncs the position' do
        expect { api_request }.to change { upstream_2.registry_upstreams.take.position }.by(-1)
      end
    end
  end

  describe 'DELETE /api/v4/virtual_registries/container/upstreams/:id/cache', :sidekiq_inline do
    let(:url) { "/virtual_registries/container/upstreams/#{upstream.id}/cache" }

    subject(:api_request) { delete api(url), headers: headers }

    before_all do
      create_list(:virtual_registries_container_cache_remote_entry, 2, upstream:) # 2 default
      create(:virtual_registries_container_cache_remote_entry, :pending_destruction, upstream:) # 1 pending destruction
      create(:virtual_registries_container_cache_remote_entry) # 1 default in another upstream
    end

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change {
          ::VirtualRegistries::Container::Cache::Remote::Entry.pending_destruction.count
        }.by(3)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :container

    context 'for different user roles' do
      where(:user_role, :status) do
        :owner      | :no_content
        :maintainer | :no_content
        :developer  | :forbidden
        :reporter   | :forbidden
        :guest      | :forbidden
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", user)
        end

        if params[:status] == :no_content
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end

      context 'with maintainer role' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like "authorizing granular token permissions", :purge_container_virtual_registry_upstream_cache do
          let(:boundary_object) { group }
          let(:request) do
            delete api(url, personal_access_token: pat)
          end
        end
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end
  end

  describe 'POST /api/v4/virtual_registries/container/upstreams/:id/test' do
    let(:url) { "/virtual_registries/container/upstreams/#{upstream.id}/test" }
    let(:params) { {} }

    subject(:api_request) { post api(url), params: params, headers: headers }

    shared_examples 'a successful test response' do
      specify do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'success' => true })
      end
    end

    before do
      allow(Gitlab::HTTP).to receive(:head).and_return(instance_double(HTTParty::Response, code: 200, success?: true,
        unauthorized?: false))
    end

    it_behaves_like 'virtual registry not available', :container
    it_behaves_like 'virtual registry non member user access',
      registry_factory: :virtual_registries_container_registry,
      upstream_factory: :virtual_registries_container_upstream

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'an authenticated virtual registry REST API'

    context 'with no override params' do
      before do
        group.add_maintainer(user)
      end

      it_behaves_like 'a successful test response'
    end

    context 'with override params' do
      before_all do
        group.add_maintainer(user)
      end

      let(:new_url) { 'http://new-example.com' }
      let(:existing_username) { upstream.username }
      let(:existing_password) { upstream.password }

      where(:scenario, :params) do
        'url only'                          | { url: ref(:new_url) }
        'url with new credentials'          | { url: ref(:new_url), username: 'new-username', password: 'new-password' }
        'existing user, no password'        | { username: ref(:existing_username), password: '' }
        'existing user and password'        | { username: ref(:existing_username), password: ref(:existing_password) }
      end

      with_them do
        it_behaves_like 'a successful test response'
      end
    end

    context 'with invalid override params' do
      where(:params, :error_message) do
        { url: '' }                    | { 'url' => ['is empty'] }
        { password: 'new-password' }   | { 'username' => ["can't be blank"] }
        { username: 'new-username' }   | { 'password' => ["can't be blank"] }
      end

      with_them do
        it_behaves_like 'returning response status', :bad_request
      end
    end

    it_behaves_like "authorizing granular token permissions", :test_container_virtual_registry_upstream do
      let(:boundary_object) { group }
      let(:request) do
        post api(url, personal_access_token: pat), params: params
      end
    end
  end
end
