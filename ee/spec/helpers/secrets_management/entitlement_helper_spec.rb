# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::EntitlementHelper, feature_category: :secrets_management do
  include described_class

  let(:user) { instance_double(User, id: 1) }
  let(:entitlement) { instance_double(SecretsManagement::Entitlement) }

  describe '#secrets_manager_entitlement_root_namespace' do
    context 'when root_namespace is a root group' do
      let(:root_group) { build_stubbed(:group) }

      it 'delegates to SecretsManagement::Entitlement.for' do
        allow(root_group).to receive(:root?).and_return(true)

        expect(SecretsManagement::Entitlement).to receive(:for).with(root_group, user: user).and_return(entitlement)

        expect(secrets_manager_entitlement_root_namespace(root_group, user)).to eq(entitlement)
      end
    end

    context 'when root_namespace is a user namespace' do
      let(:user_namespace) { build_stubbed(:namespace) }

      it 'returns nil' do
        expect(secrets_manager_entitlement_root_namespace(user_namespace, user)).to be_nil
      end
    end

    context 'when root_namespace is nil' do
      it 'returns nil' do
        expect(secrets_manager_entitlement_root_namespace(nil, user)).to be_nil
      end
    end
  end
end
