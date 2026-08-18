# frozen_string_literal: true

module EE
  module Gitlab
    module ImportExport
      module Project
        module RelationTreeRestorer
          extend ::Gitlab::Utils::Override

          EE_GROUP_MODELS = [Iteration].freeze

          private

          override :relations
          def relations
            relations = super
            relations.delete('ci_pipelines') if importable.gitlab_custom_project_template_import?
            relations
          end

          override :group_models
          def group_models
            super + EE_GROUP_MODELS
          end
        end
      end
    end
  end
end
