# frozen_string_literal: true

module Ai
  class FlowTriggerPolicy < ::BasePolicy
    delegate { @subject.project }
  end
end
