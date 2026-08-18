# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowNotePolicy < BasePolicy
      delegate { @subject.workflow }
    end
  end
end
