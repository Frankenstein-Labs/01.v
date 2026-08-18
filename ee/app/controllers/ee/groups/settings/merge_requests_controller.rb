# frozen_string_literal: true

module EE
  module Groups
    module Settings
      module MergeRequestsController
        extend ::Gitlab::Utils::Override

        override :permitted_group_settings_params
        def permitted_group_settings_params
          super + %i[
            only_allow_merge_if_pipeline_succeeds
            allow_merge_on_skipped_pipeline
            only_allow_merge_if_all_discussions_are_resolved
            allow_merge_without_pipeline
            auto_duo_code_review_enabled
          ]
        end
      end
    end
  end
end
