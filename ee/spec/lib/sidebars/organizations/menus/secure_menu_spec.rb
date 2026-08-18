# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Organizations::Menus::SecureMenu, feature_category: :vulnerability_management do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- read_security_resource checks organization membership, which requires persisted records
  let_it_be(:user) { create(:user) }

  # Each membership context builds its own organization: Organization#owner_user_ids is memoized on
  # the instance, so reusing one `let_it_be` organization would carry an owner list between examples.
  let_it_be(:organization) { create(:organization, owners: [user]) }

  let(:context) { Sidebars::Context.new(current_user: user, container: organization) }

  subject(:menu) { described_class.new(context) }

  before do
    stub_licensed_features(security_dashboard: true, security_orchestration_policies: true)
    stub_application_setting(policy_store_experiment_enabled: true)
  end

  describe '#render?' do
    subject { menu.render? }

    context 'when the user is an owner of the organization' do
      it { is_expected.to be true }

      context 'when neither the security dashboard nor the Policy Store experiment is available' do
        before do
          stub_feature_flags(organization_security_dashboard: false, security_policies_v2: false)
        end

        it { is_expected.to be false }
      end

      context 'when the security_dashboard licensed feature is unavailable' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it { is_expected.to be false }
      end

      context 'when only the Policy Store experiment is available' do
        before do
          stub_feature_flags(organization_security_dashboard: false)
        end

        it { is_expected.to be true }
      end
    end

    context 'when the user is a non-owner member of the organization' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:membership) { create(:organization_user, organization: organization, user: user) }

      it { is_expected.to be false }
    end

    context 'when the user has no association to the organization' do
      let_it_be(:organization) { create(:organization) }

      it { is_expected.to be false }
    end

    context 'when there is no current user' do
      let(:context) { Sidebars::Context.new(current_user: nil, container: organization) }

      it { is_expected.to be false }
    end
  end

  describe '#title' do
    it 'is the Secure navigation area title' do
      expect(menu.title).to eq(s_('Navigation|Secure'))
    end
  end

  describe '#sprite_icon' do
    it 'has an icon' do
      expect(menu.sprite_icon).to be_present
    end
  end

  describe '#pick_into_super_sidebar?' do
    it { expect(menu.pick_into_super_sidebar?).to be true }
  end

  describe 'the Security dashboard menu item' do
    before do
      stub_feature_flags(security_policies_v2: false)
    end

    it 'is the only item and links to the organization security dashboard', :aggregate_failures do
      expect(menu.renderable_items.size).to eq(1)

      item = menu.renderable_items.first

      expect(item.title).to eq('Security dashboard')
      expect(item.link).to eq("/o/#{organization.path}/-/security/dashboard")
    end
  end

  describe 'the Policy store menu item' do
    it 'links to the organization policy store', :aggregate_failures do
      item = menu.renderable_items.find { |menu_item| menu_item.item_id == :policy_store }

      expect(item).to be_present
      expect(item.title).to eq('Policy store')
      expect(item.link).to eq("/o/#{organization.path}/-/security/policy_store")
    end
  end
  # rubocop:enable RSpec/FactoryBot/AvoidCreate
end
