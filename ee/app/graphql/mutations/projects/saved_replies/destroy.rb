# frozen_string_literal: true

module Mutations
  module Projects
    module SavedReplies
      class Destroy < ::Mutations::SavedReplies::Destroy
        graphql_name 'ProjectSavedReplyDestroy'

        field :saved_reply, ::Types::Projects::SavedReplyType,
          null: true,
          description: 'Saved reply after mutation.'

        argument :id, Types::GlobalIDType[::Projects::SavedReply],
          required: true,
          description: copy_field_description(::Types::Projects::SavedReplyType, :id)
      end
    end
  end
end
