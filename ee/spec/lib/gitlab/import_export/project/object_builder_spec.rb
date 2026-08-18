# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Project::ObjectBuilder, feature_category: :importers do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }
  let_it_be(:project) do
    create(
      :project,
      :builds_disabled,
      :issues_disabled,
      name: 'project',
      path: 'project',
      group: subgroup
    )
  end

  context 'epics' do
    let_it_be(:epic1) { create(:epic, group: group, title: 'Shared title', iid: 1) }
    let_it_be(:epic2) { create(:epic, group: group, title: 'Shared title', iid: 2) }

    it 'finds the correct epic by iid even if titles are identical' do
      found_epic = described_class.build(
        Epic,
        'title' => 'Shared title',
        'iid' => epic2.iid,
        'group' => group
      )

      expect(found_epic).to eq(epic2)
    end

    it 'falls back to title-based matching when iid is missing' do
      found_epic = described_class.build(
        Epic,
        'title' => 'Shared title',
        'group' => group
      )

      # without iid, it should return the first epic found (deterministic based on creation order)
      expect(found_epic).to eq(epic1)
    end

    it 'returns nil if group is missing for a group-level object' do
      found_epic = described_class.build(
        Epic,
        'title' => 'Shared title',
        'iid' => epic1.iid,
        'group' => nil
      )

      expect(found_epic).to be_nil
    end

    it 'finds the existing epic in root ancestor' do
      root_ancestor_epic = create(:epic, title: 'root ancestor epic', group: group)
      found_epic = described_class.build(
        Epic,
        'iid' => root_ancestor_epic.iid,
        'title' => 'root ancestor epic',
        'group' => project.group,
        'author_id' => project.creator.id
      )

      expect(found_epic).to eq(root_ancestor_epic)
    end

    it 'creates a new epic' do
      created_epic = described_class.build(
        Epic,
        'iid' => 1,
        'title' => 'new epic',
        'group' => project.group,
        'author_id' => project.creator.id
      )

      expect(created_epic.persisted?).to be false
    end
  end

  context 'iterations' do
    it 'finds existing iteration based on iterations cadence title' do
      cadence = create(:iterations_cadence, title: 'iterations cadence', group: project.group)
      iteration = create(
        :iteration,
        iid: 2,
        start_date: '2022-01-01',
        due_date: '2022-02-02',
        group: project.group,
        iterations_cadence: cadence
      )

      object = described_class.build(
        Iteration,
        {
          'iid' => 2,
          'start_date' => '2022-01-01',
          'due_date' => '2022-02-02',
          'iterations_cadence' => cadence,
          'group' => project.group
        }
      )

      expect(object).to eq(iteration)
    end

    context 'when existing iteration does not exist' do
      it 'does not create a new iteration' do
        expect(described_class.build(
          Iteration,
          'iid' => 2,
          'start_date' => '2022-01-01',
          'due_date' => '2022-02-02',
          'group' => project.group
        )).to be_nil
      end
    end
  end
end
