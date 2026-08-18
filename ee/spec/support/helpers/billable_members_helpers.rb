# frozen_string_literal: true

require 'support/helpers/reactive_caching_helpers'

module BillableMembersHelpers
  include ReactiveCachingHelpers

  def stub_billable_members_reactive_cache(group)
    group_with_fresh_memoization = Group.find(group.id)
    result = group_with_fresh_memoization.calculate_reactive_cache
    stub_reactive_cache(group, result)
  end
end
