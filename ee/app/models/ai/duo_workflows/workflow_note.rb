# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowNote < ::ApplicationRecord
      include WorkflowLinkable

      self.table_name = :duo_workflows_workflow_notes

      links_workflow_to :note, class_name: 'Note', inverse_of: false

      scope :triggered_for_notes, ->(note_ids) {
        link_type_triggered.where(note_id: note_ids).order(id: :desc)
          .preload(workflow: [:user, { ai_catalog_item_version: :item }])
      }

      enum :link_type, {
        # the note (comment) was created by the flow
        created: 1,
        # the note (comment) triggered the flow (the original @mention)
        triggered: 2
      }, prefix: true
    end
  end
end
