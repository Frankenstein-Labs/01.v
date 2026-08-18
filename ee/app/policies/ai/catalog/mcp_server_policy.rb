# frozen_string_literal: true

module Ai
  module Catalog
    class McpServerPolicy < ::BasePolicy
      delegate { @subject.organization }
    end
  end
end
