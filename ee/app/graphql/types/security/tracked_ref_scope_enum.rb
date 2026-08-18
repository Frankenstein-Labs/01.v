# frozen_string_literal: true

module Types
  module Security
    class TrackedRefScopeEnum < BaseEnum
      graphql_name 'SecurityTrackedRefScope'
      description 'Return vulnerabilities scoped to certain types of refs.'

      value 'DEFAULT_BRANCHES', 'Returns vulnerabilities that are on a default branch.', value: :default_branches
      value 'ALL_REFS', 'Returns all tracked refs. This is the same as omitting the filter.', value: :all_refs
    end
  end
end
