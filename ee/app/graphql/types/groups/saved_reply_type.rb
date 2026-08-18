# frozen_string_literal: true

module Types
  module Groups
    class SavedReplyType < ::Types::SavedReplyType
      graphql_name 'GroupSavedReply'

      authorize :read_saved_replies

      field :id, Types::GlobalIDType[::Groups::SavedReply],
        null: false,
        description: 'Global ID of the group-level saved reply.'
    end
  end
end
