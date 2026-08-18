# frozen_string_literal: true

module Resolvers
  module Ai
    class GitlabCreditsUnavailableReasonResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      authorize :read_namespace

      type ::Types::Ai::CreditsDenialReasonEnum, null: true

      description 'Reason GitLab credits are unavailable. Returns "usage_billing_forbidden" when usage ' \
        'billing is not available for the account. Returns null when credits are available ' \
        'or the unavailability reason is not recognized.'

      argument :namespace_id,
        ::Types::GlobalIDType[::Namespace],
        required: false,
        description: 'Global ID of the namespace to check credits for.'

      def resolve(namespace_id: nil)
        return unless current_user

        namespace = authorized_find!(id: namespace_id) if namespace_id

        duo_chat = ::Gitlab::Llm::DuoChat.new(user: current_user, group: namespace)
        'usage_billing_forbidden' if duo_chat.usage_billing_forbidden?
      end
    end
  end
end
