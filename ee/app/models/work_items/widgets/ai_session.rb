# frozen_string_literal: true

module WorkItems
  module Widgets
    class AiSession < Base
      def duo_workflows
        work_item.duo_workflows
      end
    end
  end
end
