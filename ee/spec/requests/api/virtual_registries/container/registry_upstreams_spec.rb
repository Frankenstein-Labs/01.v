# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Container::RegistryUpstreams, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for container virtual registry api setup'

  shared_examples 'forbidden response' do
    it_behaves_like 'returning response status', :forbidden
  end

  describe 'POST /api/v4/virtual_registries/container/registry_upstreams' do
    let_it_be_with_refind(:upstream2) do
      create(:virtual_registries_container_upstream, group: group, registries: [])
    end

    let(:registry_id) { registry.id }
    let(:upstream_id) { upstream2.id }
    let(:url) { '/virtual_registries/container/registry_upstreams' }
    let(:params) { { registry_id:, upstream_id: } }

    subject(:api_request) { post api(url), headers: headers, params: params }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:created)
        expect(Gitlab::Json.parse(response.body)).to eq(
          upstream2.registry_upstreams.last.as_json.except('group_id', 'created_at', 'updated_at')
        )
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :container

    where(:user_role, :expected_behavior) do
      :owner      | 'successful response'
      :maintainer | 'successful response'
      :developer  | 'forbidden response'
      :reporter   | 'forbidden response'
      :guest      | 'forbidden response'
    end

    with_them do
      before do
        group.send(:"add_#{user_role}", user)
      end

      it_behaves_like params[:expected_behavior]
    end

    context 'with maintainer role' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like "authorizing granular token permissions", :associate_container_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          post api(url, personal_access_token: pat), params: params
        end
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :created do
      before_all do
        group.add_maintainer(user)
      end
    end

    context 'with invalid params' do
      where(:param_registry_id, :param_upstream_id, :status) do
        non_existing_record_id | non_existing_record_id | :not_found
        ref(:registry_id)      | non_existing_record_id | :not_found
        non_existing_record_id | ref(:upstream_id)      | :not_found
        'foo'                  | 'bar'                  | :bad_request
      end

      before_all do
        group.add_maintainer(user)
      end

      with_them do
        let(:params) { { registry_id: param_registry_id, upstream_id: param_upstream_id } }

        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'when upstream is already shared' do
      let(:params) { { registry_id: registry.id, upstream_id: upstream.id } }

      before_all do
        group.add_maintainer(user)
      end

      it 'returns a bad request' do
        api_request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response).to eq({ 'message' => { 'upstream_id' => ['has already been taken'] } })
      end
    end
  end

  describe 'PATCH /api/v4/virtual_registries/container/registry_upstreams/:id' do
    let(:registry_upstream) { create(:virtual_registries_container_registry_upstream, registry:) }
    let(:url) { "/virtual_registries/container/registry_upstreams/#{registry_upstream.id}" }

    subject(:api_request) { patch api(url), headers: headers, params: params }

    context 'with valid params' do
      let(:params) { { position: 5 } }

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

    context 'with invalid params' do
      [0, -1, 'a', 21].each do |position|
        context "when position is #{position}" do
          let(:params) { { position: position } }

          it 'returns a bad request' do
            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response).to match({ 'error' => /position does not have a valid value/ })
          end
        end
      end
    end
  end

  describe 'DELETE /api/v4/virtual_registries/container/registry_upstreams/:id' do
    let(:registry_upstream) { upstream.registry_upstreams.first }
    let(:url) { "/virtual_registries/container/registry_upstreams/#{registry_upstream.id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change { ::VirtualRegistries::Container::RegistryUpstream.count }.by(-1)
          .and not_change { ::VirtualRegistries::Container::Upstream.count }

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'virtual registry not available', :container

    where(:user_role, :expected_behavior) do
      :owner      | 'successful response'
      :maintainer | 'successful response'
      :developer  | 'forbidden response'
      :reporter   | 'forbidden response'
      :guest      | 'forbidden response'
    end

    with_them do
      before do
        group.send(:"add_#{user_role}", user)
      end

      it_behaves_like params[:expected_behavior]
    end

    context 'with maintainer role' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like "authorizing granular token permissions", :disassociate_container_virtual_registry_upstream do
        let(:boundary_object) { group }
        let(:request) do
          delete api(url, personal_access_token: pat)
        end
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end

    context 'when upstream is shared between registries' do
      let_it_be(:registry_2) do
        create(:virtual_registries_container_registry, group: group, name: 'other')
      end

      let_it_be(:registry_upstream_2) do
        create(:virtual_registries_container_registry_upstream, registry:)
      end

      let_it_be(:registry_upstream_3) do
        create(:virtual_registries_container_registry_upstream, upstream: registry_upstream_2.upstream,
          registry: registry_2)
      end

      let(:registry_upstream) { registry_upstream_3 }

      before_all do
        group.add_maintainer(user)
      end

      it 'deletes the registry upstream but keeps the upstream' do
        expect { api_request }.to change { ::VirtualRegistries::Container::RegistryUpstream.count }.by(-1)
          .and not_change { ::VirtualRegistries::Container::Upstream.count }
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
end
