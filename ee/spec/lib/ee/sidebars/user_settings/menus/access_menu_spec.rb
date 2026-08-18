# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::UserSettings::Menus::AccessMenu, feature_category: :navigation do
  let_it_be(:user) { build(:user) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

  describe 'Menu Items' do
    subject(:items) { described_class.new(context).renderable_items.find { |e| e.item_id == item_id } }

    describe 'Personal access tokens menu', feature_category: :system_access do
      let(:item_id) { :access_tokens }

      context 'when the instance allows personal access tokens' do
        it { is_expected.to be_present }
      end

      context 'when the instance does not allow personal access tokens' do
        before do
          stub_ee_application_setting(personal_access_tokens_disabled?: true)
        end

        it { is_expected.not_to be_present }
      end

      context 'for enterprise users' do
        let(:user) { build(:enterprise_user) }

        context 'when personal access tokens are enabled' do
          it { is_expected.to be_present }
        end

        context 'when personal access tokens are disabled' do
          before do
            allow(user.enterprise_group).to receive(:disable_personal_access_tokens?).and_return(true)
          end

          it { is_expected.not_to be_present }
        end
      end
    end

    describe 'SSH keys menu', feature_category: :system_access do
      let(:item_id) { :ssh_keys }

      context 'when user can use SSH keys' do
        it { is_expected.to be_present }
      end

      context 'for enterprise users' do
        let_it_be_with_reload(:group) { create(:group) }
        let_it_be(:user) { create(:enterprise_user, enterprise_group: group) }

        before do
          stub_licensed_features(disable_ssh_keys: true)
          stub_saas_features(disable_ssh_keys: true)
        end

        context 'when user can not use SSH keys' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          it { is_expected.not_to be_present }
        end
      end
    end
  end
end
