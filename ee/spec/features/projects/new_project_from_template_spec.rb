# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'New project from template', :js, feature_category: :source_code_management do
  let(:user) { create(:user) }

  before do
    stub_licensed_features(custom_project_templates: true)
    sign_in(user)

    visit new_project_path
  end

  context 'create from template' do
    before do
      page.find('a[href="#create_from_template"]').click
    end

    it 'shows template tabs' do
      page.within('#create-from-template-pane') do
        expect(page).to have_link('Built-in', href: '#built-in')
        expect(page).to have_link('Instance', href: '#custom-instance-project-templates')
        expect(page).to have_link('Group', href: '#custom-group-project-templates')
      end
    end

    context 'when SaaS', :saas do
      it 'shows only Built-in and Group tabs' do
        page.within('#create-from-template-pane') do
          expect(page).to have_link('Built-in', href: '#built-in')
          expect(page).to have_link('Group', href: '#custom-group-project-templates')

          expect(page).not_to have_link('Instance', href: '#custom-instance-project-templates')
        end
      end
    end
  end
end
