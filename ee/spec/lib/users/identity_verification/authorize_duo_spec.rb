# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::IdentityVerification::AuthorizeDuo, feature_category: :duo_agent_platform do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:ai_feature) { :duo_agent_platform }
  let(:enablement_type) { 'duo_core' }
  let(:identity_verified) { false }
  let(:entitlement_allowed) { true }

  let(:entitlement) do
    ::Ai::UserAuthorizable::Response.new(
      allowed?: entitlement_allowed, namespace_ids: [root_namespace.id],
      enablement_type: enablement_type, authorized_by_duo_core: false
    )
  end

  let(:authorizer) do
    described_class.new(
      user: user, ai_feature: ai_feature, root_namespace: root_namespace, entitlement: entitlement
    )
  end

  before do
    allow(user).to receive(:identity_verified?).and_return(identity_verified)
  end

  describe '#identity_verification_required?' do
    subject(:identity_verification_required) { authorizer.identity_verification_required? }

    context 'when the access is unpaid and the user has not verified their identity' do
      it { is_expected.to be(true) }
    end

    context 'when the user has already verified their identity' do
      let(:identity_verified) { true }

      it { is_expected.to be(false) }
    end

    context 'with each enablement type' do
      using RSpec::Parameterized::TableSyntax

      where(:enablement_type, :expected) do
        'duo_core'       | true
        'tier'           | true
        'duo_pro'        | false
        'duo_enterprise' | false
        'gitlab_credits' | false
      end

      with_them do
        it { is_expected.to be(expected) }
      end
    end

    context 'when the entitlement does not allow access' do
      let(:entitlement_allowed) { false }

      it { is_expected.to be(false) }
    end

    context 'when the feature is not the `duo_agent_platform`' do
      let(:ai_feature) { :duo_chat }

      it { is_expected.to be(false) }
    end

    context 'when `dap_require_identity_verification` feature-flag is disabled' do
      before do
        stub_feature_flags(dap_require_identity_verification: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when an entitlement is given' do
      it 'does not resolve one from the user' do
        expect(user).not_to receive(:duo_entitlement)

        identity_verification_required
      end
    end

    context 'when no entitlement is given' do
      let(:authorizer) do
        described_class.new(user: user, ai_feature: ai_feature, root_namespace: root_namespace)
      end

      it 'resolves one from the user' do
        expect(user).to receive(:duo_entitlement)
          .with(ai_feature, root_namespace: root_namespace).once.and_return(entitlement)

        expect(identity_verification_required).to be(true)
      end
    end
  end
end
