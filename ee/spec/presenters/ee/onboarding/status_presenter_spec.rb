# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::StatusPresenter, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  context 'for delegations' do
    subject { described_class.new({}, nil, nil) }

    it { is_expected.to delegate_method(:tracking_label).to(:registration_type) }
    it { is_expected.to delegate_method(:event_label).to(:registration_type) }
    it { is_expected.to delegate_method(:account_created_product_interaction).to(:registration_type) }
    it { is_expected.to delegate_method(:setup_for_company_label_text).to(:registration_type) }
    it { is_expected.to delegate_method(:setup_for_company_help_text).to(:registration_type) }
    it { is_expected.to delegate_method(:get_started_subtext).to(:registration_type) }
    it { is_expected.to delegate_method(:signup_page_image).to(:registration_type) }
    it { is_expected.to delegate_method(:signup_page_heading).to(:registration_type) }
    it { is_expected.to delegate_method(:identity_verification_panel_image).to(:registration_type) }
    it { is_expected.to delegate_method(:identity_verification_panel_heading).to(:registration_type) }
    it { is_expected.to delegate_method(:show_company_form_footer?).to(:registration_type) }
    it { is_expected.to delegate_method(:show_company_form_side_column?).to(:registration_type) }
    it { is_expected.to delegate_method(:redirect_to_company_form?).to(:registration_type) }
    it { is_expected.to delegate_method(:show_joining_project?).to(:registration_type) }
    it { is_expected.to delegate_method(:read_from_stored_user_location?).to(:registration_type) }
    it { is_expected.to delegate_method(:preserve_stored_location?).to(:registration_type) }
    it { is_expected.to delegate_method(:learn_gitlab_redesign?).to(:registration_type) }
    it { is_expected.to delegate_method(:preregistration_tracking_label).to(:registration_type).as(:tracking_label) }
    it { is_expected.to delegate_method(:unification_enabled?).to(:registration_type) }
    it { is_expected.to delegate_method(:redirect_to_customers_portal?).to(:registration_type) }
  end

  describe '.glm_tracking_params' do
    let(:params) { ActionController::Parameters.new(glm_source: 'source', glm_content: 'content', extra: 'param') }

    subject { described_class.glm_tracking_params(params) }

    it { is_expected.to eq(params.slice(:glm_source, :glm_content).permit!) }

    context 'when not all are present' do
      let(:params) { ActionController::Parameters.new(glm_content: 'content') }

      it { is_expected.to eq(params.slice(:glm_content).permit!) }
    end
  end

  describe '.passed_through_params' do
    let(:params) do
      ActionController::Parameters.new(jobs_to_be_done_other: 'jtbd_o')
    end

    subject { described_class.passed_through_params(params) }

    it 'permits correct parameters' do
      is_expected.to eq(params.slice(:jobs_to_be_done_other).permit!)
    end
  end

  describe '.glm_tracking_attributes' do
    let(:params) { ActionController::Parameters.new(glm_source: 'source', glm_content: 'content', extra: 'param') }
    let(:expected_params) { { glm_source: 'source', glm_content: 'content' }.stringify_keys }

    subject { described_class.glm_tracking_attributes(params) }

    it { is_expected.to eq(expected_params) }
  end

  describe '.registration_path_params' do
    let(:params) { ActionController::Parameters.new(glm_source: 'source', glm_content: 'content', extra: 'param') }
    let(:onboarding_enabled) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled)
    end

    subject { described_class.registration_path_params(params: params) }

    context 'when onboarding is enabled' do
      let(:expected_params) { { glm_source: 'source', glm_content: 'content' } }

      it { is_expected.to eq(expected_params.stringify_keys) }
    end

    context 'when onboarding is disabled' do
      let(:onboarding_enabled) { false }

      it { is_expected.to eq({}) }
    end
  end

  describe '#registration_omniauth_params' do
    let(:params) { { glm_source: 'source', glm_content: 'content', extra: 'param' } }
    let(:onboarding_enabled) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled)
    end

    subject { described_class.new(params, nil, nil).registration_omniauth_params }

    context 'when onboarding is enabled' do
      it { is_expected.to eq({ glm_source: 'source', glm_content: 'content', onboarding_status_email_opt_in: true }) }
    end

    context 'when onboarding is disabled' do
      let(:onboarding_enabled) { false }

      it { is_expected.to eq({}) }
    end
  end

  describe '#email_opt_in?' do
    let(:params) { { onboarding_status_email_opt_in: 'true' } }

    subject { described_class.new(params, nil, nil).email_opt_in? }

    context 'when onboarding_status_email_opt_in is true' do
      it { is_expected.to be(true) }
    end

    context 'when onboarding_status_email_opt_in is false' do
      let(:params) { { onboarding_status_email_opt_in: 'false' } }

      it { is_expected.to be(false) }
    end

    context 'when onboarding_status_email_opt_in is not present' do
      let(:params) { {} }

      it { is_expected.to be(true) }
    end
  end

  describe '#trial_registration_omniauth_params' do
    let(:params) { { glm_source: 'source', glm_content: 'content', extra: 'param' } }
    let(:onboarding_enabled) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled)
    end

    subject { described_class.new(params, nil, nil).trial_registration_omniauth_params }

    context 'when onboarding is enabled' do
      it 'has the glm, onboarding and trial params' do
        is_expected
          .to eq({ glm_source: 'source', glm_content: 'content', onboarding_status_email_opt_in: true, trial: true })
      end
    end

    context 'when onboarding is disabled' do
      let(:onboarding_enabled) { false }

      it { is_expected.to eq({ trial: true }) }
    end
  end

  describe '#continue_full_onboarding?' do
    let(:session_in_oauth) { ::Gitlab::Routing.url_helpers.oauth_authorization_path(some_param: '_param_') }
    let(:session_not_in_oauth) { nil }

    where(:registration_type, :user_return_to, :enabled?, :expected_result) do
      'free'         | ref(:session_not_in_oauth) | true  | true
      'free'         | ref(:session_in_oauth)     | true  | false
      'free'         | ref(:session_not_in_oauth) | false | false
      'free'         | ref(:session_in_oauth)     | false | false
      nil            | ref(:session_not_in_oauth) | true  | true
      nil            | ref(:session_in_oauth)     | true  | false
      nil            | ref(:session_not_in_oauth) | false | false
      nil            | ref(:session_in_oauth)     | false | false
      'trial'        | ref(:session_not_in_oauth) | true  | true
      'trial'        | ref(:session_in_oauth)     | true  | false
      'trial'        | ref(:session_not_in_oauth) | false | false
      'trial'        | ref(:session_in_oauth)     | false | false
    end

    with_them do
      let(:current_user) { create(:user, onboarding_status_registration_type: registration_type) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persisted check
      let(:instance) { described_class.new({}, user_return_to, current_user) }

      before do
        stub_saas_features(onboarding: enabled?)
      end

      subject { instance.continue_full_onboarding? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#welcome_submit_button_text' do
    let(:continue_text) { _('Continue') }
    let(:get_started_text) { _('Get started!') }
    let(:session_in_oauth) { ::Gitlab::Routing.url_helpers.oauth_authorization_path(some_param: '_param_') }
    let(:session_not_in_oauth) { nil }

    where(:registration_type, :user_return_to, :expected_result) do
      'free'         | ref(:session_not_in_oauth) | ref(:continue_text)
      'free'         | ref(:session_in_oauth)     | ref(:get_started_text)
      nil            | ref(:session_not_in_oauth) | ref(:continue_text)
      nil            | ref(:session_in_oauth)     | ref(:get_started_text)
      'trial'        | ref(:session_not_in_oauth) | ref(:continue_text)
      'trial'        | ref(:session_in_oauth)     | ref(:get_started_text)
    end

    with_them do
      let(:current_user) { create(:user, onboarding_status_registration_type: registration_type) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persisted check
      let(:instance) { described_class.new({}, user_return_to, current_user) }

      before do
        stub_saas_features(onboarding: true)
      end

      subject { instance.welcome_submit_button_text }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#tracking_label' do
    let(:current_user) { build(:user) }

    it 'delegates to the resolved registration type' do
      expect(described_class.new({}, nil, current_user).tracking_label)
        .to eq ::Onboarding::FreeRegistration.tracking_label
    end

    context 'when user is nil' do
      it 'defaults to FreeRegistration' do
        expect(described_class.new({}, nil, nil).tracking_label)
          .to eq ::Onboarding::FreeRegistration.tracking_label
      end

      context 'when it is an invite' do
        it 'returns InviteRegistration tracking label' do
          expect(described_class.new({ invite_email: 'some_email@example.com' }, nil, nil).tracking_label)
            .to eq ::Onboarding::InviteRegistration.tracking_label
        end
      end

      context 'when it is a trial', :saas_onboarding do
        it 'returns TrialRegistration tracking label' do
          expect(described_class.new({ trial: true }, nil, nil).tracking_label)
            .to eq ::Onboarding::TrialRegistration.tracking_label
        end

        context 'when onboarding is disabled' do
          before do
            stub_saas_features(onboarding: false)
          end

          it 'falls back to FreeRegistration tracking label' do
            expect(described_class.new({ trial: true }, nil, nil).tracking_label)
              .to eq ::Onboarding::FreeRegistration.tracking_label
          end
        end
      end

      context 'when it is a subscription' do
        it 'returns SubscriptionRegistration tracking label' do
          user_return_to = ::Gitlab::Routing.url_helpers.new_subscriptions_path

          expect(described_class.new({}, user_return_to, nil).tracking_label)
            .to eq ::Onboarding::SubscriptionRegistration.tracking_label
        end
      end

      context 'when it is a self-managed subscription', :saas_onboarding do
        let(:user_return_to) do
          ::Gitlab::Routing.url_helpers.new_subscriptions_path(
            plan_id: 'abc123', deployment_type: 'self_managed'
          )
        end

        it 'returns SubscriptionSmRegistration tracking label' do
          expect(described_class.new({}, user_return_to, nil).tracking_label)
            .to eq ::Onboarding::SubscriptionSmRegistration.tracking_label
        end
      end

      context 'when it is a self-managed credits purchase (no plan_id)', :saas_onboarding do
        let(:user_return_to) do
          ::Gitlab::Routing.url_helpers.new_subscriptions_path(
            deployment_type: 'self_managed', plan_type: 'gitlab_credits'
          )
        end

        it 'returns SubscriptionSmRegistration tracking label' do
          expect(described_class.new({}, user_return_to, nil).tracking_label)
            .to eq ::Onboarding::SubscriptionSmRegistration.tracking_label
        end
      end
    end
  end

  describe '#convert_to_automatic_trial?' do
    where(:registration_type, :setup_for_company?, :expected_result) do
      'free'         | false | false
      'free'         | true  | true
      nil            | false | false
      nil            | true  | true
      'trial'        | false | false
      'trial'        | true  | false
    end

    with_them do
      let(:current_user) { create(:user, onboarding_status_registration_type: registration_type) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persisted check
      let(:instance) { described_class.new({}, nil, current_user) }

      before do
        allow(instance).to receive(:setup_for_company?).and_return(setup_for_company?)
      end

      subject { instance.convert_to_automatic_trial? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#setup_for_company?' do
    where(:params, :expected_result) do
      { onboarding_status_setup_for_company: true }   | true
      { onboarding_status_setup_for_company: false }  | false
      {} | false
    end

    with_them do
      let(:instance) { described_class.new(params, nil, nil) }

      subject { instance.setup_for_company? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#joining_a_project?' do
    let(:no_value_user) { build(:user) }
    let(:joining_user) { build(:user, onboarding_status_joining_project: true) }
    let(:not_joining_user) { build(:user, onboarding_status_joining_project: false) }

    where(:current_user, :expected_result) do
      ref(:joining_user)     | true
      ref(:not_joining_user) | false
      ref(:no_value_user)    | false
    end

    subject { described_class.new({}, nil, current_user).joining_a_project? }

    with_them do
      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#user_return_to' do
    let(:user_return_to) { nil }

    subject { described_class.new({}, user_return_to, nil).user_return_to }

    context 'when no user location is passed' do
      it { is_expected.to be_nil }
    end

    context 'when user location has value' do
      let(:user_return_to) { '/some/path' }

      it { is_expected.to eq('/some/path') }
    end
  end
end
