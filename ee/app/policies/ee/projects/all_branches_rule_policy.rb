# frozen_string_literal: true

module EE
  module Projects
    module AllBranchesRulePolicy
      extend ActiveSupport::Concern

      prepended do
        # These conditions override ones set in EE::Projects::BranchRulePolicy as
        # Projects::AllBranchesRule objects do not have a ProtectedBranch
        # associated with them so cannot have unprotect restrictions applied.
        condition(:unprotect_restrictions_enabled) { false }
      end
    end
  end
end
