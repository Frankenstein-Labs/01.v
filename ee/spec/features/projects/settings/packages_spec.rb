# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project > Settings > Packages and registries > Dependency proxy for Packages', :js,
  feature_category: :package_registry do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, namespace: user.namespace) }

  before do
    stub_licensed_features(dependency_proxy_for_packages: true)
    stub_config(dependency_proxy: { enabled: true })
    sign_in(user)
  end

  it 'passes axe automated accessibility testing' do
    visit_page

    click_button 'Expand Package registry'

    within_testid('dependency-proxy-settings') do
      expect(page).to have_text 'Dependency Proxy'
    end

    expect(page).to be_axe_clean.within_testid('packages-and-registries-project-settings')
                                .skipping :'link-in-text-block'
  end

  shared_examples 'dependency proxy settings' do
    it 'shows available section' do
      visit_method

      within_testid('dependency-proxy-settings') do
        expect(page).to have_text 'Dependency Proxy'
      end
    end

    it 'allows toggling dependency proxy & adding maven URL' do
      visit_method

      within_testid('dependency-proxy-settings') do
        check('Enable Dependency Proxy')
        fill_in('URL', with: 'http://example.com')
        click_button 'Save changes'
      end

      expect(page).to have_content('Settings saved successfully.')
    end

    it 'allows filling complete form' do
      visit_method

      within_testid('dependency-proxy-settings') do
        check('Enable Dependency Proxy')
        fill_in('URL', with: 'http://example.com')
        fill_in('Username', with: 'username')
        fill_in('Password', with: 'password')
        click_button 'Save changes'
      end

      expect(page).to have_content('Settings saved successfully.')
    end

    it 'shows an error when username is supplied without password' do
      visit_method

      within_testid('dependency-proxy-settings') do
        fill_in('Username', with: 'user1')
        click_button 'Save changes'
      end

      expect(page).to have_content("Maven external registry password can't be blank")
    end

    context 'with existing settings' do
      let_it_be_with_reload(:dependency_proxy_setting) do
        create(:dependency_proxy_packages_setting, :maven, project: project)
      end

      it 'allows clearing username' do
        visit_method

        within_testid('dependency-proxy-settings') do
          fill_in('Username', with: '')
          click_button 'Save changes'
        end

        expect(page).to have_content('Settings saved successfully.')
      end
    end
  end

  it_behaves_like 'dependency proxy settings' do
    let(:visit_method) { visit_and_expand_section }
  end

  private

  def visit_page
    visit project_settings_packages_and_registries_path(project)
  end

  def visit_and_expand_section
    visit_page

    click_button 'Expand Package registry'
  end
end
