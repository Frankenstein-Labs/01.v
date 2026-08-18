# frozen_string_literal: true

module EE
  module Gitlab
    module HookData
      module MergeRequestBuilder
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        EE_SAFE_HOOK_ATTRIBUTES = %i[
          approval_rules
        ].freeze

        override :build
        def build
          attrs = super

          if merge_request.supports_approval_rules?
            attrs[:approval_rules] = merge_request.approval_rules.map(&:hook_attrs)
          end

          attrs
        end

        class_methods do
          extend ::Gitlab::Utils::Override

          override :safe_hook_attributes
          def safe_hook_attributes
            super + EE_SAFE_HOOK_ATTRIBUTES
          end
        end
      end
    end
  end
end
