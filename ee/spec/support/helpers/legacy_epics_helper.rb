# frozen_string_literal: true

module LegacyEpicsHelper
  def assign_epic_parent(epic, parent_epic, relative_position: nil)
    epic.parent_id = parent_epic.id
    epic.relative_position = relative_position if relative_position

    # Check if there's an existing parent link on the work item that we should use
    work_item_parent_link = epic.work_item.parent_link

    if work_item_parent_link.present? && epic.work_item_parent_link != work_item_parent_link
      # Case 1: Assign existing link from work_item
      epic.work_item_parent_link = work_item_parent_link

    elsif epic.work_item_parent_link.present?
      # Case 2: Update existing link's parent
      epic.work_item_parent_link.work_item_parent_id = parent_epic.work_item.id
      epic.work_item_parent_link.relative_position = relative_position if relative_position
      epic.work_item_parent_link.save!
    else
      # Case 3: Create new link
      link_attributes = {
        work_item: epic.work_item,
        work_item_parent: parent_epic.work_item
      }
      link_attributes[:relative_position] = relative_position if relative_position

      epic.work_item_parent_link = create(:parent_link, **link_attributes)
    end

    epic.save!
  end
end
