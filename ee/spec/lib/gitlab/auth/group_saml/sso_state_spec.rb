# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::SsoState, feature_category: :system_access do
  let(:saml_provider_id) { 10 }

  subject(:sso_state) { described_class.new(saml_provider_id) }

  describe '.active_saml_sessions' do
    subject(:active_saml_sessions) { described_class.active_saml_sessions }

    context 'when session data is stored' do
      let(:session_data) do
        {
          27 => (Time.current - 1.day),
          99 => (Time.current - 12.hours)
        }
      end

      around do |ex|
        Gitlab::Session.with_session(described_class::SESSION_STORE_KEY => session_data) { ex.run }
      end

      it { is_expected.to match(session_data) }
    end
  end

  describe '#update_active' do
    let(:new_state) { double }

    it 'updates the current sign in state' do
      Gitlab::Session.with_session({}) do
        sso_state.update_active(new_state)

        expect(Gitlab::Session.current[:active_group_sso_sign_ins]).to eq(
          { saml_provider_id => new_state,
            "#{saml_provider_id}_session_not_on_or_after" => nil })
      end
    end

    it "sets 'SessionNotOnOrAfter' correctly" do
      session_not_on_or_after = 1.day.from_now

      Gitlab::Session.with_session({}) do
        sso_state.update_active(new_state, session_not_on_or_after: session_not_on_or_after)
        expect(Gitlab::Session.current[:active_group_sso_sign_ins]).to eq(
          {
            saml_provider_id => new_state,
            "#{saml_provider_id}_session_not_on_or_after" => session_not_on_or_after
          }
        )
      end
    end
  end

  describe '#active?' do
    it 'gets the current sign in state' do
      current_state = double

      Gitlab::Session.with_session(active_group_sso_sign_ins: { saml_provider_id => current_state }) do
        expect(sso_state.active?).to eq current_state
      end
    end
  end

  describe '#active_since?' do
    let(:cutoff) { 1.week.ago }

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

      Gitlab::Session.with_session(active_group_sso_sign_ins: { saml_provider_id => time_after_cut_off }) do
        is_expected.to be_active_since(cutoff)
      end
    end

    it 'is inactive if signed in before the cut off' do
      time_before_cut_off = cutoff - 2.days

      Gitlab::Session.with_session(active_group_sso_sign_ins: { saml_provider_id => time_before_cut_off }) do
        is_expected.not_to be_active_since(cutoff)
      end
    end

    context "when cutoff is nil" do
      let(:cutoff) { nil }

      it 'is nil when last_sign_in is also nil in an active session' do
        Gitlab::Session.with_session(active_group_sso_sign_ins: { saml_provider_id => nil }) do
          is_expected.not_to be_active_since(cutoff)
          expect(sso_state.active_since?(cutoff)).to be_nil
        end
      end
    end
  end

  it_behaves_like 'SAML SSO State checks for session_not_on_or_after', 'group'
end
