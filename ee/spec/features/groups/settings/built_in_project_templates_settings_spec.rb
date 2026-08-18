# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group Built-in project templates settings', feature_category: :source_code_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  before_all do
    group.add_owner(user)
  end

  before do
    stub_licensed_features(built_in_project_templates_enabled: true)

    sign_in(user)
  end

  describe 'Built-in project templates settings' do
    before do
      visit edit_group_path(group)
    end

    it 'renders the built-in project templates section' do
      within_testid('built-in-project-templates-settings') do
        expect(page).to have_content 'Built-in project templates'
      end
    end

    it 'disables built-in project templates' do
      within_testid('built-in-project-templates-settings') do
        uncheck 'Enable built-in project templates'
        click_button 'Save changes'
      end

      expect(page).to have_content 'successfully updated.'
      expect(group.reload.namespace_settings.built_in_project_templates_enabled).to be(false)
    end

    it 're-enables built-in project templates after disabling' do
      group.namespace_settings.update!(built_in_project_templates_enabled: false)
      visit edit_group_path(group)

      within_testid('built-in-project-templates-settings') do
        check 'Enable built-in project templates'
        click_button 'Save changes'
      end

      expect(page).to have_content 'successfully updated.'
      expect(group.reload.namespace_settings.built_in_project_templates_enabled).to be(true)
    end

    context 'when setting is locked by parent group' do
      let(:subgroup) { create(:group, parent: group) }

      before do
        group.namespace_settings.update!(lock_built_in_project_templates_enabled: true)
        visit edit_group_path(subgroup)
      end

      it 'shows the setting as disabled' do
        within_testid('built-in-project-templates-settings') do
          expect(find_field('Enable built-in project templates', disabled: true)).to be_disabled
        end
      end
    end

    context 'when the feature is unlicensed' do
      before do
        stub_licensed_features(built_in_project_templates_enabled: false)
        visit edit_group_path(group)
      end

      it 'does not render the built-in project templates section' do
        expect(page).not_to have_testid('built-in-project-templates-settings')
      end
    end
  end
end
