# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranch::UnprotectAccessLevel, feature_category: :source_code_management do
  it_behaves_like 'protected branch access'
  it_behaves_like 'protected ref access allowed_access_levels', excludes: [Gitlab::Access::NO_ACCESS]
  it_behaves_like 'ee protected ref access'
  it_behaves_like 'ee protected branch access'
end
