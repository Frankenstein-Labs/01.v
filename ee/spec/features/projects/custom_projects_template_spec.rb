# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project', feature_category: :source_code_management do
  describe 'Custom instance-level projects templates' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    # Names are pinned because the template list is sorted by name.
    let_it_be(:projects) do
      (1..3).map do |n|
        create(:project, :public, :metrics_dashboard_enabled, namespace: group, name: "Template #{n}")
      end
    end

    before do
      stub_ee_application_setting(custom_project_templates_group_id: group.id)
    end

    describe 'when feature custom_project_templates is enabled' do
      before do
        stub_licensed_features(custom_project_templates: true)
        allow(Project).to receive(:default_per_page).and_return(2)

        sign_in user
        visit new_project_path
      end

      it 'shows built-in templates tab' do
        page.within '.project-template .built-in-tab' do
          expect(page).to have_content 'Built-in'
        end
      end

      describe 'Instance tab' do
        it 'shows custom projects templates tab' do
          page.within '.project-template .custom-instance-project-templates-tab' do
            expect(page).to have_content 'Instance'
          end
        end

        it 'displays the number of projects templates available to the user' do
          page.within '.project-template .custom-instance-project-templates-tab span.badge' do
            expect(page).to have_content '3'
          end
        end

        context 'when SaaS', :saas do
          it 'does not show Instance tab' do
            page.within '.project-template' do
              expect(page).not_to have_content 'Instance'
            end
          end
        end
      end

      it 'renders a Preview link for instance templates', :js do
        click_link 'Create from template'
        click_link 'Instance'

        expect(page).to have_link('Preview', href: "/#{projects.first.full_path}")
      end

      it 'allows creation from custom project template', :js, :sidekiq_inline do
        new_path = 'example-custom-project-template'
        new_name = 'Example Custom Project Template'

        create_from_template(:instance, projects.first.name)

        page.within '.project-fields-form' do
          fill_in('project_name', with: new_name)
          # Have to reset it to '' so it overwrites rather than appends
          fill_in('project_path', with: '')
          fill_in('project_path', with: new_path)
          select_user_namespace
          click_button 'Create project'
        end

        expect(page).to have_content new_name
        expect(Project.last.name).to eq new_name
        expect(page).to have_current_path "/#{user.username}/#{new_path}"
        expect(Project.last.path).to eq new_path
      end

      it 'allows creation from custom project template using only the name', :js, :sidekiq_inline do
        new_path = 'example-custom-project-template'
        new_name = 'Example Custom Project Template'

        create_from_template(:instance, projects.first.name)

        page.within '.project-fields-form' do
          fill_in('project_name', with: new_name)
          select_user_namespace
          click_button 'Create project'
        end

        expect(page).to have_content new_name
        expect(Project.last.name).to eq new_name
        expect(page).to have_current_path "/#{user.username}/#{new_path}"
        expect(Project.last.path).to eq new_path
      end

      it 'allows creation from custom project template using only the path', :js, :sidekiq_inline do
        new_path = 'example-custom-project-template'
        new_name = 'Example Custom Project Template'

        create_from_template(:instance, projects.first.name)

        page.within '.project-fields-form' do
          fill_in('project_path', with: new_path)
          select_user_namespace
          click_button 'Create project'
        end

        expect(page).to have_content new_name
        expect(Project.last.name).to eq new_name
        expect(page).to have_current_path "/#{user.username}/#{new_path}"
        expect(Project.last.path).to eq new_path
      end

      it 'has a working pagination', :js,
        quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/17078' do
        last_project = "label[for='#{projects.last.name}']"

        click_link 'Create from template'
        find('.project-template .custom-instance-project-templates-tab').click

        expect(page).to have_css('.custom-project-templates .gl-pagination')
        expect(page).not_to have_css(last_project)

        find_by_testid('kaminari-pagination-next').click

        wait_for_requests

        expect(page).to have_css(last_project)
      end
    end

    describe 'when feature custom_project_templates is disabled' do
      it 'does not show custom project templates tab' do
        expect(page).not_to have_css('.project-template .nav-tabs')
      end
    end
  end

  describe 'Custom group-level project templates', :js do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, name: 'long-parent-group') }
    let_it_be(:template_subgroup) { create(:group, parent: group, name: 'template-subgroup') }
    let_it_be(:template) { create(:project, name: 'template-project', namespace: template_subgroup) }

    before_all do
      group.add_owner(user)
      group.update!(custom_project_templates_group_id: template_subgroup.id)
    end

    before do
      stub_licensed_features(custom_project_templates: true, group_project_templates: true)
      sign_in user
    end

    context 'without a namespace in the project path' do
      it 'displays the group selector' do
        visit new_project_path

        click_link 'Create from template'
        find('.custom-group-project-templates-tab').click

        within_testid('group-templates-group-selector') do
          expect(page).to have_content(
            s_('ProjectsNew|Select a group to view its project templates')
          )
          expect(page).to have_content(s_('ProjectsNew|Select a group'))
        end
      end

      it 'lists groups the user can create projects in' do
        visit new_project_path

        click_link 'Create from template'
        find('.custom-group-project-templates-tab').click

        within_testid('group-templates-group-selector') do
          find_by_testid('group-templates-group-select').click
        end
        wait_for_requests

        expect(page).to have_content(group.full_path)
      end
    end

    context 'with namespace_id and tab=group in the URL' do
      it 'activates the group tab and loads templates' do
        visit new_project_path(namespace_id: group.id, tab: 'group')

        click_link 'Create from template'
        wait_for_requests

        expect(page).to have_selector('#custom-group-project-templates.tab-pane.active')
        expect(page).to have_content(template.name)
      end
    end

    context 'with a group namespace in the project path' do
      it 'displays the group namespace for default project URL' do
        visit new_project_path(namespace_id: group.id)
        create_from_template(:group, template.name)

        expect(find_by_testid('select-namespace-dropdown')).to have_text(group.full_path)
      end
    end

    context 'with a subgroup namespace in the project path' do
      let!(:other_subgroup) { create(:group, parent: group, name: 'long-other-subgroup') }

      it 'displays the subgroup namespace for default project URL' do
        visit new_project_path(namespace_id: other_subgroup.id)
        create_from_template(:group, template.name)

        expect(find_by_testid('select-namespace-dropdown')).to have_text(other_subgroup.full_path)
      end
    end
  end

  def create_from_template(type, template_name)
    tab = case type
          when :instance
            '.custom-instance-project-templates-tab'
          when :group
            '.custom-group-project-templates-tab'
          else
            raise ArgumentError, "#{type} is not a valid template type"
          end

    click_link 'Create from template'
    find(tab).click
    wait_for_requests
    find("label[for='#{template_name}']").click
  end

  # Instance templates do not preselect a namespace, and the form's client-side
  # validation blocks submission until one is chosen explicitly. Open the
  # namespace dropdown and pick the user's personal namespace, then confirm the
  # toggle reflects the selection before continuing.
  def select_user_namespace
    within_testid('select-namespace-dropdown') do
      find('button').click
    end

    wait_for_requests

    find_by_testid("listbox-item-#{user.namespace.to_global_id}").click

    within_testid('select-namespace-dropdown') do
      expect(page).to have_button(user.username)
    end
  end
end
