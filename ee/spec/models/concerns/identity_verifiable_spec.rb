# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IdentityVerifiable, :saas, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user) }

  def add_user_risk_band(value)
    create(:user_custom_attribute, key: UserCustomAttribute::ARKOSE_RISK_BAND, value: value, user_id: user.id)
  end

  def stub_phone_verification_limits(soft: false, hard: false)
    allow(::Gitlab::ApplicationRateLimiter).to receive(:peek)
      .with(:soft_phone_verification_transactions_limit, scope: :global)
      .and_return(soft)

    allow(::Gitlab::ApplicationRateLimiter).to receive(:peek)
      .with(:hard_phone_verification_transactions_limit, scope: :global)
      .and_return(hard)
  end

  describe('#signup_identity_verification_enabled?') do
    where(
      identity_verification: [true, false],
      require_admin_approval_after_user_signup: [true, false],
      email_confirmation_setting: %w[soft hard off]
    )

    with_them do
      before do
        stub_saas_features(identity_verification: identity_verification)
        stub_application_setting(require_admin_approval_after_user_signup: require_admin_approval_after_user_signup)
        stub_application_setting_enum('email_confirmation_setting', email_confirmation_setting)
      end

      it 'returns the expected result' do
        result = identity_verification &&
          !require_admin_approval_after_user_signup &&
          email_confirmation_setting == 'hard'

        expect(user.signup_identity_verification_enabled?).to eq(result)
      end
    end
  end

  describe('#identity_verification_enabled?') do
    let_it_be(:user, freeze: false) { build_stubbed(:user) }

    subject { user.identity_verification_enabled? }

    context 'when running in SaaS' do
      it { is_expected.to be(true) }
    end

    context 'when running in self-managed' do
      before do
        stub_saas_features(identity_verification: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when verification methods are unavailable' do
      before do
        stub_application_setting(phone_verification_enabled: false)
        stub_application_setting(credit_card_verification_enabled: false)
      end

      context 'when the user is not active' do
        it 'is enabled for email verification', :aggregate_failures do
          expect(subject).to be(true)
          expect(user.required_identity_verification_methods).to eq(['email'])
        end
      end

      context 'when the user is active' do
        let_it_be(:user, freeze: false) { build_stubbed(:user, :with_sign_ins) }

        it { is_expected.to be(false) }
      end
    end
  end

  describe('#identity_verified?') do
    let_it_be(:user, freeze: false) { create(:user, :identity_verification_eligible) }

    subject(:identity_verified?) { user.identity_verified? }

    where(:phone_verified, :credit_card_verified, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(user).to receive(:identity_verification_enabled?).and_return(true)
        allow(user).to receive(:identity_verification_state).and_return(
          {
            phone: phone_verified,
            credit_card: credit_card_verified
          }
        )
      end

      it { is_expected.to eq(result) }
    end

    context 'when identity verification is not enabled' do
      before do
        allow(user).to receive(:identity_verification_enabled?).and_return(false)
      end

      it { is_expected.to be(true) }
    end

    context 'when the user is exempt from identity verification' do
      before do
        allow(user).to receive(:identity_verification_exempt?).and_return(true)
      end

      it { is_expected.to be true }
    end

    context 'when the user has a pre-existing credit card validation' do
      before do
        allow(user).to receive(:identity_verification_enabled?).and_return(true)
        allow(user).to receive(:credit_card_verified?).and_return(credit_card_verified)
        allow(user).to receive(:identity_verification_state) do
          state = { described_class::VERIFICATION_METHODS[:PHONE_NUMBER] => phone_verified }
          state[described_class::VERIFICATION_METHODS[:CREDIT_CARD]] = credit_card_verified if credit_card_required

          state
        end
      end

      where(:credit_card_required, :credit_card_verified, :phone_verified, :result) do
        true  | true  | true  | true
        true  | true  | false | false
        true  | false | true  | false
        true  | false | false | false
        false | true  | true  | true
        false | true  | false | true
        false | false | true  | true
        false | false | false | false
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end

    context 'when the user is a bot' do
      let_it_be(:human_user) { build_stubbed(:user, :with_sign_ins, :identity_verification_eligible) }
      let_it_be(:user, freeze: false) { create(:user, :project_bot, created_by: human_user) }

      it 'verifies the identity of the bot creator', :aggregate_failures do
        expect(human_user).to receive(:identity_verified?).and_call_original

        expect(identity_verified?).to be(false)
      end

      context 'when identity verification is not enabled' do
        before do
          allow(user).to receive(:identity_verification_enabled?).and_return(false)
        end

        it 'returns true without performing the bot check' do
          expect(user).not_to receive(:project_bot?)

          expect(identity_verified?).to be(true)
        end
      end

      context 'when the user is not a project bot' do
        let(:user) { build_stubbed(:user, :admin_bot) }

        it { is_expected.to be(true) }
      end

      context 'when the bot is in a paid namespace' do
        before do
          create(:group_with_plan, plan: :ultimate_plan, developers: user)
        end

        it { is_expected.to be(true) }
      end

      context 'when the bot is in a trial namespace' do
        before do
          create(:group_with_plan, plan: :ultimate_trial_plan, developers: user)
        end

        it { is_expected.to be(false) }
      end

      context 'when the bot creator is nil' do
        let_it_be(:user, freeze: false) { build_stubbed(:user, :project_bot) }

        context 'when the bot was created after the feature release date' do
          it 'fails the identity verification check' do
            user.created_at = described_class::IDENTITY_VERIFICATION_RELEASE_DATE + 1.day

            expect(identity_verified?).to be(false)
          end
        end

        context 'when the bot was created before the feature release date' do
          it 'passes the identity verification check' do
            user.created_at = described_class::IDENTITY_VERIFICATION_RELEASE_DATE - 1.day

            expect(identity_verified?).to be(true)
          end
        end
      end

      context 'when the bot creator has been banned' do
        it 'fails the identity verification check', :aggregate_failures do
          expect(human_user).to receive(:banned?).and_return(true)
          expect(human_user).not_to receive(:identity_verified?)

          expect(identity_verified?).to be(false)
        end
      end
    end

    context 'when the user was created before the release date' do
      let_it_be(:user, freeze: false) do
        create(:user, :with_sign_ins, created_at: described_class::IDENTITY_VERIFICATION_RELEASE_DATE - 1.day)
      end

      before do
        allow(user).to receive(:identity_verification_enabled?).and_return(true)
        allow(user).to receive(:identity_verification_state).and_return({ phone: false })
      end

      it { is_expected.to be true }
    end
  end

  describe('#active_for_authentication?') do
    subject { user.active_for_authentication? }

    where(:identity_verification_enabled?, :identity_verified?, :email_confirmation_setting, :result) do
      true  | true  | 'hard' | true
      true  | false | 'hard' | false
      false | false | 'hard' | true
      false | true  | 'hard' | true
      true  | true  | 'soft' | true
      true  | false | 'soft' | false
      false | false | 'soft' | true
      false | true  | 'soft' | true
    end

    before do
      allow(user).to receive(:signup_identity_verification_enabled?).and_return(identity_verification_enabled?)
      allow(user).to receive(:signup_identity_verified?).and_return(identity_verified?)
      stub_application_setting_enum('email_confirmation_setting', email_confirmation_setting)
    end

    with_them do
      context 'when not confirmed' do
        before do
          allow(user).to receive(:confirmed?).and_return(false)
        end

        it { is_expected.to be(false) }
      end

      context 'when confirmed' do
        before do
          allow(user).to receive(:confirmed?).and_return(true)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe('#signup_identity_verified?') do
    subject { user.signup_identity_verified? }

    where(:phone_verified, :email_verified, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(user).to receive(:signup_identity_verification_enabled?).and_return(true)
        allow(user).to receive(:identity_verification_state).and_return(
          {
            phone: phone_verified,
            email: email_verified
          }
        )
      end

      it { is_expected.to eq(result) }
    end

    context 'when identity verification is not enabled' do
      before do
        allow(user).to receive(:signup_identity_verification_enabled?).and_return(false)
      end

      context 'and their email is already verified' do
        it { is_expected.to be(true) }
      end

      context 'and their email is not yet verified' do
        let(:user) { create(:user, :unconfirmed) }

        it { is_expected.to be(false) }
      end
    end

    context 'when user has already signed in before' do
      context 'and their email is already verified' do
        let(:user) { create(:user, last_sign_in_at: Time.zone.now) }

        it { is_expected.to be(true) }
      end

      context 'and their email is not yet verified' do
        let(:user) { create(:user, :unconfirmed, last_sign_in_at: Time.zone.now) }

        it { is_expected.to be(false) }
      end
    end
  end

  describe('#required_identity_verification_methods') do
    subject { user.required_identity_verification_methods }

    let(:user) { create(:user) }

    where(:risk_band, :credit_card, :phone_number, :phone_exempt, :identity_verification_exempt, :result) do
      'High'   | true  | true  | false | false | %w[email phone credit_card]
      'High'   | true  | true  | true  | false | %w[email credit_card]
      'High'   | true  | true  | false | true  | %w[email]
      'High'   | false | true  | false | false | %w[email phone]
      'High'   | true  | false | false | false | %w[email credit_card]
      'High'   | false | false | false | false | %w[email]
      'Medium' | true  | true  | false | false | %w[email phone]
      'Medium' | false | true  | false | false | %w[email phone]
      'Medium' | true  | true  | true  | false | %w[email credit_card]
      'Medium' | true  | true  | false | true  | %w[email]
      'Medium' | true  | false | false | false | %w[email]
      'Medium' | false | false | false | false | %w[email]
      'Low'    | true  | true  | false | false | %w[email]
      'Low'    | false | true  | false | false | %w[email]
      'Low'    | true  | false | false | false | %w[email]
      'Low'    | false | false | false | false | %w[email]
      nil      | true  | true  | false | false | %w[email]
      nil      | false | true  | false | false | %w[email]
      nil      | true  | false | false | false | %w[email]
      nil      | false | false | false | false | %w[email]
    end

    with_them do
      before do
        add_user_risk_band(risk_band) if risk_band
        user.add_phone_number_verification_exemption if phone_exempt
        user.add_identity_verification_exemption('test') if identity_verification_exempt

        stub_application_setting(credit_card_verification_enabled: credit_card)
        stub_application_setting(phone_verification_enabled: phone_number)
      end

      it { is_expected.to eq(result) }
    end

    context 'when user is already active i.e. signed in at least once' do
      let(:user) { create(:user, :unconfirmed, last_sign_in_at: Time.zone.now) }

      where(:phone_exempt, :email_verified, :assumed_high_risk, :affected_by_phone_verifications_limit, :result) do
        false | true  | false | false | %w[phone]
        false | false | false | false | %w[email]
        true  | true  | false | false | %w[credit_card]
        false | true  | true  | false | %w[credit_card phone]
        false | false | true  | false | %w[email credit_card phone]
        false | true  | false | true  | %w[credit_card]
      end

      with_them do
        before do
          user.add_phone_number_verification_exemption if phone_exempt
          user.assume_high_risk!(reason: 'test') if assumed_high_risk
          user.confirm if email_verified

          stub_phone_verification_limits(
            soft: affected_by_phone_verifications_limit,
            hard: affected_by_phone_verifications_limit
          )
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when phone verifications soft limit has been exceeded' do
      where(:risk_band, :result) do
        'High'   | %w[email credit_card phone]
        'Medium' | %w[email phone]
        'Low'    | %w[email]
        nil      | %w[email]
      end

      with_them do
        before do
          stub_phone_verification_limits(soft: true, hard: false)
          add_user_risk_band(risk_band) if risk_band
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when phone verifications hard limit has been exceeded' do
      before do
        stub_phone_verification_limits(soft: true, hard: true)
        add_user_risk_band(risk_band) if risk_band
      end

      where(:risk_band, :result) do
        'High'   | %w[email credit_card]
        'Medium' | %w[email credit_card]
        'Low'    | %w[email credit_card]
        nil      | %w[email credit_card]
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end

    context 'when user is assumed high risk' do
      where(:risk_band, :phone_exempt, :identity_verification_exempt, :result) do
        'High'   | false | false | %w[email credit_card phone]
        'High'   | true  | false | %w[email credit_card]
        'High'   | false | true  | %w[email]
        'Medium' | false | false | %w[email credit_card phone]
        'Medium' | true  | false | %w[email credit_card]
        'Medium' | false | true  | %w[email]
        'Low'    | false | false | %w[email credit_card phone]
        'Low'    | true  | false | %w[email credit_card]
        'Low'    | false | true  | %w[email]
        nil      | false | false | %w[email credit_card phone]
        nil      | true  | false | %w[email credit_card]
        nil      | false | true  | %w[email]
      end

      with_them do
        before do
          user.assume_high_risk!(reason: 'test')

          add_user_risk_band(risk_band) if risk_band
          user.add_phone_number_verification_exemption if phone_exempt
          user.add_identity_verification_exemption('test') if identity_verification_exempt
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe('#identity_verification_state') do
    describe 'credit card verification state' do
      before do
        add_user_risk_band('High')
      end

      subject { user.identity_verification_state['credit_card'] }

      context 'when user has not verified a credit card' do
        let(:user) { create(:user, credit_card_validation: nil) }

        it { is_expected.to be false }
      end

      context 'when user has verified a credit card' do
        let(:validation) { create(:credit_card_validation) }
        let(:user) { create(:user, credit_card_validation: validation) }

        it { is_expected.to be true }
      end
    end

    describe 'phone verification state' do
      before do
        add_user_risk_band('Medium')
      end

      subject { user.identity_verification_state['phone'] }

      context 'when user has no phone number' do
        let(:user) { create(:user, phone_number_validation: nil) }

        it { is_expected.to be false }
      end

      context 'when user has not verified a phone number' do
        let(:validation) { create(:phone_number_validation) }
        let(:user) { create(:user, phone_number_validation: validation) }

        before do
          allow(validation).to receive(:validated?).and_return(false)
        end

        it { is_expected.to be false }
      end

      context 'when user has verified a phone number' do
        let(:validation) { create(:phone_number_validation) }
        let(:user) { create(:user, phone_number_validation: validation) }

        before do
          allow(validation).to receive(:validated?).and_return(true)
        end

        it { is_expected.to be true }
      end
    end

    describe 'email verification state' do
      subject { user.identity_verification_state['email'] }

      context 'when user has not verified their email' do
        let(:user) { create(:user, :unconfirmed) }

        it { is_expected.to be false }
      end

      context 'when user has verified their email' do
        let(:user) { create(:user) }

        it { is_expected.to be true }
      end
    end
  end

  describe('#credit_card_verified?') do
    subject { user.credit_card_verified? }

    context 'when user has not verified a credit card' do
      it { is_expected.to be false }
    end

    context 'when user has verified a credit card' do
      let!(:credit_card_validation) { create(:credit_card_validation, user: user) }

      it { is_expected.to be true }

      context 'when credit card has been used by a banned user' do
        before do
          allow(credit_card_validation).to receive(:used_by_banned_user?).and_return(true)
        end

        it { is_expected.to be false }
      end
    end
  end

  describe '#add_phone_number_verification_exemption' do
    subject(:call_method) { user.add_phone_number_verification_exemption }

    it 'adds an exemption', :aggregate_failures, quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/492093' do
      expect(user).to receive(:clear_memoization).with(:identity_verification_state)
      expect(user.send(:risk_profile)).to receive(:add_phone_number_verification_exemption)

      subject
    end

    shared_examples 'it does not add an exemption' do
      specify :aggregate_failures do
        expect(user).not_to receive(:clear_memoization)
        expect(user.send(:risk_profile)).not_to receive(:add_phone_number_verification_exemption)

        subject
      end
    end

    context 'when user has already verified a phone number' do
      before do
        create(:phone_number_validation, :validated, user: user)
      end

      it_behaves_like 'it does not add an exemption'
    end

    context 'when user is already exempt' do
      before do
        allow(user).to receive(:phone_number_verification_exempt?).and_return(true)
      end

      it_behaves_like 'it does not add an exemption'
    end
  end

  describe '#identity_verification_exempt?' do
    subject(:identity_verification_exempt) { user.identity_verification_exempt? }

    let(:user) { create(:user) }

    let_it_be(:group_paid) { create(:group_with_plan, :public, plan: :ultimate_plan) }

    let_it_be(:group_trial) do
      create(
        :group_with_plan,
        :public,
        plan: :ultimate_plan,
        trial: true,
        trial_starts_on: Date.current,
        trial_ends_on: 30.days.from_now
      )
    end

    context 'when a user has a identity verification exemption' do
      before do
        user.add_identity_verification_exemption('test')
      end

      it { is_expected.to be true }
    end

    context 'when a user is an enterprise user' do
      let(:user) { create(:enterprise_user) }

      it { is_expected.to be true }
    end

    context 'when a user is a pending member of a paid non-trial namespace' do
      before do
        create(:group_member, :awaiting, :developer, source: group_paid, user: user)
      end

      it { is_expected.to be true }
    end

    context 'when a user is a member of a paid non-trial namespace' do
      before do
        create(:group_member, :developer, source: group_paid, user: user)
      end

      it { is_expected.to be true }
    end

    context 'when a user is a member of a paid trial namespace' do
      before do
        create(:group_member, :awaiting, :developer, source: group_trial, user: user)
      end

      it { is_expected.to be_falsy }
    end

    context 'when a user is a member of an open source plan namespace' do
      let(:group_oss) { create(:group_with_plan, :public, plan: :opensource_plan) }
      let(:id_check_for_oss_feature_flag) { true }

      before do
        stub_feature_flags(id_check_for_oss: id_check_for_oss_feature_flag)
        create(:group_member, :developer, source: group_oss, user: user)
      end

      it { is_expected.to be false }

      context 'with id_check_for_oss feature flag is disabled' do
        let(:id_check_for_oss_feature_flag) { false }

        it { is_expected.to be true }
      end

      context 'with user created before ID check become required for OSS' do
        before do
          user.created_at = described_class::IDENTITY_VERIFICATION_FOR_OSS_FROM_DATE - 1.day
        end

        it { is_expected.to be true }
      end
    end

    context 'when a user is a Developer on a subgroup but only a Guest at the root of a paid namespace' do
      let_it_be(:subgroup) { create(:group, parent: group_paid) }

      before do
        create(:group_member, :guest, source: group_paid, user: user)
        create(:group_member, :developer, source: subgroup, user: user)
      end

      context 'when the identity_verification_paid_membership feature flag is disabled' do
        before do
          stub_feature_flags(identity_verification_paid_membership: false)
        end

        it { is_expected.to be false }
      end

      context 'when the identity_verification_paid_membership feature flag is enabled' do
        before do
          stub_feature_flags(identity_verification_paid_membership: true)
        end

        it { is_expected.to be true }
      end
    end

    context 'when a user is not an enterprise user, a paid namespace member or exempted' do
      it { is_expected.to be_falsy }
    end
  end

  describe '#toggle_phone_number_verification' do
    before do
      allow(user).to receive(:clear_memoization).with(:identity_verification_state).and_call_original
    end

    subject(:toggle_phone_number_verification) { user.toggle_phone_number_verification }

    context 'when not exempt from phone number verification' do
      it 'creates an exemption' do
        expect(user).to receive(:add_phone_number_verification_exemption)

        toggle_phone_number_verification
      end
    end

    context 'when exempt from phone number verification' do
      it 'destroys the exemption' do
        user.add_phone_number_verification_exemption

        expect { toggle_phone_number_verification }.to change {
                                                         user.phone_number_verification_exempt?
                                                       }.from(true).to(false)
      end
    end

    it 'clears memoization of identity_verification_state' do
      expect(user).to receive(:clear_memoization).with(:identity_verification_state)

      toggle_phone_number_verification
    end
  end

  describe '#offer_phone_number_exemption?' do
    subject(:offer_phone_number_exemption?) { user.offer_phone_number_exemption? }

    where(:credit_card, :phone_number, :phone_exempt, :required_verification_methods, :result) do
      true   | true  | false | %w[email]                   | false
      false  | true  | false | %w[email phone]             | false
      true   | true  | false | %w[email phone]             | true
      true   | false | false | %w[email credit_card]       | false
      true   | true  | false | %w[email credit_card]       | false
      true   | true  | true  | %w[email credit_card]       | true
      true   | true  | false | %w[email phone credit_card] | false
    end

    with_them do
      before do
        stub_application_setting(credit_card_verification_enabled: credit_card)
        stub_application_setting(phone_verification_enabled: phone_number)

        allow(user).to receive(:required_identity_verification_methods).and_return(required_verification_methods)
        user.add_phone_number_verification_exemption if phone_exempt
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '#verification_method_allowed?' do
    subject(:result) { user.verification_method_allowed?(method: method) }

    context 'when verification method is not required' do
      let_it_be(:user, freeze: false) { create(:user, :medium_risk, confirmed_at: Time.current) }
      let(:method) { 'credit_card' }

      it { is_expected.to be false }
    end

    context 'when verification method is required but already completed' do
      let_it_be(:user, freeze: false) { create(:user, :low_risk, confirmed_at: Time.current) }
      let(:method) { 'email' }

      it { is_expected.to be false }
    end

    context 'when verification method is required and not completed' do
      context 'when there are prerequisite verification methods' do
        let(:method) { 'credit_card' }

        context 'when all prerequisite verification methods are completed' do
          let_it_be(:user, freeze: false) { create(:user, :high_risk, confirmed_at: Time.current) }
          let_it_be(:phone_number_validation) { create(:phone_number_validation, :validated, user: user) }

          it { is_expected.to be true }
        end

        context 'when any of prerequisite verification methods are incomplete' do
          let_it_be(:user, freeze: false) { create(:user, :high_risk, confirmed_at: Time.current) }

          it { is_expected.to be false }
        end

        context 'when all of prerequisite verification methods are incomplete' do
          let_it_be(:user, freeze: false) { create(:user, :high_risk, :unconfirmed) }

          it { is_expected.to be false }
        end
      end

      context 'when there are no prerequisite verification methods' do
        let_it_be(:user, freeze: false) { create(:user, :unconfirmed) }
        let(:method) { 'email' }

        it { is_expected.to be true }
      end
    end
  end

  describe '#requires_identity_verification_to_create_group?' do
    let_it_be(:top_level_group) { build(:group) }
    let(:group) { top_level_group }

    subject { user.requires_identity_verification_to_create_group?(group) }

    before do
      allow(user).to receive(:identity_verification_enabled?).and_return(true)
      allow(user).to receive(:identity_verified?).and_return(false)
    end

    context 'when the user has created the max number of groups' do
      before do
        create_list(:group, ::Gitlab::CurrentSettings.unverified_account_group_creation_limit, creator: user)
      end

      it { is_expected.to be(true) }

      context 'when the group is a subgroup' do
        let(:group) { build(:group, parent: top_level_group) }

        it { is_expected.to be(false) }
      end

      context 'when the user is already identity verified' do
        before do
          allow(user).to receive(:identity_verified?).and_return(true)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when the user has not created the max number of groups' do
      before do
        create_list(:group, ::Gitlab::CurrentSettings.unverified_account_group_creation_limit - 1, creator: user)
      end

      it { is_expected.to be(false) }
    end
  end

  it 'delegates risk profile methods', :aggregate_failures do
    expect_next_instance_of(IdentityVerification::UserRiskProfile, user) do |instance|
      expect(instance).to receive(:arkose_verified?).ordered
      expect(instance).to receive(:assume_low_risk!).with(reason: 'Low reason').ordered
      expect(instance).to receive(:assume_high_risk!).with(reason: 'High reason').ordered
      expect(instance).to receive(:assumed_high_risk?).ordered
      expect(instance).to receive(:add_identity_verification_exemption)
      expect(instance).to receive(:remove_identity_verification_exemption)
      expect(instance).to receive(:phone_number_verification_exempt?)
      expect(instance).to receive(:assume_high_risk_if_phone_verification_limit_exceeded!)
    end

    user.arkose_verified?
    user.assume_low_risk!(reason: 'Low reason')
    user.assume_high_risk!(reason: 'High reason')
    user.assumed_high_risk?
    user.add_identity_verification_exemption
    user.remove_identity_verification_exemption
    user.phone_number_verification_exempt?
    user.assume_high_risk_if_phone_verification_limit_exceeded!
  end
end
