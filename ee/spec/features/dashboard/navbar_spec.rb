# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '"Your work" navbar', :js, feature_category: :navigation do
  include NavbarStructureHelper

  include_context 'dashboard navbar structure'

  let_it_be(:user) { create(:user) }

  before do
    stub_config(knowledge_graph: { 'enabled' => true })
  end

  def insert_orbit_nav_item(after_item)
    insert_after_nav_item(
      after_item,
      new_nav_item: {
        nav_item: s_("Orbit|Orbit"),
        nav_sub_items: []
      }
    )
  end

  context 'when devops operations dashboard is available' do
    before do
      stub_licensed_features(operations_dashboard: true)
      stub_application_setting(bulk_import_enabled: true)
      sign_in(user)

      insert_after_nav_item(
        _('Import history'),
        new_nav_item: {
          nav_item: _("Environments"),
          nav_sub_items: []
        }
      )
      insert_after_nav_item(
        _("Environments"),
        new_nav_item: {
          nav_item: _("Operations"),
          nav_sub_items: []
        }
      )
      insert_orbit_nav_item(_("Operations"))

      visit root_path
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when security dashboard is available' do
    before do
      stub_licensed_features(security_dashboard: true)
      stub_application_setting(bulk_import_enabled: true)
      sign_in(user)

      insert_after_nav_item(
        _('Import history'),
        new_nav_item: {
          nav_item: _("Security"),
          nav_sub_items: [
            _('Security dashboard'),
            _('Vulnerability report'),
            _('Settings')
          ]
        }
      )
      insert_orbit_nav_item(_("Security"))

      visit root_path
    end

    it_behaves_like 'verified navigation bar'
  end
end
