# frozen_string_literal: true

module EE
  module Resolvers
    module MergeRequestsResolver # rubocop:disable Gitlab/BoundedContexts -- false positive, this follows the same format as the rest of the directory
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :approver, [GraphQL::Types::String],
          required: false,
          as: :approver_usernames,
          description: 'Usernames of possible approvers.'
      end
    end
  end
end
