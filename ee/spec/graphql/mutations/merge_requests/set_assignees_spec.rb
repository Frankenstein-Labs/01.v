# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::MergeRequests::SetAssignees, feature_category: :code_review_workflow do
  it_behaves_like 'a multi-assignable resource' do
    let_it_be_with_reload(:resource) { create(:merge_request) }
  end
end
