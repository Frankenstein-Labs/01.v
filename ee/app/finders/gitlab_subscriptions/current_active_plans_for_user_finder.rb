# frozen_string_literal: true

module GitlabSubscriptions
  class CurrentActivePlansForUserFinder
    include Gitlab::Utils::StrongMemoize

    def initialize(user)
      @user = user
    end

    def execute
      return Plan.none if user.blank?

      Plan.with(members_cte.to_arel) # rubocop:disable CodeReuse/ActiveRecord -- specific to this finder
          .with_subscriptions
          .by_distinct_names(Plan::CURRENT_ACTIVE_PLANS)
          .by_namespace(members_scope.select(:source_id))
          # For pluck use, fits here due to distinct and helps keep all the current logic contained
          .limit(Plan::CURRENT_ACTIVE_PLANS.size)
    end

    private

    attr_reader :user

    def members_scope
      Member.from(members_cte.table) # rubocop:disable CodeReuse/ActiveRecord -- specific to this finder
    end

    def members_cte
      query = GroupMember
                .non_request
                .non_minimal_access
                .with_user(user)
                .select(:source_id)

      Gitlab::SQL::CTE.new(:members, query, materialized: true)
    end
    strong_memoize_attr :members_cte
  end
end
