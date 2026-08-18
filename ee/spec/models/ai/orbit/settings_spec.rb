# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Orbit::Settings, feature_category: :duo_agent_platform do
  let_it_be_with_reload(:user) { create(:user) }

  # All feature flags default to enabled in the GitLab test suite, so
  # platform-availability flags (`knowledge_graph`, `orbit_foundational_agent`)
  # and the per-user preference flag (`orbit_user_preference`) are on
  # unless an individual context stubs them off. The Knowledge Graph service
  # config does NOT default on, so it is stubbed here: `platform_available?`
  # now sources the `:knowledge_graph` gate from
  # `Analytics::KnowledgeGraph.enabled_for?`, which also requires the service
  # to be configured on the instance.

  before do
    stub_config(knowledge_graph: { 'enabled' => true })
    # Default user to a non-team-member so the killswitch rules apply
    # without the team-member default-on shortcut. The team-member
    # branch is exercised in its own context below.
    allow(user).to receive(:gitlab_team_member?).and_return(false)
  end

  shared_examples 'a subsetting predicate' do |predicate, subsetting_key|
    describe ".#{predicate}" do
      subject(:result) { described_class.public_send(predicate, user) }

      it 'returns false without a user' do
        expect(described_class.public_send(predicate, nil)).to be(false)
      end

      context 'when knowledge_graph is disabled' do
        before do
          stub_feature_flags(knowledge_graph: false)
        end

        it { is_expected.to be(false) }
      end

      context 'when the Knowledge Graph service is not configured on the instance' do
        before do
          stub_config(knowledge_graph: { 'enabled' => false })
        end

        it { is_expected.to be(false) }
      end

      context 'when orbit_foundational_agent is disabled' do
        before do
          stub_feature_flags(orbit_foundational_agent: false)
        end

        it { is_expected.to be(false) }
      end

      context 'when orbit_user_preference flag is disabled (legacy default)' do
        before do
          stub_feature_flags(orbit_user_preference: false)
        end

        it 'returns true regardless of the saved user preference' do
          user.user_preference.update!(orbit_settings: { 'enabled' => false })

          expect(result).to be(true)
        end

        it 'returns false without a user' do
          expect(described_class.public_send(predicate, nil)).to be(false)
        end
      end

      context 'when orbit_user_preference flag is enabled (default)' do
        it 'returns false when the killswitch is off' do
          user.user_preference.update!(orbit_settings: { 'enabled' => false, subsetting_key => true })

          expect(result).to be(false)
        end

        it 'returns false when only this subsetting is off' do
          settings = { 'enabled' => true }
          described_class::SUBSETTINGS.each_value { |k| settings[k] = true }
          settings[subsetting_key] = false

          user.user_preference.update!(orbit_settings: settings)

          expect(result).to be(false)
        end

        it 'returns true when the killswitch and this subsetting are on' do
          user.user_preference.update!(orbit_settings: { 'enabled' => true, subsetting_key => true })

          expect(result).to be(true)
        end

        it 'returns true when the killswitch is on and the subsetting key is absent (defaults to true)' do
          user.user_preference.update!(orbit_settings: { 'enabled' => true })

          expect(result).to be(true)
        end
      end
    end
  end

  it_behaves_like 'a subsetting predicate', :agent_enabled?, 'orbit_agent_enabled'
  it_behaves_like 'a subsetting predicate', :chat_enabled?, 'orbit_agentic_chat_enabled'
  it_behaves_like 'a subsetting predicate', :foundational_enabled?, 'orbit_other_foundational_agents_enabled'
  it_behaves_like 'a subsetting predicate', :custom_agents_enabled?, 'orbit_custom_agents_enabled'

  describe 'GitLab team member default-on for the standalone agent' do
    before do
      allow(user).to receive(:gitlab_team_member?).and_return(true)
    end

    context 'when the user has not saved their /preferences form' do
      it 'returns true for agent_enabled?' do
        expect(user.user_preference.orbit_settings).not_to have_key('enabled')

        expect(described_class.agent_enabled?(user)).to be(true)
      end

      it 'still gates on the platform-availability flags' do
        stub_feature_flags(orbit_foundational_agent: false)

        expect(described_class.agent_enabled?(user)).to be(false)
      end

      it 'does not affect chat, foundational, or custom_agents subsettings' do
        expect(described_class.chat_enabled?(user)).to be(false)
        expect(described_class.foundational_enabled?(user)).to be(false)
        expect(described_class.custom_agents_enabled?(user)).to be(false)
      end
    end

    context 'when the user has saved the form with the killswitch on' do
      before do
        user.user_preference.update!(orbit_settings: { 'enabled' => true, 'orbit_agent_enabled' => true })
      end

      it 'follows the normal subsetting path' do
        expect(described_class.agent_enabled?(user)).to be(true)
      end
    end

    context 'when the user has explicitly opted out via the killswitch' do
      before do
        user.user_preference.update!(orbit_settings: { 'enabled' => false })
      end

      it 'respects the saved value and returns false' do
        expect(described_class.agent_enabled?(user)).to be(false)
      end
    end

    context 'when the user has the killswitch on but explicitly disabled the agent subsetting' do
      before do
        user.user_preference.update!(orbit_settings: { 'enabled' => true, 'orbit_agent_enabled' => false })
      end

      it 'respects the explicit subsetting opt-out' do
        expect(described_class.agent_enabled?(user)).to be(false)
      end
    end

    context 'when the per-user preference flag is disabled (legacy default)' do
      before do
        stub_feature_flags(orbit_user_preference: false)
      end

      it 'returns true via the legacy path without consulting team-member status' do
        expect(described_class.agent_enabled?(user)).to be(true)
      end
    end
  end

  describe '.user_preference_flag_enabled?' do
    it 'mirrors the orbit_user_preference feature flag' do
      expect(described_class.user_preference_flag_enabled?(user)).to be(true)

      stub_feature_flags(orbit_user_preference: false)

      expect(described_class.user_preference_flag_enabled?(user)).to be(false)
    end
  end

  describe '.user_preference_section_visible?' do
    subject(:visible) { described_class.user_preference_section_visible?(user) }

    it 'returns false without a user' do
      expect(described_class.user_preference_section_visible?(nil)).to be(false)
    end

    context 'when the platform-availability flags are off' do
      it 'returns false when knowledge_graph is disabled' do
        stub_feature_flags(knowledge_graph: false)

        expect(visible).to be(false)
      end

      it 'returns false when orbit_foundational_agent is disabled' do
        stub_feature_flags(orbit_foundational_agent: false)

        expect(visible).to be(false)
      end
    end

    # The config gate must be the ONLY thing hiding the section here: on
    # self-managed with the :orbit license present, available_for? would
    # otherwise return true, so a failing config check is what keeps it hidden.
    context 'when licensed on self-managed but the service is not configured' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        stub_licensed_features(orbit: true)
        stub_config(knowledge_graph: { 'enabled' => false })
      end

      it { is_expected.to be(false) }
    end

    context 'on GitLab.com' do
      let(:finder) { instance_double(::Analytics::KnowledgeGraph::GoverningNamespaceFinder) }
      let(:candidates) { instance_double(ActiveRecord::Relation) }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(::Analytics::KnowledgeGraph::GoverningNamespaceFinder).to receive(:new).with(user).and_return(finder)
        allow(finder).to receive(:candidates).and_return(candidates)
      end

      it 'returns true when the user is in a participating namespace' do
        allow(candidates).to receive(:exists?).and_return(true)

        expect(visible).to be(true)
      end

      it 'returns false when the user is not in a participating namespace' do
        allow(candidates).to receive(:exists?).and_return(false)

        expect(visible).to be(false)
      end

      it 'does not fall back to the instance license' do
        allow(candidates).to receive(:exists?).and_return(false)

        expect(::Analytics::KnowledgeGraph::OrbitLicense).not_to receive(:available_for?)

        visible
      end
    end

    context 'on a self-managed instance' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns true when the :orbit license is available' do
        stub_licensed_features(orbit: true)

        expect(visible).to be(true)
      end

      it 'returns false when the :orbit license is not available' do
        stub_licensed_features(orbit: false)

        expect(visible).to be(false)
      end
    end
  end

  describe '.killswitch_on?' do
    it 'returns false without a user' do
      expect(described_class.killswitch_on?(nil)).to be(false)
    end

    it 'reflects the saved orbit_enabled value, ignoring platform flags' do
      user.user_preference.update!(orbit_settings: { 'enabled' => true })

      # Platform flags off: gate predicates would return false, but
      # killswitch_on? is purely a UI-state read of the saved value.
      stub_feature_flags(knowledge_graph: false, orbit_foundational_agent: false)

      expect(described_class.killswitch_on?(user)).to be(true)

      user.user_preference.update!(orbit_settings: { 'enabled' => false })

      expect(described_class.killswitch_on?(user)).to be(false)
    end
  end

  describe 'SUBSETTINGS constant' do
    it 'maps every flow to a UserPreference accessor that exists' do
      preference = user.user_preference

      described_class::SUBSETTINGS.each_value do |accessor|
        expect(preference).to respond_to(accessor)
        expect(preference).to respond_to("#{accessor}=")
      end
    end

    it 'is the single source of truth for UserPreference::ORBIT_SUBSETTINGS' do
      expect(::UserPreference::ORBIT_SUBSETTINGS).to match_array(described_class::SUBSETTINGS.values)
    end
  end
end
