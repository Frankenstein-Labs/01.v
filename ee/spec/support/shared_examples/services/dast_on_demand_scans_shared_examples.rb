# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'it delegates scan creation to another service' do
  it 'calls AppSec::Dast::Scans::CreateService' do
    expect(AppSec::Dast::Scans::CreateService).to receive(:new).with(hash_including(params: delegated_params)).and_call_original

    subject
  end
end

RSpec.shared_examples 'it bypasses branch protection for on-demand DAST scans' do
  context 'when the branch is protected' do
    before do
      unless project.protected_branches.exists?(name: branch_name)
        create(:protected_branch, project: project, name: branch_name)
      end

      unless project.repository.branch_exists?(branch_name)
        project.repository.add_branch(project.first_owner, branch_name, project.default_branch)
      end
    end

    it 'does not fail with a branch permission error for on-demand DAST source' do
      errors = subject[:errors] || []

      expect(errors).not_to include(
        a_string_including("You do not have sufficient permission to run a pipeline on '#{branch_name}'")
      )
    end
  end
end
