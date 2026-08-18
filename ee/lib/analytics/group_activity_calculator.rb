# frozen_string_literal: true

module Analytics
  class GroupActivityCalculator
    RECENT_DURATION = 30.days
    RECENT_COUNT_LIMIT = 1000
    CACHE_OPTIONS = { raw: false, expires_in: 24.hours }.freeze

    def initialize(group, current_user)
      @group = group
      @current_user = current_user
    end

    def issues_count
      @issues_count ||= fetch_cached(:issues, Issue) do
        IssuesFinder.new(@current_user, issuable_params).execute.limit(RECENT_COUNT_LIMIT).without_order.count
      end
    end

    def merge_requests_count
      @merge_requests_count ||= fetch_cached(:merge_requests, MergeRequest) do
        MergeRequestsFinder.new(@current_user, issuable_params).execute.limit(RECENT_COUNT_LIMIT).without_order.count
      end
    end

    def new_members_count
      @new_members_count ||= fetch_cached(:new_members, Member) do
        GroupMembersFinder.new(
          @group,
          @current_user,
          params: { created_after: RECENT_DURATION.ago }
        ).execute(include_relations: [:direct, :descendants]).limit(RECENT_COUNT_LIMIT).without_order.count
      end
    end

    private

    def issuable_params
      { group_id: @group.id,
        state: 'all',
        created_after: RECENT_DURATION.ago,
        include_subgroups: true,
        attempt_group_search_optimizations: true,
        attempt_project_search_optimizations: true }
    end

    def fetch_cached(type, klass, &block)
      Rails.cache.fetch(cache_key(type), CACHE_OPTIONS) do
        ::Gitlab::Database::LoadBalancing::SessionMap
          .current(klass.load_balancer)
          .use_replicas_for_read_queries(&block)
      end.to_i
    end

    def cache_key(type)
      ['groups', "recent_30d_#{type}_count", @group.id, @current_user.id]
    end
  end
end
