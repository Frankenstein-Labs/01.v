# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::ParentLink, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'associations' do
    it 'has one epic_issue association' do
      is_expected.to have_one(:epic_issue).class_name('EpicIssue')
        .with_foreign_key('work_item_parent_link_id')
        .inverse_of(:work_item_parent_link)
    end

    it 'has one epic association' do
      is_expected.to have_one(:epic).class_name('Epic')
        .with_foreign_key('work_item_parent_link_id')
        .inverse_of(:work_item_parent_link)
    end
  end

  describe '#validate_legacy_hierarchy' do
    context 'when assigning a parent with type Epic' do
      let_it_be_with_reload(:issue) { create(:work_item, project: project) }
      let_it_be(:legacy_epic) { create(:epic, group: group) }
      let_it_be(:epic) { create(:work_item, :epic, project: project) }

      subject { described_class.new(work_item: issue, work_item_parent: epic) }

      it 'is valid for child with no legacy epic' do
        expect(subject).to be_valid
      end

      it 'is invalid for child with existing legacy epic', :aggregate_failures do
        create(:epic_issue, epic: legacy_epic, issue: issue)

        expect(subject).to be_invalid
        expect(subject.errors.full_messages).to include('Work item already assigned to an epic')
      end
    end
  end

  describe 'validations' do
    subject { build(:parent_link) }

    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    describe 'hierarchy validations' do
      let_it_be(:issue) { create(:work_item, project: project) }
      let_it_be(:task1) { create(:work_item, :task, project: project) }
      let_it_be(:task2) { build(:work_item, :task, project: project) }

      describe '#validate_hierarchy_restrictions' do
        let(:parent_work_item) { create(:work_item, project: project) }

        context 'when parent has a system-defined work item type' do
          it 'allows adding a child item' do
            link = build(:parent_link, work_item_parent: parent_work_item, work_item: task1)

            expect(link).to be_valid
          end
        end

        context 'when parent has a non-converted custom work item type' do
          let_it_be(:custom_type) { create(:work_item_custom_type, namespace: group) }

          it 'allows adding a child item' do
            parent_work_item.clear_memoization(:work_items_types_provider) # Use fresh provider instance
            parent_work_item.work_item_type_id = custom_type.id

            link = build(:parent_link, work_item_parent: parent_work_item, work_item: task1)

            expect(link).to be_valid
          end
        end

        context 'when parent has a converted custom work item type' do
          let_it_be(:converted_type) do
            create(:work_item_custom_type, :converted_from_issue, namespace: group)
          end

          it 'allows adding a child item' do
            parent_work_item.clear_memoization(:work_items_types_provider) # Use fresh provider instance
            parent_work_item.work_item_type = converted_type.converted_from_system_defined_type_identifier

            link = build(:parent_link, work_item_parent: parent_work_item, work_item: task1)

            expect(link).to be_valid
          end
        end
      end

      describe '#validate_depth' do
        it_behaves_like 'validates hierarchy depth', :epic, 7
        it_behaves_like 'validates hierarchy depth', :objective, 9

        context 'with cross-type hierarchies (objective to key_result)' do
          let_it_be(:objective1) { create(:work_item, :objective, project: project) }
          let_it_be(:key_result) { create(:work_item, :key_result, project: project) }
          let_it_be(:objective3) { create(:work_item, :objective, project: project) }

          it 'validates maximum depth of 1 for key_results under objectives' do
            create(:parent_link, work_item_parent: objective1, work_item: key_result)

            key_result2 = create(:work_item, :key_result, project: project)
            link = build(:parent_link, work_item_parent: key_result, work_item: key_result2)

            expect(link).not_to be_valid
          end
        end
      end

      describe '#validate_cyclic_reference' do
        let_it_be(:epic_a) { create(:work_item, :epic, project: project) }
        let_it_be(:epic_b) { create(:work_item, :epic, project: project) }
        let_it_be(:epic_c) { create(:work_item, :epic, project: project) }

        before do
          # Create a chain: epic_a -> epic_b -> epic_c
          create(:parent_link, work_item_parent: epic_a, work_item: epic_b)
          create(:parent_link, work_item_parent: epic_b, work_item: epic_c)
        end

        it 'is not valid if parent and child are same' do
          link = build(:parent_link, work_item_parent: epic_a, work_item: epic_a)

          expect(link).not_to be_valid
          expect(link.errors[:work_item]).to include('is not allowed to point to itself')
        end

        it 'is not valid if child is already in ancestors' do
          # epic_c is a descendant of epic_a, so epic_a cannot be a child of epic_c
          link = build(:parent_link, work_item_parent: epic_c, work_item: epic_a)

          expect(link).not_to be_valid
          expect(link.errors[:work_item]).to include("it's already present in this item's hierarchy")
        end
      end
    end
  end
end
