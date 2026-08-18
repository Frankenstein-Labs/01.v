# frozen_string_literal: true

module API
  module Entities
    class ApprovalRuleShort < Grape::Entity
      expose :id, documentation: { type: 'Integer', format: 'int64', example: 1 }
      expose :name, documentation: { type: 'String', example: 'QA' }
      expose :rule_type, documentation: { type: 'String', example: 'regular' }
    end
  end
end
