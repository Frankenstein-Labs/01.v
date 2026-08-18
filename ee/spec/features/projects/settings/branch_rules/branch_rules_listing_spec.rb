# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Settings > Repository > Branch rules > Branch rules listing', :js, feature_category: :source_code_management do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:branch_rule, freeze: true) do
    create(
      :protected_branch,
      code_owner_approval_required: true,
      allow_force_push: false
    )
  end

  let_it_be(:project) { branch_rule.project }

  before_all do
    project.add_maintainer(user)
  end

  before do
    sign_in(user)
  end

  context 'when not licensed' do
    before do
      stub_licensed_features(merge_request_approvers: false, external_status_checks: false,
        multiple_approval_rules: false, protected_refs_for_users: false)
    end

    context 'with predefined rule' do
      it 'does not render predefined rules' do
        visit_branch_rules_listing
        wait_for_requests

        click_button 'Add branch rule'

        expect(page).not_to have_content 'All protected branches'
      end
    end
  end

  context 'when licensed' do
    before do
      stub_licensed_features(merge_request_approvers: true, external_status_checks: true,
        multiple_approval_rules: true, protected_refs_for_users: true)
    end

    context 'with predefined rule' do
      it 'renders predefined rules' do
        visit_branch_rules_listing
        wait_for_requests

        click_button 'Add branch rule'

        expect(page).to have_content 'All protected branches'
      end
    end
  end

  def visit_branch_rules_listing
    visit project_settings_repository_path(project)
  end
end
