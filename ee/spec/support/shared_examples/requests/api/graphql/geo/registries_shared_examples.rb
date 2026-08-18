# frozen_string_literal: true

RSpec.shared_examples 'gets registries for' do |args|
  let(:field_name) { args[:field_name] }
  let(:registry_class_name) { args[:registry_class_name] }
  let(:registry_factory) { args[:registry_factory] }
  let(:registry_foreign_key_field_name) { args[:registry_foreign_key_field_name] }
  let(:replicator_class) { Geo.const_get(registry_class_name, false).replicator_class }
  let(:feature_flag) { replicator_class.replication_enabled_feature_key }
  let(:verification_enabled) { replicator_class.verification_enabled? }
  let(:registry_foreign_key) { registry_foreign_key_field_name.underscore }
  let(:field_name_sym) { field_name.underscore.to_sym }

  include GraphqlHelpers
  include EE::GeoHelpers

  let_it_be(:secondary, freeze: false) { create(:geo_node) }
  let!(:registry1) { create(registry_factory) } # rubocop:disable Rails/SaveBang
  let!(:registry2) { create(registry_factory) } # rubocop:disable Rails/SaveBang

  let(:query) do
    excluded = verification_enabled ? [] : %w[verifiedAt verificationRetryAt]

    <<~QUERY
      {
        geoNode {
          #{field_name} {
            nodes {
              #{all_graphql_fields_for(registry_class_name, excluded: excluded)}
            }
          }
        }
      }
    QUERY
  end

  let(:current_user) { create(:user, :admin) }

  before do
    stub_current_geo_node(secondary)
    stub_current_node_name(secondary.name)
  end

  it_behaves_like 'a working graphql query' do
    before do
      post_graphql(query, current_user: current_user)
    end
  end

  it 'returns registries' do
    expected = [registry1, registry2].map do |registry|
      registry_to_graphql_data_hash(registry)
    end

    post_graphql(query, current_user: current_user)

    actual = graphql_data_at(:geo_node, field_name_sym, :nodes)
    expect(actual).to eq(expected)
  end

  context 'with count limit' do
    let!(:expected_registry3) { create(registry_factory, :failed) }

    def query_count(limit: '', params: '')
      <<~QUERY
        {
          geoNode {
            #{field_name}#{params} {
              count#{limit}
            }
          }
        }
      QUERY
    end

    it 'returns registries count' do
      post_graphql(query_count, current_user: current_user)

      actual = graphql_data_at(:geo_node, field_name_sym, :count)
      expect(actual).to eq(3)
    end

    it 'returns limited registries count' do
      post_graphql(query_count(limit: '(limit: 1)'), current_user: current_user)

      actual = graphql_data_at(:geo_node, field_name_sym, :count)
      expect(actual).to eq(2)
    end

    it 'returns an error when limit is too large' do
      post_graphql(query_count(limit: '(limit: 1500)'), current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => 'limit must be less than or equal to 1000'))
    end

    it 'returns count of filtered registries' do
      post_graphql(query_count(params: '(replicationState: FAILED)'), current_user: current_user)

      actual = graphql_data_at(:geo_node, field_name_sym, :count)
      expect(actual).to eq(1)
    end
  end

  context 'when paginating' do
    let!(:expected_registry1) { create(registry_factory) } # rubocop:disable Rails/SaveBang
    let!(:expected_registry2) { create(registry_factory) } # rubocop:disable Rails/SaveBang

    def query(registries_params)
      <<~QUERY
        {
          geoNode {
            #{field_name}(#{registries_params}) {
              edges {
                node {
                  id
                }
                cursor
              }
              pageInfo {
                endCursor
                hasNextPage
              }
            }
          }
        }
      QUERY
    end

    it 'supports cursor-based pagination' do
      post_graphql(query('first: 2'), current_user: current_user)

      edges = graphql_data_at(:geo_node, field_name_sym, :edges)
      page_info = graphql_data_at(:geo_node, field_name_sym, :page_info)
      has_next_page = graphql_data_at(:geo_node, field_name_sym, :page_info, :has_next_page)

      expect(edges.size).to eq(2)
      expect(page_info).to be_present
      expect(has_next_page).to eq(true)
    end

    it 'returns the correct page of registries' do
      # Get first page
      post_graphql(query('first: 2'), current_user: current_user)
      end_cursor = graphql_data_at(:geo_node, field_name_sym, :page_info, :end_cursor)

      # Get second page
      post_graphql(query("first: 2, after: \"#{end_cursor}\""), current_user: current_user)

      response_data = Gitlab::Json.parse(response.body).dig('data', 'geoNode', GraphqlHelpers.fieldnamerize(field_name), 'edges')
      first_result = response_data.first['node']
      second_result = response_data.second['node']

      expect(first_result).to eq('id' => expected_registry1.to_global_id.to_s)
      expect(second_result).to eq('id' => expected_registry2.to_global_id.to_s)
    end
  end

  context 'for data_management_details_path field' do
    let(:query_with_path) do
      <<~QUERY
        {
          geoNode {
            #{field_name} {
              nodes {
                id
                modelRecordId
                dataManagementDetailsPath
              }
            }
          }
        }
      QUERY
    end

    context 'when registry is valid' do
      it 'returns the data management details path' do
        post_graphql(query_with_path, current_user: current_user)

        actual = graphql_data_at(:geo_node, field_name_sym, :nodes)

        [registry1, registry2].each do |registry|
          registry_data = actual.find { |r| r['id'] == registry.to_global_id.to_s }
          expected_path = data_management_details_path_for_registry(registry)
          expect(registry_data['dataManagementDetailsPath']).to eq(expected_path)
        end
      end
    end

    context 'when registry has no model_record_id' do
      before do
        allow_next_found_instance_of(registry1.class) do |instance|
          allow(instance).to receive(:model_record_id).and_return(nil)
        end
      end

      it 'returns nil for data management details path' do
        post_graphql(query_with_path, current_user: current_user)

        actual = graphql_data_at(:geo_node, field_name_sym, :nodes)
        registry_data = actual.find { |r| r['id'] == registry1.to_global_id.to_s }

        expect(registry_data['dataManagementDetailsPath']).to be_nil
      end
    end
  end

  private

  def registry_to_graphql_data_hash(registry)
    data = {
      'id' => registry.to_global_id.to_s,
      registry_foreign_key_field_name => registry.send(registry_foreign_key).to_s,
      'state' => registry.state_name.to_s.upcase,
      'retryCount' => registry.retry_count,
      'lastSyncFailure' => registry.last_sync_failure,
      'retryAt' => registry.retry_at,
      'lastSyncedAt' => registry.last_synced_at,
      'createdAt' => registry.created_at.iso8601,
      'forceToRedownload' => registry.try(:force_to_redownload),
      'missingOnPrimary' => registry.try(:missing_on_primary),
      'checksumMismatch' => registry.checksum_mismatch,
      'verificationChecksumMismatched' => registry.verification_checksum_mismatched,
      'modelRecordId' => registry.model_record_id,
      'verificationChecksum' => registry.verification_checksum,
      'verificationFailure' => registry.verification_failure,
      'verificationRetryCount' => registry.verification_retry_count,
      'verificationStartedAt' => registry.verification_started_at,
      'verificationState' => registry.verification_state_name_no_prefix.upcase,
      'dataManagementDetailsPath' => data_management_details_path_for_registry(registry)
    }

    return data unless verification_enabled

    data.merge({ 'verifiedAt' => registry.verified_at, 'verificationRetryAt' => registry.verification_retry_at })
  end

  def data_management_details_path_for_registry(registry)
    "/admin/data_management/#{replicator_class.model_name.pluralize}/#{registry.model_record_id}"
  end
end
