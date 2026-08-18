# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::ReindexProjectElasticZoektData, feature_category: :global_search do
  let(:organizations) { table(:organizations) }
  let(:organization) { organizations.create!(name: 'Test Org', path: 'test-org') }
  let(:namespaces) { table(:namespaces) }
  let(:namespace) { namespaces.create!(name: 'Test Group', path: 'test-group', organization_id: organization.id) }
  let(:namespace2) { namespaces.create!(name: 'Test Group2', path: 'test-group2', organization_id: organization.id) }
  let(:namespace3) { namespaces.create!(name: 'Test Group3', path: 'test-group3', organization_id: organization.id) }
  let(:namespace_settings) { table(:namespace_settings) }
  let!(:_ns) { namespace_settings.create!(namespace_id: namespace.id, archived: true) }
  let!(:_ns2) { namespace_settings.create!(namespace_id: namespace2.id, archived: true) }
  let!(:_ns3) { namespace_settings.create!(namespace_id: namespace3.id) }

  let(:migration_args) do
    {
      batch_table: :namespace_settings,
      batch_column: :namespace_id,
      sub_batch_size: 1,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  it 'calls Search::Elastic::GroupArchivedEventWorker, Search::Zoekt::GroupArchivedEventWorker for archived groups' do
    expect(Search::Elastic::GroupArchivedEventWorker).to receive(:perform_async)
      .with('Namespaces::Groups::GroupArchivedEvent', { group_id: namespace.id, root_namespace_id: 0 })
    expect(Search::Zoekt::GroupArchivedEventWorker).to receive(:perform_async)
      .with('Namespaces::Groups::GroupArchivedEvent', { group_id: namespace.id, root_namespace_id: 0 })
    expect(Search::Elastic::GroupArchivedEventWorker).to receive(:perform_async)
      .with('Namespaces::Groups::GroupArchivedEvent', { group_id: namespace2.id, root_namespace_id: 0 })
    expect(Search::Zoekt::GroupArchivedEventWorker).to receive(:perform_async)
      .with('Namespaces::Groups::GroupArchivedEvent', { group_id: namespace2.id, root_namespace_id: 0 })
    expect(Search::Elastic::GroupArchivedEventWorker).not_to receive(:perform_async)
      .with('Namespaces::Groups::GroupArchivedEvent', { group_id: namespace3.id, root_namespace_id: 0 })
    expect(Search::Zoekt::GroupArchivedEventWorker).not_to receive(:perform_async)
      .with('Namespaces::Groups::GroupArchivedEvent', { group_id: namespace3.id, root_namespace_id: 0 })
    described_class.new(**migration_args).perform
  end
end
