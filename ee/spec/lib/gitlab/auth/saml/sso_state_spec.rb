# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::Saml::SsoState, feature_category: :system_access do
  let(:saml_provider_id) { 'saml' }

  subject(:sso_state) { described_class.new(provider_id: saml_provider_id) }

  describe '.new' do
    let(:saml_provider_id) { 'Saml thing ' }

    it 'normalizes the provider_id' do
      expect(sso_state.provider_id).to eq 'saml thing'
    end
  end

  describe '#update_active' do
    let(:new_state) { double }
    let(:session_expiry) { Time.current + 2.days }

    it 'updates the current sign in state' do
      Gitlab::Session.with_session({}) do
        sso_state.update_active(time: new_state)

        expect(Gitlab::Session.current[:active_instance_sso_sign_ins])
          .to eq({ saml_provider_id => { 'last_signin_at' => new_state, "session_not_on_or_after" => nil } })
      end
    end

    it 'updates session_not_on_or_after attribute' do
      Gitlab::Session.with_session({}) do
        sso_state.update_active(time: new_state, session_not_on_or_after: session_expiry)
        expect(Gitlab::Session.current[:active_instance_sso_sign_ins]).to eq({ saml_provider_id => {
          "last_signin_at" => new_state, "session_not_on_or_after" => session_expiry
        } })
      end
    end
  end

  describe '#active?' do
    it 'gets the current sign in state' do
      current_state = double

      Gitlab::Session.with_session(
        active_instance_sso_sign_ins: { saml_provider_id => { 'last_signin_at' => current_state } }
      ) do
        expect(sso_state.active?).to eq current_state
      end
    end
  end

  describe '#active_since?' do
    let(:cutoff) { 1.week.ago }

    context "when passed in cutoff is nil" do
      let(:cutoff) { nil }

      it 'is always active in sessionless request' do
        is_expected.to be_active_since(cutoff)
      end

      it 'is inactive if never signed in' do
        Gitlab::Session.with_session({}) do
          is_expected.not_to be_active_since(cutoff)
        end
      end

      it 'is active if any last_sign_at is present' do
        Gitlab::Session.with_session(
          active_instance_sso_sign_ins: { saml_provider_id => { 'last_signin_at' => Time.current + 5.days } }
        ) do
          is_expected.to be_active_since(cutoff)
        end
        Gitlab::Session.with_session(
          active_instance_sso_sign_ins: { saml_provider_id => { 'last_signin_at' => Time.current - 4.days } }
        ) do
          is_expected.to be_active_since(cutoff)
        end
      end

      it 'is inactive when last_signin_at is also nil in an active session' do
        Gitlab::Session.with_session(
          active_instance_sso_sign_ins: { saml_provider_id => { 'last_signin_at' => nil } }
        ) do
          is_expected.not_to be_active_since(cutoff)
        end
      end
    end

    it 'is always active in a sessionless request' do
      is_expected.to be_active_since(cutoff)
    end

    it 'is inactive if never signed in' do
      Gitlab::Session.with_session({}) do
        is_expected.not_to be_active_since(cutoff)
      end
    end

    it 'is active if signed in since the cut off' do
      time_after_cut_off = cutoff + 2.days

      Gitlab::Session.with_session(
        active_instance_sso_sign_ins: { saml_provider_id => { 'last_signin_at' => time_after_cut_off } }
      ) do
        is_expected.to be_active_since(cutoff)
      end
    end

    it 'is inactive if signed in before the cut off' do
      time_before_cut_off = cutoff - 2.days

      Gitlab::Session.with_session(
        active_instance_sso_sign_ins: { saml_provider_id => { 'last_signin_at' => time_before_cut_off } }
      ) do
        is_expected.not_to be_active_since(cutoff)
      end
    end
  end

  it_behaves_like 'SAML SSO State checks for session_not_on_or_after', 'instance'
end
