# frozen_string_literal: true

module EE
  module Gitlab
    module QuickActions
      module MergeRequestActions
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override
        include ::Gitlab::QuickActions::Dsl
        include ::Gitlab::Utils::StrongMemoize

        included do
          desc { _('Change reviewers') }
          explanation { _('Change reviewers.') }
          execution_message { _('Changed reviewers.') }
          params '@user1 @user2'
          types MergeRequest
          condition do
            quick_action_target.allows_multiple_reviewers? &&
              quick_action_target.persisted? &&
              current_user.can?(:"admin_#{quick_action_target.to_ability_name}", project)
          end
          command :reassign_reviewer do |reassign_param|
            @updates[:reviewer_ids] = extract_users(reassign_param).map(&:id)
          end
        end

        override :process_reviewer_users
        def process_reviewer_users(users)
          strong_memoize_with(:process_reviewer_users, users.map(&:id)) do
            next users if users.empty?
            next users if users.none?(&:duo_code_review_bot?)
            next users if quick_action_target.ai_review_merge_request_allowed?(current_user)

            # Set flag to use in execution_message and flash message in controller
            quick_action_target.duo_code_review_attempted = :manual

            users.reject(&:duo_code_review_bot?)
          end
        end

        override :process_reviewer_users_message
        def process_reviewer_users_message
          return unless quick_action_target.duo_code_review_attempted

          ::Gitlab::Duo::CodeReview::Messages.manual_error
        end

        override :auto_merge_strategy_copy
        def auto_merge_strategy_copy(strategy, type)
          case strategy
          when ::EE::AutoMergeService::STRATEGY_MERGE_TRAIN
            case type
            when :desc then _('Add to merge train')
            when :explanation then _('Adds this merge request to merge train.')
            when :feedback then _('Added to merge train.')
            end
          when ::AutoMergeService::STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS
            case type
            when :desc then _('Add to merge train when ready')
            when :explanation then _('Adds this merge request to merge train when ready.')
            when :feedback then _('Set to add to merge train when ready.')
            end
          else
            super
          end
        end
      end
    end
  end
end
