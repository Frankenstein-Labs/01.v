# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::BackgroundMigration::BackfillRolledUpWeightForWorkItems, feature_category: :team_planning do
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:users) { table(:users) }
  let(:issues) { table(:issues) }
  let(:work_item_types) { table(:work_item_types) }
  let(:work_item_parent_links) { table(:work_item_parent_links) }

  let(:organization) { organizations.create!(name: 'Foobar', path: 'path1') }
  let(:namespace) { namespaces.create!(name: 'test', path: 'test', type: 'Group', organization_id: organization.id) }
  let(:project) do
    projects.create!(namespace_id: namespace.id, project_namespace_id: namespace.id, organization_id: organization.id)
  end

  let(:user) { users.create!(email: 'test@example.com', projects_limit: 10, organization_id: organization.id) }
  let(:issue_type) { work_item_types.create!(id: 1, name: 'Issue', base_type: 0) }
  let(:epic_type) { work_item_types.create!(id: 8, name: 'Epic', base_type: 7) }

  let(:start_id) { 1 }
  let(:end_id) { issues.maximum(:id) || 1000 }

  let(:background_migration) do
    described_class.new(
      start_id: start_id,
      end_id: end_id,
      batch_table: :issues,
      batch_column: :id,
      sub_batch_size: 10,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  describe '#perform' do
    context 'when there are leaf node work items' do
      let!(:leaf_issue1) do
        issues.create!(
          title: 'Leaf Issue 1',
          project_id: project.id,
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: issue_type.id
        )
      end

      let!(:leaf_issue2) do
        issues.create!(
          title: 'Leaf Issue 2',
          project_id: project.id,
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: issue_type.id
        )
      end

      let!(:parent_epic) do
        issues.create!(
          title: 'Parent Epic',
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: epic_type.id
        )
      end

      let!(:child_issue) do
        issues.create!(
          title: 'Child Issue',
          project_id: project.id,
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: issue_type.id
        )
      end

      before do
        # Create parent-child relationship
        work_item_parent_links.create!(
          work_item_id: child_issue.id,
          work_item_parent_id: parent_epic.id
        )
      end

      it 'enqueues UpdateWeightsWorker for child nodes only and not standalone nodes' do
        expect(::WorkItems::Weights::UpdateWeightsWorker)
          .to receive(:perform_async)
          .with(match_array([child_issue.id]))

        background_migration.perform
      end
    end

    context 'when there are no work items in the batch' do
      it 'does not enqueue any jobs' do
        expect(::WorkItems::Weights::UpdateWeightsWorker).not_to receive(:perform_async)

        background_migration.perform
      end
    end

    context 'when all work items are child nodes' do
      let!(:parent_epic) do
        issues.create!(
          title: 'Parent Epic',
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: epic_type.id
        )
      end

      let!(:child_issue1) do
        issues.create!(
          title: 'Child Issue 1',
          project_id: project.id,
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: issue_type.id
        )
      end

      let!(:child_issue2) do
        issues.create!(
          title: 'Child Issue 2',
          project_id: project.id,
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: issue_type.id
        )
      end

      before do
        work_item_parent_links.create!(
          work_item_id: child_issue1.id,
          work_item_parent_id: parent_epic.id
        )
        work_item_parent_links.create!(
          work_item_id: child_issue2.id,
          work_item_parent_id: parent_epic.id
        )
      end

      it 'enqueues UpdateWeightsWorker only for the parent epic' do
        expect(::WorkItems::Weights::UpdateWeightsWorker)
          .to receive(:perform_async)
          .with(match_array([child_issue1.id, child_issue2.id]))

        background_migration.perform
      end
    end

    context 'when there are multiple levels of hierarchy' do
      let!(:top_level_epic) do
        issues.create!(
          title: 'Top Level Epic',
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: epic_type.id
        )
      end

      let!(:mid_level_epic) do
        issues.create!(
          title: 'Mid Level Epic',
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: epic_type.id
        )
      end

      let!(:leaf_issue) do
        issues.create!(
          title: 'Leaf Issue',
          project_id: project.id,
          namespace_id: namespace.id,
          author_id: user.id,
          work_item_type_id: issue_type.id
        )
      end

      before do
        work_item_parent_links.create!(
          work_item_id: mid_level_epic.id,
          work_item_parent_id: top_level_epic.id
        )
        work_item_parent_links.create!(
          work_item_id: leaf_issue.id,
          work_item_parent_id: mid_level_epic.id
        )
      end

      it 'enqueues UpdateWeightsWorker only for the lowest node in heirarchy' do
        expect(::WorkItems::Weights::UpdateWeightsWorker)
          .to receive(:perform_async)
          .with([leaf_issue.id])

        background_migration.perform
      end
    end
  end
end
