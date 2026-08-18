# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Packages::Maven::Cache::Entries, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for maven virtual registry api setup'

  describe 'GET /api/v4/virtual_registries/packages/maven/upstreams/:id/cache_entries' do
    let(:upstream_id) { upstream.id }
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream_id}/cache_entries" }

    let_it_be(:processing_cache_entry) do
      create(
        :virtual_registries_packages_maven_cache_remote_entry,
        :processing,
        upstream: upstream,
        relative_path: cache_entry.relative_path
      )
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response', :freeze_time do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)).to contain_exactly(
          cache_entry
            .as_json
            .merge('id' => cache_entry.generate_id)
            .except('object_storage_key', 'file', 'file_store', 'status', 'iid')
        )
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    context 'with invalid upstream' do
      where(:upstream_id, :status) do
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

    context 'for search param' do
      let(:url) { "#{super()}?search=#{search}" }
      let(:valid_search) { cache_entry.relative_path.slice(0, 5) }

      where(:search, :status) do
        ref(:valid_search) | :ok
        'foo'              | :empty
        ''                 | :ok
        nil                | :ok
      end

      with_them do
        if params[:status] == :ok
          it_behaves_like 'successful response'
        else
          it 'returns an empty array' do
            api_request

            expect(json_response).to eq([])
          end
        end
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_maven_virtual_registry_upstream_cache_entry do
      let(:boundary_object) { upstream.group }
      let(:request) do
        get api(url), headers: { 'Private-Token' => pat.token }
      end
    end
  end

  describe 'DELETE /api/v4/virtual_registries/packages/maven/cache_entries/:id' do
    let(:url) { "/virtual_registries/packages/maven/cache_entries/#{cache_entry.generate_id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change {
          VirtualRegistries::Packages::Maven::Cache::Remote::Entry.last.status
        }.from('default').to('pending_destruction')

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

    context 'when error occurs' do
      before_all do
        group.add_maintainer(user)
      end

      before do
        allow_next_found_instance_of(cache_entry.class) do |instance|
          errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:cache_entry, 'error message') }
          allow(instance).to receive_messages(pending_destruction!: false, errors: errors)
        end
      end

      it_behaves_like 'returning response status with message', status: :bad_request,
        message: { 'cache_entry' => ['error message'] }
    end

    it_behaves_like 'authorizing granular token permissions', :delete_maven_virtual_registry_upstream_cache_entry do
      let(:boundary_object) { cache_entry.upstream.group }
      let(:request) do
        delete api(url), headers: { 'Private-Token' => pat.token }
      end

      before do
        group.add_maintainer(user)
      end
    end
  end
end
