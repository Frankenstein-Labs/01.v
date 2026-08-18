# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowWorkItemPolicy < BasePolicy
      # A link is readable exactly when its session is, so reuse the workflow's policy.
      delegate { @subject.workflow }
    end
  end
end
