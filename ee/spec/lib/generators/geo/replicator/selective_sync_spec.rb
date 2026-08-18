# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../lib/generators/geo/replicator/selective_sync'

RSpec.describe Geo::Replicator::SelectiveSync, feature_category: :geo_replication do
  def sync_for(key)
    described_class.new(sharding_key: key, file_name: 'cool_widget', parent_model_factory_name: 'widget')
  end

  describe '#scope_definition' do
    it 'returns the sharding-key scope for the configured key', :aggregate_failures do
      expect(sync_for('project_id').scope_definition)
        .to eq('scope :project_id_in, ->(ids) { where(project_id: ids) }')
      expect(sync_for('organization_id').scope_definition).to include('organization_id_in')
    end
  end

  describe '#raw_selective_sync_scope_body' do
    it 'builds a distinct scope body for every sharding key', :aggregate_failures do
      expect(sync_for('project_id').raw_selective_sync_scope_body)
        .to include('::Project.selective_sync_scope(node)')
      expect(sync_for('namespace_id').raw_selective_sync_scope_body)
        .to include('namespace_id_in(node.namespaces_for_group_owned_replicables')
      expect(sync_for('organization_id').raw_selective_sync_scope_body)
        .to include('organization_id_in(node.organizations.select(:id))')
      expect(sync_for('uploaded_by_user_id').raw_selective_sync_scope_body)
        .to include('OrganizationUser.in_organization')
    end
  end

  describe '#selective_sync_fixtures' do
    it 'builds fixtures referencing the parent factory for every sharding key', :aggregate_failures do
      expect(sync_for('project_id').selective_sync_fixtures)
        .to include('create(:geo_cool_widget, parent_model: create(:widget, project: project_1))')
      expect(sync_for('namespace_id').selective_sync_fixtures).to include('create(:widget, group: group_1)')
      expect(sync_for('organization_id').selective_sync_fixtures)
        .to include('create(:widget, organization: organization_1)')
      expect(sync_for('uploaded_by_user_id').selective_sync_fixtures).to include('create(:widget, user: user_1)')
    end
  end

  describe 'with no sharding key (cell-setting / instance-wide)' do
    let(:sync) { sync_for(nil) }

    it 'returns an empty scope definition' do
      expect(sync.scope_definition).to eq('')
    end

    it 'builds an always-replicate scope body that ignores selective sync', :aggregate_failures do
      body = sync.raw_selective_sync_scope_body

      expect(body).to include('replicables = params.fetch(:replicables, all)')
      expect(body).to include('always replicated regardless')
      expect(body).not_to include('node.selective_sync?')
    end

    it 'returns no selective-sync fixtures' do
      expect(sync.selective_sync_fixtures).to eq('')
    end
  end

  describe 'with an unsupported sharding key' do
    it 'raises a descriptive error instead of a cryptic NoMethodError' do
      expect { sync_for('bogus_id').scope_definition }
        .to raise_error(ArgumentError, /Unsupported sharding key: "bogus_id"/)
    end
  end
end
