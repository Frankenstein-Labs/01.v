# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Admin, feature_category: :permissions do
  subject(:instance_authorization) { described_class.new(user) }

  let_it_be(:user) { create(:user) }
  let_it_be(:admin_role) { create(:admin_member_role, :read_admin_users, user: user) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe "#permitted" do
    subject(:permitted) { instance_authorization.permitted }

    context 'with admin mode enabled', :enable_admin_mode do
      it 'includes the ability' do
        is_expected.to eq([:read_admin_users])
      end
    end

    context 'with admin mode disabled' do
      it 'returns an empty array' do
        is_expected.to be_empty
      end
    end
  end

  describe "#available_permissions_for_user" do
    subject(:permitted) { instance_authorization.available_permissions_for_user }

    context 'with admin mode enabled', :enable_admin_mode do
      it 'includes the ability' do
        is_expected.to eq([:read_admin_users])
      end
    end

    context 'with admin mode disabled' do
      it 'includes the ability' do
        is_expected.to eq([:read_admin_users])
      end
    end
  end
end
