# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module ValidatesItemVisibility
        extend ActiveSupport::Concern

        def ready?(**args)
          if args[:visibility]&.to_sym == :restricted &&
              Feature.disabled?(:ai_catalog_internal_visibility, current_user)
            raise Gitlab::Graphql::Errors::ArgumentError,
              s_('AICatalog|`restricted` visibility is not available')
          end

          super
        end
      end
    end
  end
end
