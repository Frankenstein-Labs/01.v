# frozen_string_literal: true

module Projects
  class AllProtectedBranchesRulePolicy < ::Projects::BranchRulePolicy
    # These conditions override ones set in EE::Projects::BranchRulePolicy as
    # Projects::AllProtectedBranchesRule objects do not have a ProtectedBranch
    # associated with them so cannot have unprotect restrictions applied.
    condition(:unprotect_restrictions_enabled) { false }
  end
end
