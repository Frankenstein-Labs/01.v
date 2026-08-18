# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AllBranchesRules::MergeRequestApprovalSetting, feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }

  it 'initializes with a project and makes that project accessible' do
    expect(described_class.new(project).project).to eq(project)
  end
end
