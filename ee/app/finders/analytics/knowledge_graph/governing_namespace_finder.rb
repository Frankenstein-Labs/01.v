# frozen_string_literal: true

module Analytics
  module KnowledgeGraph
    class GoverningNamespaceFinder
      def initialize(user)
        @user = user
      end

      def candidates
        return ::Group.none unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        paid_group_ids = ::GitlabSubscription
          .with_hosted_plan([::Plan::PREMIUM, ::Plan::ULTIMATE])
          .namespace_id_in(user.gitlab_com_root_group_ids)
          .select(:namespace_id)

        ::Group.id_in(paid_group_ids).with_knowledge_graph_enabled_namespace
      end

      def eligible?(namespace_id)
        return false unless namespace_id

        candidates.exists?(id: namespace_id) # rubocop:disable CodeReuse/ActiveRecord -- finder-built relation
      end

      def single_candidate_fallback
        namespaces = candidates.limit(2).to_a
        namespaces.first if namespaces.size == 1
      end

      private

      attr_reader :user
    end
  end
end
