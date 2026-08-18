# frozen_string_literal: true

module EE
  module Organizations
    module Transfer
      module UsersService
        extend ::Gitlab::Utils::Override

        private

        override :update_personal_snippet_notes
        def update_personal_snippet_notes(user_ids)
          super

          transfer_snippet_repository_states(user_ids)
        end

        # rubocop:disable CodeReuse/ActiveRecord -- Query specific to this service
        def transfer_snippet_repository_states(user_ids)
          personal_snippets = ::PersonalSnippet.where(author_id: user_ids)

          update_organization_id_for(
            ::Geo::SnippetRepositoryState, organization_key: :snippet_organization_id
          ) do |relation|
            # `snippet_repositories` has no `id` column of its own - its primary key is
            # `snippet_id`, shared 1:1 with `snippets.id`. So `snippet_repository_id` here
            # is directly comparable to `snippets.id`, with no join through SnippetRepository needed.
            relation.where(snippet_repository_id: personal_snippets.select(:id))
          end
        end
        # rubocop:enable CodeReuse/ActiveRecord
      end
    end
  end
end
