# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Container::Cache::Entries, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for container virtual registry api setup'

  describe 'GET /api/v4/virtual_registries/container/upstreams/:id/cache_entries' do
    let(:upstream_id) { upstream.id }
    let(:url) { "/virtual_registries/container/upstreams/#{upstream_id}/cache_entries" }

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response', :freeze_time do
        api_request

        expect(response).to have_gitlab_http_status(:ok)

        response_body = Gitlab::Json.parse(response.body)
        expect(response_body).to be_an(Array)
        expect(response_body.length).to eq(1)

        actual_entry = response_body.first
        expected_entry = cache_entry
          .as_json
          .merge('id' => cache_entry.generate_id)
          .except('object_storage_key', 'file', 'file_store', 'status', 'iid')

        # Compare each field individually to identify the mismatch
        expected_entry.each do |key, expected_value|
          actual_value = actual_entry[key]
          expect(actual_value).to eq(expected_value),
            "Mismatch for key '#{key}': expected #{expected_value.inspect}, got #{actual_value.inspect}"
        end

        # Check for extra fields in actual response
        extra_keys = actual_entry.keys - expected_entry.keys
        expect(extra_keys).to be_empty, "Unexpected keys in response: #{extra_keys.inspect}"
      end
    end

    before_all do
      create(
        :virtual_registries_container_cache_remote_entry,
        :processing,
        upstream: upstream,
        relative_path: cache_entry.relative_path
      )
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'successful response'

    it_behaves_like "authorizing granular token permissions",
      :read_container_virtual_registry_upstream_cache_entry do
      let(:boundary_object) { group }
      let(:request) do
        get api(url, personal_access_token: pat)
      end
    end

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

    it_behaves_like 'virtual registry not available', :container
    it_behaves_like 'virtual registry non member user access', registry_factory: :virtual_registries_container_registry,
      upstream_factory: :virtual_registries_container_upstream
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
  end

  describe 'DELETE /api/v4/virtual_registries/container/cache_entries/*id' do
    let(:id) { cache_entry.generate_id }
    let(:url) { "/virtual_registries/container/cache_entries/#{id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change {
          VirtualRegistries::Container::Cache::Remote::Entry.first.status
        }.from('default').to('pending_destruction')

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

        it_behaves_like "authorizing granular token permissions",
          :delete_container_virtual_registry_upstream_cache_entry do
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

      it_behaves_like 'returning response status with message',
        status: :bad_request,
        message: { 'cache_entry' => ['error message'] }
    end
  end
end
