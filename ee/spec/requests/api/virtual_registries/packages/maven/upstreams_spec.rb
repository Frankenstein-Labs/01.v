# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Packages::Maven::Upstreams, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for maven virtual registry api setup'

  describe 'GET /api/v4/groups/:id/-/virtual_registries/packages/maven/upstreams' do
    let(:group_id) { group.id }
    let(:url) { "/groups/#{group_id}/-/virtual_registries/packages/maven/upstreams" }
    let_it_be_with_reload(:local_upstream) do
      create(:virtual_registries_packages_maven_local_upstream, group: group)
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response with both remote and local upstreams' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to contain_exactly(
          upstream.as_json.merge('upstream_type' => 'remote'),
          local_upstream.as_json.merge('upstream_type' => 'local')
        )
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    context 'with valid group_id' do
      it_behaves_like 'successful response'

      context 'when upstream_name is given' do
        let_it_be(:upstream2) do
          create(:virtual_registries_packages_maven_upstream, registries: [registry], name: 'foo-name')
        end

        let_it_be(:local_upstream2) do
          create(:virtual_registries_packages_maven_local_upstream, group: group, name: 'foo-name')
        end

        let(:params) { { upstream_name: 'foo' } }

        subject(:api_request) { get api(url), params: params, headers: headers }

        it 'returns both remote and local upstreams matching the name' do
          api_request

          expect(json_response).to contain_exactly(
            upstream2.as_json.merge('upstream_type' => 'remote'),
            local_upstream2.as_json.merge('upstream_type' => 'local')
          )
        end

        context 'when no upstream is found' do
          let(:params) { { upstream_name: 'bar' } }

          it 'returns empty array' do
            api_request

            expect(Gitlab::Json.parse(response.body)).to be_empty
          end
        end
      end

      it_behaves_like 'authorizing granular token permissions', :read_maven_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          get api(url, personal_access_token: pat)
        end
      end

      context 'when two upstreams share the same updated_at' do
        before do
          timestamp = Time.current
          upstream.update_column(:updated_at, timestamp)
          local_upstream.update_column(:updated_at, timestamp)
        end

        it 'returns a deterministic order, tiebroken by type then id' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          # With equal updated_at, the [updated_at, upstream_type, id] sort (reversed)
          # decides the order: the remote upstream comes before the local one.
          expect(json_response.map { |u| u['upstream_type'] }).to eq(%w[remote local])
        end
      end

      it 'avoids N+1 queries when more upstreams are added' do
        control = ActiveRecord::QueryRecorder.new { get api(url), headers: headers }

        create(:virtual_registries_packages_maven_upstream, registries: [registry])
        create(:virtual_registries_packages_maven_local_upstream, group: group)

        expect { get api(url), headers: headers }.not_to exceed_query_limit(control)
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

    it_behaves_like 'virtual registry not available', :maven
    it_behaves_like 'virtual registry non member user access',
      registry_factory: :virtual_registries_packages_maven_registry,
      upstream_factory: :virtual_registries_packages_maven_upstream
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'virtual registry custom role read access'
  end

  describe 'POST /api/v4/groups/:id/-/virtual_registries/packages/maven/upstreams/test' do
    let(:group_id) { group.id }
    let(:url) { "/groups/#{group_id}/-/virtual_registries/packages/maven/upstreams/test" }
    let(:params) { { url: 'http://example.com', username: 'user', password: 'test' } }

    subject(:api_request) { post api(url), params: params, headers: headers }

    it_behaves_like 'virtual registry not available', :maven

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
            allow_next_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |instance|
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
        allow_next_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |upstream_instance|
          allow(upstream_instance).to receive(:test).and_return({ success: true })
        end
      end

      it { is_expected.to have_request_urgency(:low) }

      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'success' => true })
      end

      it_behaves_like 'authorizing granular token permissions', :test_maven_virtual_registry_upstream do
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
      registry_factory: :virtual_registries_packages_maven_registry,
      upstream_factory: :virtual_registries_packages_maven_upstream
    it_behaves_like 'an authenticated virtual registry REST API' do
      before do
        allow_next_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |instance|
          allow(instance).to receive(:test)
        end
      end
    end
  end

  describe 'GET /api/v4/virtual_registries/packages/maven/registries/:id/upstreams' do
    let_it_be(:local_upstream) { create(:virtual_registries_packages_maven_local_upstream, group: group) }
    let_it_be(:local_registry_upstream) do
      create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream,
        registry: registry, local_upstream: local_upstream)
    end

    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry_id}/upstreams" }
    let(:remote_as_json) do
      upstream.as_json.merge(
        upstream_type: 'remote',
        registry_upstream: upstream.registry_upstreams.take.slice(:id, :registry_id, :position, :local_upstream_id)
      ).as_json
    end

    let(:local_as_json) do
      local_upstream.as_json.merge(
        upstream_type: 'local',
        registry_upstream: local_registry_upstream.slice(:id, :registry_id, :position, :local_upstream_id)
      ).as_json
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns both remote and local upstreams ordered by position' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq([remote_as_json, local_as_json])
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    context 'with valid registry' do
      it_behaves_like 'successful response'

      it 'avoids N+1 queries when more upstreams are added' do
        control = ActiveRecord::QueryRecorder.new { get api(url), headers: headers }

        create(:virtual_registries_packages_maven_registry_upstream, registry: registry)
        create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream, registry: registry)

        expect { get api(url), headers: headers }.not_to exceed_query_limit(control)
      end

      context 'with a registry that has only local upstreams' do
        let_it_be(:local_only_registry) do
          create(:virtual_registries_packages_maven_registry, group: group, name: 'local-only')
        end

        let_it_be(:local_only_upstream) { create(:virtual_registries_packages_maven_local_upstream, group: group) }
        let_it_be(:local_only_registry_upstream) do
          create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream,
            registry: local_only_registry, local_upstream: local_only_upstream)
        end

        let(:registry_id) { local_only_registry.id }

        it 'returns only the local upstream' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(1)
          expect(json_response.first['upstream_type']).to eq('local')
          expect(json_response.first['registry_upstream']['local_upstream_id']).to eq(local_only_upstream.id)
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

    it_behaves_like 'virtual registry not available', :maven
    it_behaves_like 'virtual registry non member user access',
      registry_factory: :virtual_registries_packages_maven_registry,
      upstream_factory: :virtual_registries_packages_maven_upstream
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'virtual registry custom role read access'

    it_behaves_like 'authorizing granular token permissions', :read_maven_virtual_registry_upstream do
      let(:boundary_object) { registry.group }
      let(:request) do
        get api(url, personal_access_token: pat)
      end
    end
  end

  describe 'POST /api/v4/virtual_registries/packages/maven/registries/:id/upstreams' do
    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry_id}/upstreams" }
    let(:params) { { url: 'http://example.com', name: 'foo', username: 'user', password: 'test' } }
    let(:upstream_as_json) do
      upstream_model.last.as_json.merge(
        registry_upstream: upstream_model.last.registry_upstreams.take.slice(
          :id, :registry_id, :position, :local_upstream_id
        )
      ).as_json
    end

    subject(:api_request) { post api(url), headers: headers, params: params }

    shared_examples 'successful response' do
      let(:upstream_model) { ::VirtualRegistries::Packages::Maven::Upstream }

      it 'returns a successful response' do
        expect { api_request }.to change { upstream_model.count }.by(1)
          .and change { ::VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to eq(upstream_as_json.merge('upstream_type' => 'remote'))
        expect(upstream_model.last).to have_attributes(
          cache_validity_hours: params[:cache_validity_hours] || upstream_model.new.cache_validity_hours,
          metadata_cache_validity_hours: params[:metadata_cache_validity_hours] ||
            upstream_model.new.metadata_cache_validity_hours
        )
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :maven

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
          name:, description:, username:, password:, cache_validity_hours:, metadata_cache_validity_hours:
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
          :virtual_registries_packages_maven_registry_upstream,
          VirtualRegistries::Packages::Maven::RegistryUpstream::MAX_UPSTREAMS_COUNT,
          registry:
        ).each(&:save!)
      end

      it_behaves_like 'returning response status with message',
        status: :bad_request,
        message: { 'registry_upstreams.position' => ['must be less than or equal to 20'] }
    end

    context 'with a maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      before do
        registry.upstreams.each(&:destroy!)
      end

      it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :created

      it_behaves_like 'authorizing granular token permissions', :create_maven_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          post api(url, personal_access_token: pat), params: params
        end
      end
    end

    context 'with existing duplicate credentials' do
      before_all do
        group.add_maintainer(user)
        registry.upstreams.delete_all
      end

      before do
        create(:virtual_registries_packages_maven_upstream, **params.merge(group:))
      end

      it_behaves_like 'returning response status with message',
        status: :bad_request,
        message: { 'group' => [::VirtualRegistries::Packages::Maven::Upstream::SAME_URL_AND_CREDENTIALS_ERROR] }
    end
  end

  describe 'POST /api/v4/virtual_registries/packages/maven/registries/:id/local/upstreams' do
    let_it_be(:target_project) { create(:project, namespace: group) }

    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry_id}/local/upstreams" }
    let(:params) { { name: 'local-foo', local_project_id: target_project.id } }

    subject(:api_request) { post api(url), headers: headers, params: params }

    shared_examples 'successful response' do
      it 'creates a local upstream and links it to the registry' do
        expect { api_request }
          .to change { ::VirtualRegistries::Packages::Maven::Local::Upstream.count }.by(1)
          .and change { ::VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to include(
          'name' => 'local-foo',
          'upstream_type' => 'local',
          'local_project_id' => target_project.id
        )
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :maven

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
          group.send(:"add_#{user_role}", user)
        end

        if params[:status] == :created
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end
    end

    context 'with a group target' do
      let(:params) { { name: 'local-bar', local_group_id: group.id } }

      it 'creates a local upstream targeting the group' do
        expect { api_request }.to change { ::VirtualRegistries::Packages::Maven::Local::Upstream.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to include('upstream_type' => 'local', 'local_group_id' => group.id)
      end
    end

    context 'when the local upstream is invalid' do
      before_all do
        group.add_maintainer(user)
      end

      before do
        create(:virtual_registries_packages_maven_local_upstream, group: group, local_project: target_project)
      end

      it 'returns a validation error and does not create the upstream' do
        expect { api_request }
          .to not_change { ::VirtualRegistries::Packages::Maven::Local::Upstream.count }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'with a maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'authorizing granular token permissions', :create_maven_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          post api(url, personal_access_token: pat), params: params
        end
      end
    end

    context 'when neither local_group_id nor local_project_id is given' do
      let(:params) { { name: 'local-foo' } }

      it_behaves_like 'returning response status', :bad_request
    end

    context 'when both local_group_id and local_project_id are given' do
      let(:params) { { name: 'local-foo', local_group_id: group.id, local_project_id: target_project.id } }

      it_behaves_like 'returning response status', :bad_request
    end

    context 'when name is missing' do
      let(:params) { { local_project_id: target_project.id } }

      it_behaves_like 'returning response status', :bad_request
    end

    context 'when the user cannot read packages on the target' do
      let_it_be(:forbidden_project) { create(:project, :private) }

      let(:params) { { name: 'local-foo', local_project_id: forbidden_project.id } }

      it_behaves_like 'returning response status', :forbidden
    end

    context 'when the user cannot read packages on the target group' do
      let_it_be(:forbidden_group) { create(:group, :private) }

      let(:params) { { name: 'local-foo', local_group_id: forbidden_group.id } }

      it_behaves_like 'returning response status', :forbidden
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
  end

  describe 'GET /api/v4/virtual_registries/packages/maven/upstreams/:id' do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}" }
    let(:upstream_as_json) do
      upstream.as_json.merge(
        registry_upstreams: upstream.registry_upstreams.map do |e|
          e.slice(:id, :registry_id, :position, :local_upstream_id)
        end
      ).as_json
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq(upstream_as_json.merge('upstream_type' => 'remote'))
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    context 'with valid params' do
      it_behaves_like 'successful response'
    end

    it_behaves_like 'virtual registry not available', :maven
    it_behaves_like 'virtual registry non member user access',
      registry_factory: :virtual_registries_packages_maven_registry,
      upstream_factory: :virtual_registries_packages_maven_upstream
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'virtual registry custom role read access'

    it_behaves_like 'authorizing granular token permissions', :read_maven_virtual_registry_upstream do
      let(:boundary_object) { upstream.group }
      let(:request) do
        get api(url, personal_access_token: pat)
      end
    end
  end

  describe 'PATCH /api/v4/virtual_registries/packages/maven/upstreams/:id' do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}" }

    subject(:api_request) { patch api(url), params: params, headers: headers }

    context 'with valid params' do
      let(:params) { { name: 'foo', description: 'description', url: 'http://example.com', username: 'test', password: 'test' } }

      it { is_expected.to have_request_urgency(:low) }

      it_behaves_like 'virtual registry not available', :maven

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

      it_behaves_like 'an authenticated virtual registry REST API' do
        before_all do
          group.add_maintainer(user)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :update_maven_virtual_registry_upstream do
        let(:boundary_object) { upstream.group }
        let(:request) do
          patch api(url, personal_access_token: pat), params: params
        end
      end
    end

    context 'for params' do
      before_all do
        group.add_maintainer(user)
      end

      let(:params) do
        { url: param_url }.merge(
          name:, description:, username:, password:, cache_validity_hours:, metadata_cache_validity_hours:
        ).compact
      end

      # rubocop:disable Layout/LineLength -- splitting the table syntax affects readability
      where(:name, :description, :param_url, :username, :password, :cache_validity_hours, :metadata_cache_validity_hours, :status) do
        nil | 'bar' | 'http://example.com' | 'test' | 'test'   | 3   | 5   | :ok
        'foo' | nil   | 'http://example.com' | 'test' | 'test' | 3   | 5   | :ok
        'foo' | 'bar' | nil                  | 'test' | 'test' | 3   | 5   | :ok
        'foo' | 'bar' | 'http://example.com' | nil    | 'test' | 3   | 5   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | nil    | 3   | 5   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | nil | 5   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | nil | :ok
        nil   | nil   | nil                  | nil    | nil    | 3   | 5   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | 5   | :ok
        'foo' | ''    | 'http://example.com' | 'test' | 'test' | 3   | 5   | :ok
        ''    | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | 5   | :bad_request
        'foo' | 'bar' | ''                   | 'test' | 'test' | 3   | 5   | :bad_request
        'foo' | 'bar' | 'http://example.com' | ''     | 'test' | 3   | 5   | :bad_request
        'foo' | 'bar' | 'http://example.com' | 'test' | ''     | 3   | 5   | :bad_request
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | -1  | 5   | :bad_request
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | 0   | :bad_request
        nil   | nil   | nil                  | nil    | nil    | nil | nil | :bad_request
      end
      # rubocop:enable Layout/LineLength

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'with existing duplicate credentials' do
      let_it_be(:existing_upstream) { create(:virtual_registries_packages_maven_upstream, group:) }
      let(:params) { existing_upstream.attributes.slice('url', 'username', 'password') }

      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'returning response status with message',
        status: :bad_request,
        message: { 'group' => [::VirtualRegistries::Packages::Maven::Upstream::SAME_URL_AND_CREDENTIALS_ERROR] }
    end
  end

  describe 'DELETE /api/v4/virtual_registries/packages/maven/upstreams/:id' do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change { ::VirtualRegistries::Packages::Maven::Upstream.count }.by(-1)
          .and change { ::VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(-1)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :maven

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
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end

    context 'for position sync' do
      let_it_be_with_refind(:upstream_2) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

      before_all do
        group.add_maintainer(user)
      end

      it 'syncs the position' do
        expect { api_request }.to change { upstream_2.registry_upstreams.take.position }.by(-1)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :delete_maven_virtual_registry_upstream do
      let(:boundary_object) { upstream.group }
      let(:request) do
        delete api(url, personal_access_token: pat)
      end
    end
  end

  describe 'DELETE /api/v4/virtual_registries/packages/maven/upstreams/:id/cache', :sidekiq_inline do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}/cache" }

    subject(:api_request) { delete api(url), headers: headers }

    before_all do
      # 2 default
      create_list(:virtual_registries_packages_maven_cache_remote_entry, 2, upstream:)
      # 1 pending destruction
      create(:virtual_registries_packages_maven_cache_remote_entry, :pending_destruction, upstream:)
      # 1 default in another upstream
      create(:virtual_registries_packages_maven_cache_remote_entry)
    end

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change {
          ::VirtualRegistries::Packages::Maven::Cache::Remote::Entry.pending_destruction.count
        }.by(3) # 2 created in before_all + 1 from 'for maven virtual registry api setup' shared context

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :maven

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
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :purge_maven_virtual_registry_upstream_cache do
      let(:boundary_object) { upstream.group }
      let(:request) do
        delete api(url, personal_access_token: pat)
      end
    end
  end

  describe 'GET /api/v4/virtual_registries/packages/maven/upstreams/:id/test' do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}/test" }

    subject(:api_request) { get api(url), headers: headers }

    before do
      allow_next_found_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |instance|
        allow(instance).to receive(:test).and_return({ success: true })
      end
    end

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'success' => true })
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :maven

    context 'with valid upstream' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'successful response'

      it_behaves_like 'authorizing granular token permissions', :test_maven_virtual_registry_upstream do
        let(:boundary_object) { upstream.group }
        let(:request) do
          get api(url, personal_access_token: pat)
        end
      end
    end

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
          allow(upstream).to receive(:test) if status == :ok
        end

        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'virtual registry non member user access',
      registry_factory: :virtual_registries_packages_maven_registry,
      upstream_factory: :virtual_registries_packages_maven_upstream
    it_behaves_like 'an authenticated virtual registry REST API'
  end

  describe 'POST /api/v4/virtual_registries/packages/maven/upstreams/:id/test' do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}/test" }
    let(:params) { {} }

    subject(:api_request) { post api(url), params: params, headers: headers }

    it_behaves_like 'virtual registry not available', :maven

    it_behaves_like 'virtual registry non member user access',
      registry_factory: :virtual_registries_packages_maven_registry,
      upstream_factory: :virtual_registries_packages_maven_upstream

    context 'with no override params' do
      before do
        group.add_maintainer(user)

        allow_next_found_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |instance|
          allow(instance).to receive(:test).and_return({ success: true })
        end
      end

      it 'tests the existing upstream without creating a new instance' do
        expect(::VirtualRegistries::Packages::Maven::Upstream).not_to receive(:new)

        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'success' => true })
      end

      it { is_expected.to have_request_urgency(:low) }

      it_behaves_like 'an authenticated virtual registry REST API'

      it_behaves_like 'authorizing granular token permissions', :test_maven_virtual_registry_upstream do
        let(:boundary_object) { upstream.group }
        let(:request) do
          post api(url, personal_access_token: pat), params: params
        end
      end
    end

    context 'with override params' do
      before_all do
        group.add_maintainer(user)
      end

      context 'when a new url is provided' do
        let(:new_url) { 'http://new-example.com' }

        before do
          allow_next_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |upstream_instance|
            allow(upstream_instance).to receive(:test).and_return({ success: true })
          end
        end

        context 'with no username and password' do
          let(:params) { { url: new_url } }

          it 'builds a new upstream instance with the new url and no credentials' do
            expect(::VirtualRegistries::Packages::Maven::Upstream).to receive(:new).with(
              url: new_url,
              username: nil,
              password: nil,
              group: upstream.group,
              name: 'test'
            )

            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'success' => true })
          end
        end

        context 'with new username and password' do
          let(:params) { { url: new_url, username: 'new-username', password: 'new-password' } }

          it 'builds a new upstream instance with new url and new credentials' do
            expect(::VirtualRegistries::Packages::Maven::Upstream).to receive(:new).with(
              url: new_url,
              username: 'new-username',
              password: 'new-password',
              group: upstream.group,
              name: 'test'
            )

            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'success' => true })
          end
        end

        context 'with existing username and no password' do
          let(:params) { { url: new_url, username: upstream.username, password: '' } }

          it 'returns a bad request and a validation error' do
            expect(::VirtualRegistries::Packages::Maven::Upstream).to receive(:new).with(
              url: new_url,
              username: upstream.username,
              password: '',
              group: upstream.group,
              name: 'test'
            )

            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['password']).to include("can't be blank")
          end
        end

        context 'with new username and no password' do
          let(:params) { { url: new_url, username: 'new-username', password: '' } }

          it 'returns a bad request and a validation error' do
            expect(::VirtualRegistries::Packages::Maven::Upstream).to receive(:new).with(
              url: new_url,
              username: 'new-username',
              password: '',
              group: upstream.group,
              name: 'test'
            )

            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['password']).to include("can't be blank")
          end
        end

        context 'with new password and no username' do
          let(:params) { { url: new_url, username: '', password: 'new-password' } }

          it 'returns a bad request and a validation error' do
            expect(::VirtualRegistries::Packages::Maven::Upstream).to receive(:new).with(
              url: new_url,
              username: '',
              password: 'new-password',
              group: upstream.group,
              name: 'test'
            )

            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['username']).to include("can't be blank")
          end
        end
      end

      context 'when credentials are provided' do
        context 'with new username and no password' do
          let(:params) { { username: 'new-username', password: '' } }

          it 'returns a bad request and a validation error' do
            allow_next_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |upstream_instance|
              allow(upstream_instance).to receive(:test).and_return({ success: true })
            end

            expect(::VirtualRegistries::Packages::Maven::Upstream).to receive(:new).with(
              url: upstream.url,
              username: 'new-username',
              password: '',
              group: upstream.group,
              name: 'test'
            )

            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['password']).to include("can't be blank")
          end
        end

        context 'with no username and new password' do
          let(:params) { { username: '', password: 'new-password' } }

          it 'returns a bad request and a validation error' do
            allow_next_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |upstream_instance|
              allow(upstream_instance).to receive(:test).and_return({ success: true })
            end

            expect(::VirtualRegistries::Packages::Maven::Upstream).to receive(:new).with(
              url: upstream.url,
              username: '',
              password: 'new-password',
              group: upstream.group,
              name: 'test'
            )

            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['username']).to include("can't be blank")
          end
        end

        context 'with existing username and no password' do
          let(:params) { { username: upstream.username, password: '' } }

          it 'tests the existing upstream without building a new instance' do
            allow_next_found_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |upstream_instance|
              allow(upstream_instance).to receive(:test).and_return({ success: true })
            end

            expect(::VirtualRegistries::Packages::Maven::Upstream).not_to receive(:new)

            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'success' => true })
          end
        end

        context 'with existing username and existing password' do
          let(:params) { { username: upstream.username, password: upstream.password } }

          it 'tests the existing upstream without building a new instance' do
            allow_next_found_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |upstream_instance|
              allow(upstream_instance).to receive(:test).and_return({ success: true })
            end

            expect(::VirtualRegistries::Packages::Maven::Upstream).not_to receive(:new)

            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'success' => true })
          end
        end

        context 'with existing url and username and password as empty strings' do
          let(:params) { { url: upstream.url, username: '', password: '' } }

          it 'builds a new upstream instance with empty credentials' do
            allow_next_instance_of(::VirtualRegistries::Packages::Maven::Upstream) do |upstream_instance|
              allow(upstream_instance).to receive(:test).and_return({ success: true })
            end

            expect(::VirtualRegistries::Packages::Maven::Upstream).to receive(:new).with(
              url: upstream.url,
              username: '',
              password: '',
              group: upstream.group,
              name: 'test'
            )

            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'success' => true })
          end
        end
      end

      context 'with invalid override params' do
        let(:params) { { url: '' } }

        it 'returns validation errors' do
          api_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to have_key('error')
          expect(json_response['error']).to eq('url is empty')
        end
      end
    end
  end

  describe 'GET /api/v4/virtual_registries/packages/maven/local/upstreams/:id' do
    let_it_be(:local_upstream) do
      create(:virtual_registries_packages_maven_local_upstream, group: group, registries: [registry])
    end

    let(:url) { "/virtual_registries/packages/maven/local/upstreams/#{local_upstream.id}" }
    let(:local_upstream_as_json) do
      local_upstream.as_json.merge(
        upstream_type: 'local',
        registry_upstreams: local_upstream.registry_upstreams.map do |e|
          e.slice(:id, :registry_id, :position, :local_upstream_id)
        end
      ).as_json
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns the local upstream' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq(local_upstream_as_json)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :maven
    it_behaves_like 'an authenticated virtual registry REST API'
    it_behaves_like 'virtual registry custom role read access'

    context 'with a valid id' do
      where(:user_role, :status) do
        :owner      | :ok
        :maintainer | :ok
        :developer  | :ok
        :reporter   | :ok
        :guest      | :ok
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", user)
        end

        it_behaves_like 'successful response'
      end
    end

    context 'with a non-existent id' do
      let(:url) { "/virtual_registries/packages/maven/local/upstreams/#{non_existing_record_id}" }

      it_behaves_like 'returning response status', :not_found
    end

    # The 'virtual registry non member user access' shared example addresses the object through a
    # `let(:upstream)` it defines, but this endpoint is keyed on the local upstream's own id, so we
    # build the equivalent fresh group/registry/local upstream here.
    context 'with a non member user' do
      let(:non_member_user) { create(:user) }
      let(:user) { non_member_user }

      where(:group_access_level, :status) do
        'PUBLIC'   | :not_found
        'INTERNAL' | :not_found
        'PRIVATE'  | :not_found
      end

      with_them do
        let(:group) { create(:group, visibility_level: Gitlab::VisibilityLevel.const_get(group_access_level, false)) }
        let(:local_upstream) do
          create(:virtual_registries_packages_maven_local_upstream, group:)
        end

        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_maven_virtual_registry_upstream do
      let(:boundary_object) { local_upstream.group }
      let(:request) do
        get api(url, personal_access_token: pat)
      end
    end
  end

  describe 'PATCH /api/v4/virtual_registries/packages/maven/local/upstreams/:id' do
    let_it_be_with_reload(:local_upstream) do
      create(:virtual_registries_packages_maven_local_upstream, group: group, registries: [registry])
    end

    let(:url) { "/virtual_registries/packages/maven/local/upstreams/#{local_upstream.id}" }
    let(:params) { { name: 'new-name', description: 'new description', cache_validity_hours: 5 } }

    subject(:api_request) { patch api(url), params: params, headers: headers }

    shared_examples 'successful response' do
      it 'updates the local upstream' do
        expect { api_request }
          .to change { local_upstream.reload.name }.to('new-name')
          .and change { local_upstream.description }.to('new description')
          .and change { local_upstream.cache_validity_hours }.to(5)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :maven
    it_behaves_like 'an authenticated virtual registry REST API' do
      before_all do
        group.add_maintainer(user)
      end
    end

    context 'with valid params' do
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

        if params[:status] == :ok
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end

      it_behaves_like 'authorizing granular token permissions', :update_maven_virtual_registry_upstream do
        let(:boundary_object) { local_upstream.group }
        let(:request) do
          patch api(url, personal_access_token: pat), params: params
        end
      end
    end

    context 'with invalid params' do
      before_all do
        group.add_maintainer(user)
      end

      # `name: ''` is rejected by Grape (allow_blank: false) before the service runs; the other two
      # pass param validation and fail model validation inside UpdateService, exercising its
      # :invalid -> render_validation_error! branch.
      where(:params) do
        [
          [{ name: '' }],
          [{ cache_validity_hours: -1 }],
          [{ metadata_cache_validity_hours: 0 }]
        ]
      end

      with_them do
        it_behaves_like 'returning response status', :bad_request
      end
    end

    context 'with no params' do
      let(:params) { {} }

      it_behaves_like 'returning response status', :bad_request
    end

    context 'with a non-existent id' do
      let(:url) { "/virtual_registries/packages/maven/local/upstreams/#{non_existing_record_id}" }

      it_behaves_like 'returning response status', :not_found
    end
  end

  describe 'DELETE /api/v4/virtual_registries/packages/maven/local/upstreams/:id' do
    let_it_be_with_refind(:local_upstream) do
      create(:virtual_registries_packages_maven_local_upstream, group: group, registries: [registry])
    end

    let(:url) { "/virtual_registries/packages/maven/local/upstreams/#{local_upstream.id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response' do
      it 'deletes the local upstream and its registry link' do
        expect { api_request }
          .to change { ::VirtualRegistries::Packages::Maven::Local::Upstream.count }.by(-1)
          .and change { ::VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(-1)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :maven
    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end

    context 'with valid id' do
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

      it_behaves_like 'authorizing granular token permissions', :delete_maven_virtual_registry_upstream do
        let(:boundary_object) { local_upstream.group }
        let(:request) do
          delete api(url, personal_access_token: pat)
        end
      end
    end

    context 'with a non-existent id' do
      let(:url) { "/virtual_registries/packages/maven/local/upstreams/#{non_existing_record_id}" }

      it_behaves_like 'returning response status', :not_found
    end

    context 'for position sync' do
      let_it_be_with_refind(:local_upstream_2) do
        create(:virtual_registries_packages_maven_local_upstream, group: group, registries: [registry])
      end

      before_all { group.add_maintainer(user) }

      it 'resyncs positions of remaining upstreams' do
        expect { api_request }.to change { local_upstream_2.registry_upstreams.take.position }.by(-1)
      end
    end
  end
end
