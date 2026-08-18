# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::WorkItem, :elastic_helpers, feature_category: :global_search do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user_project) { create(:project, namespace: create(:namespace)) }
  let_it_be(:work_item) do
    group_milestone = create(:milestone, group: group, start_date: Date.tomorrow, due_date: 1.week.from_now)
    create(:work_item, :opened, labels: [label], namespace: group, milestone: group_milestone,
      health_status: :on_track, weight: 3)
  end

  let_it_be_with_reload(:user_work_item) do
    user_project_milestone = create(:milestone, project: user_project, start_date: Date.tomorrow,
      due_date: 1.week.from_now)
    create(:work_item, :opened, labels: [label], milestone: user_project_milestone,
      project: user_project, health_status: :on_track, weight: 3)
  end

  let_it_be(:project_work_item) do
    project_milestone = create(:milestone, project: project, start_date: Date.tomorrow, due_date: 1.week.from_now)
    create(:work_item, :opened, labels: [label], project: project, milestone: project_milestone,
      health_status: :on_track, weight: 3)
  end

  before do
    allow(Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
  end

  describe '#as_indexed_json' do
    let(:base_work_item_hash) do
      {
        project_id: object.reload.project_id,
        id: object.id,
        iid: object.iid,
        root_namespace_id: object.namespace.root_ancestor.id,
        hashed_root_namespace_id: object.namespace.hashed_root_namespace_id,
        created_at: object.created_at,
        updated_at: object.updated_at,
        title: object.title,
        description: object.description,
        state: object.state,
        upvotes: object.upvotes_count,
        hidden: object.hidden?,
        work_item_type_id: object.work_item_type_id,
        confidential: object.confidential,
        author_id: object.author_id,
        label_ids: [label.id.to_s],
        assignee_id: object.issue_assignee_user_ids,
        due_date: object.due_date,
        traversal_ids: "#{object.namespace.id}-",
        schema_version: schema_version,
        routing: object.es_parent,
        type: 'work_item',
        milestone_title: object.milestone&.title,
        milestone_id: object.milestone_id,
        health_status: object.health_status_for_database,
        weight: object.weight,
        milestone_start_date: object.milestone&.start_date,
        milestone_due_date: object.milestone&.due_date,
        milestone_state: object.milestone&.state,
        label_names: object.label_names,
        closed_at: object.closed_at
      }
    end

    let(:work_item_reference) { described_class.new(object.id, object.es_parent) }
    let(:schema_version) { work_item_reference.schema_version }

    subject(:indexed_json) { work_item_reference.as_indexed_json.with_indifferent_access }

    describe 'user namespace work item' do
      let(:object) { user_work_item }
      let(:expected_hash) do
        base_work_item_hash.merge(
          archived: object.project.self_or_ancestors_archived?,
          traversal_ids: object.namespace.elastic_namespace_ancestry,
          project_visibility_level: object.project.visibility_level,
          issues_access_level: object.project.issues_access_level
        )
      end

      it 'serializes work_item as a hash' do
        expect(indexed_json).to match(expected_hash)
      end
    end

    describe 'group namespace work item' do
      let(:object) { work_item }
      let(:expected_hash) do
        base_work_item_hash.merge(
          root_namespace_id: parent_group.id,
          traversal_ids: "#{parent_group.id}-#{group.id}-",
          namespace_visibility_level: group.visibility_level,
          namespace_id: group.id
        )
      end

      it 'serializes work_item as a hash' do
        expect(indexed_json).to match(expected_hash)
      end
    end

    describe 'project namespace work item' do
      let(:object) { project_work_item }
      let(:expected_hash) do
        base_work_item_hash.merge(
          root_namespace_id: project_work_item.namespace.root_ancestor.id,
          traversal_ids: project_work_item.namespace.elastic_namespace_ancestry,
          archived: project.self_or_ancestors_archived?,
          project_visibility_level: project.visibility_level,
          issues_access_level: project.issues_access_level
        )
      end

      it 'serializes work_item as a hash' do
        expect(indexed_json).to match(expected_hash)
      end
    end

    describe 'work item with broken namespace hierarchy' do
      let(:work_item_reference) { described_class.new(work_item.id, work_item.es_parent) }

      context 'when namespace is nil' do
        before do
          work_item_reference.database_record = work_item
          allow(work_item).to receive(:namespace).and_return(nil)
        end

        it 'raises DocumentShouldBeDeletedFromIndexError' do
          expect { work_item_reference.as_indexed_json }
            .to raise_error(::Elastic::Latest::DocumentShouldBeDeletedFromIndexError)
        end
      end

      context 'when namespace root ancestor is nil (broken traversal_ids ancestry chain)' do
        before do
          work_item_reference.database_record = work_item
          allow(work_item.namespace).to receive(:root_ancestor).and_return(nil)
        end

        it 'raises DocumentShouldBeDeletedFromIndexError' do
          expect { work_item_reference.as_indexed_json }
            .to raise_error(::Elastic::Latest::DocumentShouldBeDeletedFromIndexError)
        end
      end
    end
  end

  describe '#instantiate' do
    let(:work_item_ref) { described_class.new(work_item.id, work_item.es_parent) }

    it 'instantiates work item' do
      new_work_item = described_class.instantiate(work_item_ref.serialize)
      expect(new_work_item.routing).to eq(work_item.es_parent)
      expect(new_work_item.identifier).to eq(work_item.id)
    end
  end

  describe '#serialize' do
    it 'returns serialized string of work item record from class method' do
      expect(described_class.serialize(work_item)).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end

    it 'returns serialized string of work item record from instance method' do
      expect(described_class.new(work_item.id,
        work_item.es_parent).serialize).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end
  end

  describe '#model_klass' do
    it 'returns correct environment based index name from class' do
      expect(described_class.new(work_item.id, work_item.es_parent).model_klass).to eq(WorkItem)
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name from class method' do
      expect(described_class.index).to eq('gitlab-test-work_items')
    end

    it 'returns correct environment based index name from instance method' do
      expect(described_class.new(work_item.id, work_item.es_parent).index_name).to eq('gitlab-test-work_items')
    end

    it 'uses custom elasticsearch_prefix setting' do
      allow(Gitlab::CurrentSettings).to receive(:elasticsearch_prefix).and_return('custom-prefix')

      expect(described_class.index).to eq('custom-prefix-test-work_items')
      expect(described_class.new(work_item.id, work_item.es_parent).index_name).to eq('custom-prefix-test-work_items')
    end
  end

  describe '#schema_version' do
    subject(:work_item_reference) { described_class.new(work_item.id, work_item.es_parent) }

    it 'returns the latest schema version' do
      expect(work_item_reference.schema_version).to eq(25_44)
    end

    context 'with SCHEMA_VERSIONS hash validation' do
      it 'SCHEMA_VERSION constant returns the maximum version dynamically' do
        max_version = described_class::SCHEMA_VERSIONS.keys.max
        expect(described_class::SCHEMA_VERSION).to eq(max_version)
      end

      it 'ensures nil migration is always the lowest schema version' do
        nil_versions = described_class::SCHEMA_VERSIONS.select { |_version, migration| migration.nil? }
        expect(nil_versions).not_to be_empty, 'SCHEMA_VERSIONS should have at least one nil migration for baseline'

        lowest_version = described_class::SCHEMA_VERSIONS.keys.min
        expect(described_class::SCHEMA_VERSIONS[lowest_version]).to be_nil,
          'The lowest schema version should always have nil migration (baseline)'
      end

      it 'ensures schema versions align with migration chronological order' do
        versioned_migrations = described_class::SCHEMA_VERSIONS.reject { |_version, migration| migration.nil? }

        next if versioned_migrations.size < 2

        migration_versions = {}
        versioned_migrations.each do |schema_version, migration_name|
          migration_record = ::Elastic::DataMigrationService.find_by_name(migration_name)
          expect(migration_record).not_to be_nil, "Migration '#{migration_name}' not found in DataMigrationService"
          migration_versions[schema_version] = migration_record.version
        end

        sorted_by_schema_version = migration_versions.sort_by { |schema_version, _migration_version| schema_version }
        sorted_by_migration_version = migration_versions.sort_by do |_schema_version, migration_version|
          migration_version
        end

        expect(sorted_by_schema_version.map(&:first)).to eq(sorted_by_migration_version.map(&:first)),
          'Schema versions must increase with migration chronological order. ' \
            "Schema order: #{sorted_by_schema_version.map { |s, m| "#{s}(migration:#{m})" }}, " \
            "Migration order: #{sorted_by_migration_version.map { |s, m| "#{s}(migration:#{m})" }}"
      end
    end

    context 'with custom SCHEMA_VERSIONS scenarios' do
      let(:original_schema_versions) { described_class::SCHEMA_VERSIONS }

      before do
        stub_const("#{described_class}::SCHEMA_VERSIONS", custom_schema_versions)
        # Simulate different migration states
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(false)
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:index_work_items_milestone).and_return(true)
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:intermediate_migration).and_return(true)
      end

      after do
        stub_const("#{described_class}::SCHEMA_VERSIONS", original_schema_versions)
      end

      context 'with multiple migrations in different states' do
        let(:custom_schema_versions) do
          {
            25_50 => :future_migration,
            25_43 => :index_work_items_milestone,
            25_30 => :intermediate_migration,
            25_27 => nil
          }
        end

        it 'returns the highest version with finished or nil migration' do
          expect(work_item_reference.schema_version).to eq(25_43)
        end
      end

      context 'when only baseline migration (nil) is available' do
        let(:custom_schema_versions) do
          {
            25_50 => :future_migration,
            25_27 => nil
          }
        end

        before do
          stub_const("#{described_class}::SCHEMA_VERSIONS", custom_schema_versions)
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(false)
        end

        it 'falls back to baseline version' do
          expect(work_item_reference.schema_version).to eq(25_27)
        end
      end

      context 'with intermediate migration finished but not the latest' do
        let(:custom_schema_versions) do
          {
            25_50 => :future_migration,
            25_40 => :intermediate_migration,
            25_27 => nil
          }
        end

        before do
          stub_const("#{described_class}::SCHEMA_VERSIONS", custom_schema_versions)
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(false)
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
            .with(:intermediate_migration).and_return(true)
        end

        it 'returns the highest finished migration version' do
          expect(work_item_reference.schema_version).to eq(25_40)
        end
      end

      context 'when all migrations are finished' do
        let(:custom_schema_versions) do
          {
            25_50 => :latest_migration,
            25_43 => :index_work_items_milestone,
            25_27 => nil
          }
        end

        before do
          stub_const("#{described_class}::SCHEMA_VERSIONS", custom_schema_versions)
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
        end

        it 'returns the highest schema version' do
          expect(work_item_reference.schema_version).to eq(25_50)
        end
      end
    end
  end
end
