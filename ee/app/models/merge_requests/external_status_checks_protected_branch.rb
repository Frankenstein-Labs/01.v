# frozen_string_literal: true

# Model for join table between ExternalStatusCheck and ProtectedBranch
module MergeRequests
  class ExternalStatusChecksProtectedBranch < ApplicationRecord
    belongs_to :external_status_check
    belongs_to :protected_branch

    validates :external_status_check, :protected_branch, presence: true
  end
end
