# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::DataManagement, :aggregate_failures, :request_store, :geo, :api, feature_category: :geo_replication do
  include ApiHelpers
  include EE::GeoHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  describe 'GET /data_management/:model_name' do
    it_behaves_like 'authorizing granular token permissions', :read_admin_data_management do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api("/admin/data_management/snippet_repositories", personal_access_token: pat) }
    end

    context 'when authenticated as admin' do
      context 'with valid model name' do
        let(:api_path) { "/admin/data_management/snippet_repositories" }

        it 'returns matching object data' do
          expected_model = create(:snippet_repository)

          get api(api_path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first).to include('record_identifier' => record_identifier(expected_model),
            'model_class' => expected_model.class.name)
        end

        context 'with pagination and ordering' do
          it 'paginates results correctly' do
            create_list(:snippet_repository, 6)

            get api("#{api_path}?per_page=5", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(5)
            expect(response.headers['X-Next-Page']).to eq('2')
            expect(response.headers['X-Page']).to eq('1')
            expect(response.headers['X-Per-Page']).to eq('5')

            get api("#{api_path}?per_page=5&page=2", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(1) # Remaining 1 record
            expect(response.headers['X-Page']).to eq('2')
            expect(response.headers['X-Next-Page']).to be_empty
          end

          it 'handles pagination with ordering correctly' do
            create_list(:ee_ci_job_artifact, 4)

            get api("/admin/data_management/ci_job_artifacts?per_page=3", admin, admin_mode: true)
            first_page_ids = json_response.pluck('record_identifier')

            get api("/admin/data_management/ci_job_artifacts?per_page=3&page=2", admin, admin_mode: true)
            second_page_ids = json_response.pluck('record_identifier')

            # Verify ordering is maintained across pages
            expect(first_page_ids).to eq(first_page_ids.sort)
            expect(second_page_ids).to eq(second_page_ids.sort)
            expect(first_page_ids.last).to be < second_page_ids.first
          end
        end

        context 'with keyset pagination and ordering' do
          let_it_be(:list) { create_list(:snippet_repository, 3) }

          it 'returns first page with cursor to next page' do
            get api(api_path, admin, admin_mode: true), params: { pagination: 'keyset', per_page: 2 }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(2)
            expect(json_response.pluck('record_identifier')).to contain_exactly(list.first.id, list.second.id)
            expect(response.headers["Link"]).to include("cursor")
            next_cursor = response.headers["Link"].match("(?<cursor_data>cursor=.*?)&")["cursor_data"]

            get api(api_path, admin, admin_mode: true),
              params: { pagination: 'keyset', per_page: 2 }.merge(Rack::Utils.parse_query(next_cursor))

            expect(json_response.size).to eq(1)
            expect(json_response.pluck('record_identifier')).to contain_exactly(list.last.id)
            expect(response.headers).not_to include("Link")
          end

          it 'orders descending results correctly' do
            get api(api_path, admin, admin_mode: true), params: { pagination: 'keyset', per_page: 3, sort: 'desc' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(3)
            expect(json_response.pluck('record_identifier')).to eq(list.map(&:id).reverse)
          end

          it 'orders ascending results correctly' do
            get api(api_path, admin, admin_mode: true), params: { pagination: 'keyset', per_page: 3, sort: 'asc' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(3)
            expect(json_response.pluck('record_identifier')).to eq(list.map(&:id))
          end
        end

        context 'with composite ids' do
          let_it_be(:list) { create_list(:virtual_registries_packages_maven_cache_remote_entry, 6) }
          let_it_be(:ids_list) { list.map { |model| record_identifier(model) } }
          # We're using this Entry model because it will be the first model with composite PKs supported by Geo.
          # The model isn't Geo-ready yet, so we need to mock its interface in this test to simulate its future
          # implementation.
          let_it_be(:orderable_klass) do
            Class.new(list.first.class) do
              include Orderable
            end
          end

          before do
            # The VirtualRegistries::Packages::Maven::Cache::Remote::Entry model is not in the allowed list yet.
            # This is why we need to force the ModelMapper to return the stubbed class instead of the model
            # passed as parameters.
            allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name)
                                                  .with('snippet_repository')
                                                  .and_return(orderable_klass)
          end

          it 'filters passed ids' do
            get api("#{api_path}?identifiers[]=#{ids_list.first}&identifiers[]=#{ids_list.last}",
              admin,
              admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.pluck('record_identifier')).to match_array([ids_list.first, ids_list.last])
            expect(json_response.size).to eq(2)
          end

          context 'with offset pagination' do
            it 'paginates results' do
              get api("#{api_path}?per_page=5", admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(5)
              expect(response.headers['X-Next-Page']).to eq('2')
              expect(response.headers['X-Page']).to eq('1')
              expect(response.headers['X-Per-Page']).to eq('5')

              get api("#{api_path}?per_page=5&page=2", admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(1) # Remaining 1 record
              expect(response.headers['X-Page']).to eq('2')
              expect(response.headers['X-Next-Page']).to be_empty
            end
          end

          context 'with keyset pagination and ordering' do
            it 'returns first page with cursor to next page' do
              get api(api_path, admin, admin_mode: true), params: { pagination: 'keyset', per_page: 5 }

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(5)

              expect(json_response.pluck('record_identifier')).to match_array(ids_list.first(5))
              expect(response.headers["Link"]).to include("cursor")
              next_cursor = response.headers["Link"].match("(?<cursor_data>cursor=.*?)&")["cursor_data"]

              get api(api_path, admin, admin_mode: true),
                params: { pagination: 'keyset', per_page: 5 }.merge(Rack::Utils.parse_query(next_cursor))

              expect(json_response.size).to eq(1)
              expect(json_response.pluck('record_identifier')).to match_array(ids_list.last(1))
              expect(response.headers).not_to include("Link")
            end

            it 'orders descending results correctly' do
              get api(api_path, admin, admin_mode: true), params: { pagination: 'keyset', per_page: 6, sort: 'desc' }

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(6)
              expect(json_response.pluck('record_identifier')).to eq(ids_list.reverse)
            end

            it 'orders ascending results correctly' do
              get api(api_path, admin, admin_mode: true), params: { pagination: 'keyset', per_page: 6, sort: 'asc' }

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(6)
              expect(json_response.pluck('record_identifier')).to eq(ids_list)
            end
          end
        end

        context 'with filtering based on ids' do
          context 'with integer ids' do
            let(:list) { create_list(:project_wiki_repository, 3) }
            let(:path) { "/admin/data_management/projects_wiki_repositories" }

            it 'filters passed ids' do
              get api("#{path}?identifiers[]=#{list.first.id}&identifiers[]=#{list.last.id}",
                admin,
                admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.pluck('record_identifier')).to match_array([list.first.id, list.last.id])
              expect(json_response.size).to eq(2)
            end
          end

          context 'with invalid ids' do
            it 'returns 400 with mixed ids' do
              fake_b64 = Base64.urlsafe_encode64('1 2 3')

              get api("/admin/data_management/uploads?identifiers[]=1&identifiers[]=#{fake_b64}",
                admin,
                admin_mode: true)

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to include('invalid base64')
            end

            it 'returns 400 with invalid composite keys' do
              fake_ids = [Base64.urlsafe_encode64('1 2 3'), Base64.urlsafe_encode64('4-5-6')]
              url = "/admin/data_management/uploads?identifiers[]=#{fake_ids.first}&identifiers[]=#{fake_ids.last}"

              get api(url, admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to include('Invalid composite key format')
            end

            it 'does not filter with empty ids' do
              list = create_list(:external_merge_request_diff, 3)

              get api("/admin/data_management/merge_request_diffs?identifiers[]=", admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.pluck('record_identifier')).to match_array(list.map(&:id))
              expect(json_response.size).to eq(3)
            end
          end
        end

        context 'with filtering based on status' do
          context 'with valid status' do
            let_it_be(:node) { create(:geo_node) }
            let(:succeeded_record) { build(:upload, :verification_succeeded) }
            let(:failed_record) { build(:upload, :verification_failed) }
            let(:pending_record) { build_record_for_given_state(:verification_pending) }
            let(:started_record) { build_record_for_given_state(:verification_started) }
            let(:disabled_record) { build_record_for_given_state(:verification_disabled) }

            def build_record_for_given_state(state)
              build(:upload, verification_state: Upload.verification_state_value(state))
            end

            before do
              stub_current_geo_node(node)
              stub_primary_site

              succeeded_record.save!
              failed_record.save!
              pending_record.save!
              started_record.save!
              disabled_record.save!
            end

            where(status: %w[pending started succeeded failed disabled])
            with_them do
              it 'returns matching object data' do
                get api("/admin/data_management/uploads?checksum_state=#{status}", admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.first).to include('record_identifier' => send(:"#{status}_record").id)
                expect(json_response.size).to eq(1)
              end
            end
          end

          context 'with invalid status' do
            it 'returns 400' do
              get api('/admin/data_management/projects?checksum_state=invalid', admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end

          context 'for a model with separate verification state table' do
            let_it_be(:node) { create(:geo_node) }
            let_it_be(:succeeded_record) { create(:nuget_symbol, :verification_succeeded) }
            let_it_be(:failed_record) { create(:nuget_symbol, :verification_failed) }

            before do
              stub_current_geo_node(node)
              stub_primary_site
            end

            it 'returns matching object data' do
              get api('/admin/data_management/packages_nuget_symbols?checksum_state=succeeded', admin,
                admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.first).to include('record_identifier' => succeeded_record.id)
              expect(json_response.size).to eq(1)
            end
          end
        end
      end

      context 'with case variations' do
        it 'returns 400 for uppercase model names' do
          get api('/admin/data_management/LFS_OBJECTS', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'returns 400 for mixed case model names' do
          get api('/admin/data_management/Lfs_Objects', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'with invalid model names' do
        # Edge cases - invalid inputs
        it 'returns 400 for non-existent model name' do
          get api('/admin/data_management/non_existent_model', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'returns 404 for empty model name' do
          get api('/admin/data_management/', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with boundary length inputs' do
        # Boundary cases - very long strings
        it 'handles very long model names gracefully' do
          long_model_name = 'a' * 1000
          get api("/admin/data_management/#{long_model_name}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'handles single character model name' do
          get api('/admin/data_management/a', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'with URL encoding' do
        # Edge cases - URL encoded characters
        it 'handles URL encoded model names' do
          get api('/admin/data_management/lfs%5Fobjects', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'handles URL encoded special characters' do
          get api('/admin/data_management/lfs%40object', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when model exists but no records' do
        it 'returns the model class even when no records exist' do
          get api("/admin/data_management/uploads", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq([])
        end
      end
    end

    context 'when not authenticated as admin' do
      # Security boundary tests
      it 'denies access for regular users' do
        get api('/admin/data_management/lfs_objects', user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'denies access for unauthenticated requests' do
        get api('/admin/data_management/lfs_objects')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'denies access for admin without admin mode' do
        get api('/admin/data_management/lfs_objects', admin)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when ModelMapper raises exceptions' do
      # Edge cases - error handling
      it 'handles ModelMapper exceptions gracefully' do
        allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name)
                                              .and_raise(StandardError)

        get api('/admin/data_management/lfs_objects', admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:internal_server_error)
      end

      it 'handles nil return from ModelMapper' do
        allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name)
                                              .and_return(nil)

        get api('/admin/data_management/lfs_objects', admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PUT /admin/data_management/:model_name/checksum' do
    let_it_be(:node) { create(:geo_node) }
    let_it_be(:api_path) { "/admin/data_management/merge_request_diffs/checksum" }

    before do
      stub_current_geo_node(node)
      stub_primary_site
    end

    it_behaves_like 'authorizing granular token permissions', :update_admin_data_management do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { put api(api_path, personal_access_token: pat) }
    end

    context 'when authenticated as admin' do
      context 'when not on primary site' do
        before do
          allow(Gitlab::Geo).to receive(:primary?).and_return(false)
        end

        it 'returns 400 bad request' do
          put api(api_path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('400 Bad request - Endpoint only available on primary site.')
        end
      end

      context 'with valid model name' do
        it 'returns service result' do
          expect(::Geo::BulkPrimaryVerificationService).to receive(:new)
                                                              .with("MergeRequestDiff", {})
                                                              .and_call_original

          put api(api_path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('status' => 'success')
        end

        it 'handles parameters appropriately' do
          allow(::Geo::BulkPrimaryVerificationService).to receive(:new).and_call_original
          list = create_list(:external_merge_request_diff, 3, :verification_failed)

          put api("#{api_path}?identifiers[]=#{list.first.id}&identifiers[]=#{list.last.id}&checksum_state=failed",
            admin,
            admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(::Geo::BulkPrimaryVerificationService).to have_received(:new) do |*args|
            expect(args.first).to eq('MergeRequestDiff')
            expect(args.second[:checksum_state]).to eq("verification_failed")
            expect(args.second[:identifiers]).to contain_exactly(list.first.verification_state_object.id,
              list.last.verification_state_object.id)
          end
        end

        context 'when service returns an error' do
          before do
            allow(::Geo::BulkPrimaryVerificationService).to receive_message_chain(:new, :async_execute)
                                                              .and_return(ServiceResponse.error(message: 'Error'))
          end

          it 'returns error message' do
            put api(api_path, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('status' => 'error')
          end
        end
      end

      context 'with invalid model names' do
        # Edge cases - invalid inputs
        it 'returns 400 for non-existent model name' do
          put api('/admin/data_management/non_existent_model/checksum', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'returns 404 for empty model name' do
          put api('/admin/data_management/checksum', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with URL encoding' do
        # Edge cases - URL encoded characters
        it 'handles URL encoded model names' do
          put api('/admin/data_management/lfs%5Fobjects/checksum', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'handles URL encoded special characters' do
          put api('/admin/data_management/lfs%40objects/checksum', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when not authenticated as admin' do
      # Security boundary tests
      it 'denies access for regular users' do
        put api(api_path, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'denies access for unauthenticated requests' do
        put api(api_path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'denies access for admin without admin mode' do
        put api(api_path, admin)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /admin/data_management/:model_name/:record_identifier' do
    it_behaves_like 'authorizing granular token permissions', :read_admin_data_management do
      let_it_be(:gpat_model) { create(:snippet_repository) }
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        get api("/admin/data_management/snippet_repositories/#{gpat_model.id}", personal_access_token: pat)
      end
    end

    context 'with valid model name' do
      let(:expected_model) { create(:snippet_repository) }

      context 'with valid integer id' do
        it 'returns matching object data' do
          get api("/admin/data_management/snippet_repositories/#{expected_model.id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('record_identifier' => expected_model.id,
            'model_class' => expected_model.class.name)
        end
      end

      context 'with valid base64 id' do
        let_it_be(:model) { create(:virtual_registries_packages_maven_cache_remote_entry) }
        # We're using this Entry model because it will be the first model with composite PKs supported by Geo.
        # The model isn't Geo-ready yet, so we need to mock its interface in this test to simulate its future
        # implementation.
        let_it_be(:stubbed_class) do
          Class.new(model.class) do
            include Geo::HasReplicator
          end
        end

        let_it_be(:base64_id) do
          pks = model.class.primary_key
          ids = pks.map { |field| model.read_attribute_before_type_cast(field).to_s }
          Base64.urlsafe_encode64(ids.join(' '))
        end

        before do
          # The VirtualRegistries::Packages::Maven::Cache::Remote::Entry model is not in the allowed list.
          # This is why the url matches`uploads` but I force the ModelMapper to return the stubbed class instead.
          allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name).with('upload').and_return(stubbed_class)
        end

        it 'returns matching object data' do
          get api("/admin/data_management/uploads/#{base64_id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('record_identifier' => base64_id)
        end
      end

      context 'with invalid id' do
        it 'returns 404 when ID does not exist' do
          get api("/admin/data_management/snippet_repositories/#{non_existing_record_id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 400 when ID is alphanumeric containing valid ID' do
          get api("/admin/data_management/snippet_repositories/rand#{expected_model.id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'with invalid base64 id' do
        let(:model) { create(:virtual_registries_packages_maven_cache_remote_entry) }
        let(:base64_id) do
          expected_id = model.class.primary_key.map { |field| model[field.to_sym].to_s }
          Base64.urlsafe_encode64(expected_id.join('-'))
        end

        before do
          # The VirtualRegistries::Packages::Maven::Cache::Remote::Entry model is not in the allowed list.
          # This is why the url matches`uploads` but I force the ModelMapper to return
          # the MavenCacheEntry double instead of the normally expected `Upload`.
          allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name).with('upload').and_return(model.class)
        end

        it 'returns 400 when base64 does not contain spaces' do
          get api("/admin/data_management/uploads/#{base64_id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to include('message' => '400 Bad request - Invalid composite key format')
        end
      end
    end

    context 'with invalid model names' do
      # Edge cases - invalid inputs
      it 'returns 400 for non-existent model name' do
        get api('/admin/data_management/non_existent_model/1', admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 for empty model name' do
        get api('/admin/data_management//1', admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when model exists but no records' do
      it 'returns not_found when no records exist' do
        get api("/admin/data_management/uploads/1", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when not authenticated as admin' do
      # Security boundary tests
      it 'denies access for regular users' do
        get api('/admin/data_management/projects/1', user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'denies access for unauthenticated requests' do
        get api('/admin/data_management/projects/1')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'denies access for admin without admin mode' do
        get api('/admin/data_management/projects/1', admin)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /admin/data_management/:model_name/:record_identifier/checksum' do
    let(:expected_model) { create(:upload, :with_file) }
    let(:api_path) { "/admin/data_management/uploads/#{expected_model.id}/checksum" }
    let_it_be(:node) { create(:geo_node) }

    before do
      stub_current_geo_node(node)
      stub_primary_site
    end

    it_behaves_like 'authorizing granular token permissions', :update_admin_data_management do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { put api(api_path, personal_access_token: pat) }
    end

    context 'when not on primary site' do
      before do
        allow(Gitlab::Geo).to receive(:primary?).and_return(false)
      end

      it 'returns 400 bad request' do
        put api(api_path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('400 Bad request - Endpoint only available on primary site.')
      end
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        put api(api_path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is not an admin' do
      it 'returns 403 forbidden' do
        put api(api_path, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with valid model name' do
      context 'with valid id' do
        it 'returns successful message' do
          put api(api_path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('record_identifier' => expected_model.id,
            'model_class' => expected_model.class.name)
        end

        context 'when model is not replicable' do
          before do
            allow(expected_model.class).to receive(:respond_to?).with(:replicator_class).and_return(false)
          end

          it 'returns 400 bad request' do
            put api(api_path, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('is not a verifiable model')
          end
        end

        context 'when model is not verifiable' do
          before do
            allow(expected_model.class.replicator_class).to receive(:verification_enabled?).and_return(false)
          end

          it 'returns 400 bad request' do
            put api(api_path, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('is not a verifiable model')
          end
        end

        context 'when verification fails' do
          # An upload without file won't be able to get successfully checksummed
          let(:expected_model) { create(:upload) }

          it 'returns 400 bad request' do
            put api(api_path, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include("Verifying uploads/#{expected_model.id} failed")
          end
        end
      end
    end
  end

  context 'with all available replicable models' do
    let_it_be(:node) { create(:geo_node) }

    before do
      stub_container_registry_config(enabled: true)
    end

    where(model_classes: Gitlab::Geo::ModelMapper.available_models)
    with_them do
      let(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model_classes).pluralize }
      let(:expected_record) { create(factory_name(model_classes)) } # rubocop:disable Rails/SaveBang -- factory
      let(:api_path) { "/admin/data_management/#{model_name}" }

      context 'for checksum endpoints' do
        before do
          stub_current_geo_node(node)
          stub_primary_site
        end

        describe 'PUT /admin/data_management/:model_name/:record_identifier/checksum' do
          # We stub a successful verification, because default factories might not include verifiable data
          before do
            allow_next_found_instance_of(model_classes.verification_state_table_class) do |instance|
              allow(instance).to receive(:verification_failed?).and_return(false)
            end
          end

          it 'handles all known replicable model names' do
            put api("#{api_path}/#{expected_record.id}/checksum", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('record_identifier' => expected_record.id,
              'model_class' => expected_record.class.name)
          end
        end

        describe 'PUT /admin/data_management/:model_name/checksum' do
          let(:list) { create_list(factory_name(model_classes), 3, :verification_failed) }
          let(:ids_list) { list.map { |model| record_identifier(model) } }

          it 'handles parameters appropriately' do
            allow(::Geo::BulkPrimaryVerificationService).to receive(:new).once.and_call_original
            query_params = "identifiers[]=#{ids_list.first}&identifiers[]=#{ids_list.last}&checksum_state=failed"

            put api("#{api_path}/checksum?#{query_params}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(::Geo::BulkPrimaryVerificationService).to have_received(:new) do |klass, params|
              expect(klass).to eq(list.first.class.name)
              expect(params).to be_a(Hash)
              expect(params[:checksum_state]).to eq("verification_failed")
              expect(params[:identifiers]).to contain_exactly(list.first.verification_state_object.id,
                list.last.verification_state_object.id)
            end
          end
        end
      end

      describe 'GET /data_management/:model_name' do
        it 'handles all known replicable model names' do
          get api(api_path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'orders results by primary key' do
          create_list(factory_name(model_classes), 3)

          get api(api_path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)

          # Extract IDs from response and verify they're in ascending order
          response_ids = json_response.pluck('record_identifier')
          expect(response_ids).to eq(response_ids.sort)
        end
      end

      describe 'GET /admin/data_management/:model_name/:record_identifier' do
        let(:identifier) { record_identifier(expected_record) }

        it 'handles all known replicable model names' do
          get api("#{api_path}/#{identifier}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('record_identifier' => identifier,
            'model_class' => expected_record.class.name)
        end
      end
    end
  end

  def record_identifier(model_record)
    return model_record.id unless model_record.class.primary_key.is_a?(Array)

    Base64.urlsafe_encode64(model_record.class.primary_key
                                        .map { |field| model_record.read_attribute_before_type_cast(field) }
                                        .join(' '))
  end
end
