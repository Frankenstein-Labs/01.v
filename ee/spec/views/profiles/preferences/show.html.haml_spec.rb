# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'profiles/preferences/show' do
  before do
    assign(:user, user)
    allow(controller).to receive(:current_user).and_return(user)
    stub_feature_flags(enable_hamilton_in_user_preferences: false)
  end

  let(:user) { create_default(:user) }

  context 'security dashboard feature is available' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    it 'renders the group view choice preference' do
      render

      expect(rendered).to have_select('Group overview content')
    end
  end

  context 'security dashboard feature is unavailable' do
    it 'does not render the group view choice preference' do
      render

      expect(rendered).not_to have_select('Group overview content')
    end
  end

  context 'Default Duo namespace assignments', feature_category: :duo_agent_platform do
    context 'when user is not allowed to assign default Duo namespace' do
      before do
        allow(view).to receive(:can?).with(user, :assign_default_duo_group).and_return(false)
      end

      it 'does not have a default Duo group input' do
        render

        expect(rendered).not_to have_select _('Default GitLab Duo namespace')
      end
    end

    context 'when user is allowed to assign default Duo namespace' do
      # `freeze: false` is required in this spec: one or more `let_it_be` subjects
      # cannot be frozen by default (deep_freeze traversal failure, a non-AR
      # subject, or an in-memory mutation that survives reload/refind). Do not
      # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
      # (see gitlab-org/gitlab#602925).
      let_it_be(:namespaces, freeze: false) do
        list = create_list(:namespace, 2) # rubocop:disable RSpec/FactoryBot/AvoidCreate -- DB query required
        Namespace.where(id: list)
      end

      let!(:user_preference) do
        user.user_preference.tap { |p| allow(user).to receive(:user_preference).and_return(p) }
      end

      before do
        allow(view).to receive(:can?).with(user, :assign_default_duo_group).and_return(true)
        allow(user_preference).to receive(:duo_default_namespace_candidates).and_return(namespaces)
      end

      context 'with no namespace selected' do
        it 'renders select input with placeholder text' do
          render

          expect(rendered).to have_select _('Default GitLab Duo namespace'),
            options: ['Select a default Duo namespace...'].concat(namespaces.map(&:name))
        end
      end

      context 'with default already selected' do
        before do
          allow(user_preference).to receive(:duo_default_namespace_id).and_return(1)
        end

        it 'renders select input with namespace options' do
          render

          expect(rendered).to have_select _('Default GitLab Duo namespace'),
            options: ['Select a default Duo namespace...'].concat(namespaces.map(&:name))
        end
      end
    end
  end

  context 'Orbit settings', feature_category: :duo_agent_platform do
    context 'when the orbit preferences section is not visible' do
      before do
        allow(::Ai::Orbit::Settings).to receive(:user_preference_section_visible?).with(user).and_return(false)
      end

      it 'does not render the orbit settings section' do
        render

        expect(rendered).not_to have_selector('[data-testid="orbit-settings-section"]')
      end
    end

    context 'when the orbit preferences section is visible' do
      before do
        allow(::Ai::Orbit::Settings).to receive(:user_preference_section_visible?).with(user).and_return(true)
      end

      it 'renders the main orbit toggle and the four subsettings' do
        render

        expect(rendered).to have_selector('[data-testid="orbit-settings-section"]')
        # Subsettings container may be hidden (killswitch defaults to off)
        expect(rendered).to have_selector('[data-testid="orbit-subsettings"]', visible: :all)
        expect(rendered).to have_field('user[orbit_enabled]', type: 'checkbox')
        expect(rendered).to have_field('user[orbit_agent_enabled]', type: 'checkbox', visible: :all)
        expect(rendered).to have_field('user[orbit_agentic_chat_enabled]', type: 'checkbox', visible: :all)
        expect(rendered).to have_field('user[orbit_other_foundational_agents_enabled]', type: 'checkbox', visible: :all)
        expect(rendered).to have_field('user[orbit_custom_agents_enabled]', type: 'checkbox', visible: :all)
      end

      context 'when the killswitch is off' do
        before do
          user.user_preference.update!(orbit_settings: { 'enabled' => false })
        end

        it 'renders the subsettings container hidden' do
          render

          expect(rendered).to have_selector('[data-testid="orbit-subsettings"].gl-hidden', visible: :all)
          expect(rendered).to have_field('user[orbit_agent_enabled]', disabled: false, visible: :all)
          expect(rendered).to have_field('user[orbit_agentic_chat_enabled]', disabled: false, visible: :all)
          expect(rendered)
            .to have_field('user[orbit_other_foundational_agents_enabled]', disabled: false, visible: :all)
          expect(rendered).to have_field('user[orbit_custom_agents_enabled]', disabled: false, visible: :all)
        end
      end

      context 'when the killswitch is on' do
        before do
          user.user_preference.update!(orbit_settings: { 'enabled' => true })
        end

        it 'renders the subsettings container visible and enabled' do
          render

          expect(rendered).not_to have_selector('[data-testid="orbit-subsettings"].gl-hidden', visible: :all)
          expect(rendered).to have_field('user[orbit_agent_enabled]', disabled: false)
          expect(rendered).to have_field('user[orbit_agentic_chat_enabled]', disabled: false)
          expect(rendered).to have_field('user[orbit_other_foundational_agents_enabled]', disabled: false)
          expect(rendered).to have_field('user[orbit_custom_agents_enabled]', disabled: false)
        end
      end
    end
  end

  context 'Code Suggestions self-assignment', :saas, feature_category: :code_suggestions do
    context 'when the feature is available' do
      before do
        stub_feature_flags(enable_hamilton_in_user_preferences: user)
      end

      it 'renders the code suggestions preference' do
        render

        expect(rendered).to render_template('profiles/preferences/_code_suggestions_settings_self_assignment')
        field_text = s_('Preferences|Code Suggestions')
        expect(rendered).to have_content(field_text)
      end
    end

    context 'when the feature is not available' do
      it 'does not render the code suggestions preference' do
        render

        expect(rendered).to render_template('profiles/preferences/_code_suggestions_settings_self_assignment')
        field_text = s_('Preferences|Code Suggestions')
        expect(rendered).not_to have_content(field_text)
      end
    end
  end
end
