# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::ProjectInstanceProxy, :elastic_helpers, feature_category: :global_search do
  let_it_be(:project) { create(:project) }

  let(:schema_version) { 25_06 }

  subject(:proxy) { described_class.new(project) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    ensure_elasticsearch_index! # ensure objects are indexed
    allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
  end

  describe '#as_indexed_json' do
    it 'contains the expected mappings' do
      result = proxy.as_indexed_json.with_indifferent_access.keys
      project_proxy = Elastic::Latest::ApplicationClassProxy.new(Project, use_separate_indices: true)
      # readme_content is not populated by as_indexed_json
      expected_keys = project_proxy.mappings.to_hash[:properties].keys.map(&:to_s) - ['readme_content']

      expect(result).to match_array(expected_keys)
    end

    it 'serializes project as hash' do
      result = proxy.as_indexed_json.with_indifferent_access

      expect(result).to include(
        id: project.id,
        name: project.name,
        path: project.path,
        description: project.description,
        namespace_id: project.namespace_id,
        created_at: project.created_at,
        updated_at: project.updated_at,
        archived: project.self_or_ancestors_archived?,
        last_activity_at: project.last_activity_at,
        name_with_namespace: project.name_with_namespace,
        path_with_namespace: project.path_with_namespace,
        traversal_ids: project.elastic_namespace_ancestry,
        type: 'project',
        visibility_level: project.visibility_level,
        schema_version: schema_version,
        ci_catalog: project.catalog_resource.present?
      )
    end

    context 'when project does not have an owner' do
      it 'does not throw an exception' do
        allow(project).to receive(:owner).and_return(nil)

        result = proxy.as_indexed_json.with_indifferent_access

        expect(result[:owner_id]).to be_nil
      end
    end
  end

  describe '#es_parent' do
    let_it_be(:group) { create(:group) }
    let_it_be(:target) { create(:project, group: group) }

    subject(:es_parent) { described_class.new(target).es_parent }

    it 'is the root namespace id' do
      expect(es_parent).to eq("n_#{group.id}")
    end
  end
end
