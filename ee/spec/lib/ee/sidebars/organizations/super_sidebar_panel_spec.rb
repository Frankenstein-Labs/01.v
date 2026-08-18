# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Organizations::SuperSidebarPanel, feature_category: :navigation do
  let_it_be(:organization) { build_stubbed(:organization) }
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:context) do
    Sidebars::Context.new(
      current_user: user,
      container: organization
    )
  end

  subject(:panel) { described_class.new(context) }

  describe '#renderable_menus' do
    it 'includes ContinuousDeploymentMenu' do
      menu_classes = panel.instance_variable_get(:@menus).map(&:class)
      expect(menu_classes).to include(Sidebars::Organizations::Menus::ContinuousDeploymentMenu)
    end

    it 'includes SecureMenu' do
      menu_classes = panel.instance_variable_get(:@menus).map(&:class)
      expect(menu_classes).to include(Sidebars::Organizations::Menus::SecureMenu)
    end

    it 'orders SecureMenu directly after ManageMenu and ahead of ContinuousDeploymentMenu' do
      menu_classes = panel.instance_variable_get(:@menus).map(&:class)

      expect(menu_classes.index(Sidebars::Organizations::Menus::SecureMenu))
        .to be_between(
          menu_classes.index(Sidebars::Organizations::Menus::ManageMenu),
          menu_classes.index(Sidebars::Organizations::Menus::ContinuousDeploymentMenu)
        ).exclusive
    end

    context 'when ai_native_deploy feature flag is disabled' do
      before do
        stub_feature_flags(ai_native_deploy: false)
      end

      it 'does not render ContinuousDeploymentMenu items' do
        menu = panel.instance_variable_get(:@menus).find do |m|
          m.is_a?(Sidebars::Organizations::Menus::ContinuousDeploymentMenu)
        end

        expect(menu&.renderable_items).to be_empty
      end
    end
  end
end
