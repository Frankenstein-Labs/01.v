# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates issue", :js, :saas, feature_category: :team_planning do
  include ListboxHelpers
  include Features::IterationHelpers

  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }

  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:project) { create(:project_empty_repo, :public, namespace: group) }
  let_it_be(:epic) { create(:epic, group: group, title: 'Sample epic', author: user) }
  let_it_be(:iteration) { create(:iteration, group: group, title: 'Sample iteration') }

  let(:issue_title) { '500 error on profile' }

  before do
    allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive_messages(credits_available?: true, usage_billing_forbidden?: false)
    end
    stub_licensed_features(issue_weights: true, epics: true)
  end

  context "when user can use AI to generate description" do
    include_context 'with ai features enabled for group'

    before do
      sign_in(user)
      visit(new_project_issue_path(project))
    end

    it 'has the GitLab Duo button' do
      expect(page).to have_button('GitLab Duo')
    end
  end

  context 'when user cannot use AI to generate description' do
    include_context 'with experiment features disabled for group'

    before do
      sign_in(user)
    end

    context 'when duo features enabled for project' do
      before do
        visit(new_project_issue_path(project))
      end

      it 'has the GitLab Duo button' do
        expect(page).to have_button('GitLab Duo')
      end
    end

    context 'when duo features disabled for project' do
      before do
        project.update!(duo_features_enabled: false)
        visit(new_project_issue_path(project))
      end

      it 'shows disabled GitLab Duo toggle' do
        expect(page).to have_testid('duo-disabled-toggle')
      end
    end
  end

  context "with weight and iteration" do
    before do
      sign_in(user)
      visit(new_project_issue_path(project))
    end

    it "creates issue" do
      fill_in("Title", with: issue_title)

      within_testid('work-item-weight') do
        click_button 'Edit'
        find_field('weight-widget-input').native.send_keys '7'
      end
      within_testid('work-item-iteration') do
        click_button 'Edit'
        select_listbox_item(iteration.title)
      end

      click_button 'Create Issue'

      expect(page).to have_css('h1', text: issue_title)
      within_testid('work-item-weight') do
        expect(page).to have_text('7')
      end
      within_testid('work-item-iteration') do
        expect(page).to have_text(iteration.title)
      end
    end
  end

  context "with parent" do
    before do
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(150)
      sign_in(user)
      visit(new_project_issue_path(project))
    end

    it "creates issue" do
      fill_in("Title", with: issue_title)

      within_testid('work-item-parent') do
        click_button 'Edit'
        select_listbox_item(epic.title)
      end

      click_button 'Create Issue'

      expect(page).to have_css('h1', text: issue_title)
      within_testid('work-item-parent') do
        expect(page).to have_text(epic.title)
      end
    end
  end

  context 'when new issue url has parameter' do
    before do
      sign_in(user)
      visit(new_project_issue_path(project))
    end

    context 'for inherited issue template' do
      let_it_be(:template_project) { create(:project, :public, :repository) }

      before do
        template_project.repository.create_file(
          user,
          '.gitlab/issue_templates/bug.md',
          'this is a test "bug" template',
          message: 'added issue template',
          branch_name: 'master')

        group.add_owner(user)
        stub_licensed_features(custom_file_templates_for_namespace: true)
        create(:project_group_link, project: template_project, group: group)
        group.update!(file_template_project_id: template_project.id)

        visit new_project_issue_path(project, issuable_template: 'bug')
      end

      it 'fills in with inherited template' do
        expect(page).to have_button('bug')
      end
    end
  end

  context 'when signed in as a maintainer' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      sign_in(user)
      visit(new_project_issue_path(project))
    end

    it_behaves_like 'embedded views (GLQL) EE'
  end
end
