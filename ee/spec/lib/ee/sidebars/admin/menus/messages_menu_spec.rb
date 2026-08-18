# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::MessagesMenu, feature_category: :navigation do
  let(:current_user) { build(:admin) }
  let(:context) { Sidebars::Context.new(current_user: current_user, container: nil) }
  let(:targeted_messages_enabled) { true }

  before do
    stub_saas_features(targeted_messages: targeted_messages_enabled)
  end

  describe '#configure_menu_items', :enable_admin_mode do
    subject(:menu_items) { described_class.new(context).configure_menu_items }

    it { is_expected.to be(true) }

    context 'when feature flag is off' do
      before do
        stub_feature_flags(targeted_messages_admin_ui: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when user is not an admin' do
      let(:current_user) { build(:user) }

      it { is_expected.to be(false) }
    end

    context 'when there is no current_user' do
      let(:current_user) { nil }

      it { is_expected.to be(false) }
    end

    context 'when targeted_messages disabled' do
      let(:targeted_messages_enabled) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '#renderable_items', :enable_admin_mode do
    subject(:menu_items) { described_class.new(context).renderable_items.map(&:title) }

    it { is_expected.to contain_exactly('Broadcast Messages', 'Targeted Messages') }

    context 'when feature flag is off' do
      before do
        stub_feature_flags(targeted_messages_admin_ui: false)
      end

      it { is_expected.to be_empty }
    end

    context 'when user is not an admin' do
      let(:current_user) { build(:user) }

      it { is_expected.to be_empty }
    end

    context 'when targeted_messages disabled' do
      let(:targeted_messages_enabled) { false }

      it { is_expected.to be_empty }
    end
  end
end
