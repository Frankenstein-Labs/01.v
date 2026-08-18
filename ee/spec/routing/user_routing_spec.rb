# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE-specific user routing', feature_category: :system_access do
  describe 'devise_for users scope' do
    it 'defines regular and Geo routes' do
      [
        ['/users/sign_in', 'GET', 'new'],
        ['/users/auth/geo/sign_in', 'GET', 'new'],
        ['/users/sign_in', 'POST', 'create'],
        ['/users/auth/geo/sign_in', 'POST', 'create'],
        ['/users/sign_out', 'POST', 'destroy'],
        ['/users/auth/geo/sign_out', 'POST', 'destroy']
      ].each do |path, method, action|
        expect(Rails.application.routes.recognize_path(path, { method: method })).to include(
          { controller: 'sessions', action: action }
        )
      end
    end

    shared_examples 'routes session paths' do |route_type|
      before do
        allow(Gitlab::Geo).to receive(:secondary?).with(infer_without_database: true).and_return(route_type == :geo)
        Rails.application.reload_routes!
      end

      after do
        allow(Gitlab::Geo).to receive(:secondary?).with(infer_without_database: true).and_call_original
        Rails.application.reload_routes!
      end

      it "handles #{route_type} named route helpers" do
        sign_in_path, sign_out_path = case route_type
                                      when :regular then
                                        ['/users/sign_in', '/users/sign_out']
                                      when :geo then
                                        ['/users/auth/geo/sign_in', '/users/auth/geo/sign_out']
                                      end

        expect(Gitlab::Routing.url_helpers.new_user_session_path).to eq(sign_in_path)
        expect(Gitlab::Routing.url_helpers.destroy_user_session_path).to eq(sign_out_path)
      end
    end

    context 'when a Geo secondary, checked without a database connection' do
      it_behaves_like 'routes session paths', :regular
    end

    context 'Geo database is configured' do
      it_behaves_like 'routes session paths', :geo
    end
  end

  describe 'sign up routes', feature_category: :acquisition do
    let(:trial_user_match?) { false }
    let(:invite_user_match?) { false }
    let(:subscription_user_match?) { false }
    let(:free_automatic_trial_match?) { false }

    before do
      allow_any_instance_of(Onboarding::TrialUserConstraint).to receive(:matches?).and_return(trial_user_match?) # rubocop:disable RSpec/AnyInstanceOf -- Needed as it is not the next instance
      allow_any_instance_of(Onboarding::InviteUserConstraint).to receive(:matches?).and_return(invite_user_match?) # rubocop:disable RSpec/AnyInstanceOf -- Needed as it is not the next instance
      allow_any_instance_of(Onboarding::SubscriptionUserConstraint) # rubocop:disable RSpec/AnyInstanceOf -- Needed as it is not the next instance
        .to receive(:matches?).and_return(subscription_user_match?)
      allow_any_instance_of(Onboarding::FreeAutomaticTrialConstraint) # rubocop:disable RSpec/AnyInstanceOf -- Needed as it is not the next instance
        .to receive(:matches?).and_return(free_automatic_trial_match?)
    end

    it 'routes to welcome controller' do
      expect(get: '/users/sign_up/welcome').to route_to(controller: 'registrations/welcome', action: 'show')
      expect(patch: '/users/sign_up/welcome').to route_to(controller: 'registrations/welcome', action: 'update')
    end

    it 'routes to registrations controller for new' do
      expect(get: '/users/sign_up/').to route_to(controller: 'registrations', action: 'new')
    end

    context 'when trial user constraint is satisfied' do
      let(:trial_user_match?) { true }

      it 'routes to trial_welcome controller for show and update' do
        expect(get: '/users/sign_up/welcome').to route_to(controller: 'registrations/trial_welcome', action: 'show')
        expect(patch: '/users/sign_up/welcome').to route_to(controller: 'registrations/trial_welcome', action: 'update')
      end
    end

    context 'when invite user constraint is satisfied' do
      let(:invite_user_match?) { true }

      it 'routes to invite_welcome controller for show and update' do
        expect(get: '/users/sign_up/welcome').to route_to(controller: 'registrations/invite_welcome', action: 'show')
        expect(patch: '/users/sign_up/welcome')
          .to route_to(controller: 'registrations/invite_welcome', action: 'update')
      end
    end

    context 'when subscription user constraint is satisfied' do
      let(:subscription_user_match?) { true }

      it 'routes to subscription_welcome controller for show and update' do
        expect(get: '/users/sign_up/welcome')
          .to route_to(controller: 'registrations/subscription_welcome', action: 'show')
        expect(patch: '/users/sign_up/welcome')
          .to route_to(controller: 'registrations/subscription_welcome', action: 'update')
      end
    end

    context 'when free automatic trial constraint is satisfied' do
      let(:free_automatic_trial_match?) { true }

      it 'routes the welcome submit (PATCH) to the trial_welcome controller' do
        expect(patch: '/users/sign_up/welcome')
          .to route_to(controller: 'registrations/trial_welcome', action: 'update')
      end

      it 'still routes a GET to the free welcome controller' do
        expect(get: '/users/sign_up/welcome').to route_to(controller: 'registrations/welcome', action: 'show')
      end
    end

    context 'when no onboarding constraint is satisfied' do
      it 'serves the free welcome controller' do
        expect(get: '/users/sign_up/welcome').to route_to(controller: 'registrations/welcome', action: 'show')
        expect(patch: '/users/sign_up/welcome').to route_to(controller: 'registrations/welcome', action: 'update')
      end
    end

    context 'for ordering priority' do
      using RSpec::Parameterized::TableSyntax

      where(:trial_match, :invite_match, :subscription_match, :free_automatic_trial_match, :expected_controller) do
        true  | true  | false | false | 'registrations/trial_welcome'
        true  | false | true  | false | 'registrations/trial_welcome'
        true  | true  | true  | false | 'registrations/trial_welcome'
        false | true  | true  | false | 'registrations/invite_welcome'
        false | false | true  | false | 'registrations/subscription_welcome'
        true  | false | false | true  | 'registrations/trial_welcome'
        false | true  | false | true  | 'registrations/invite_welcome'
        false | false | true  | true  | 'registrations/subscription_welcome'
      end

      with_them do
        let(:trial_user_match?) { trial_match }
        let(:invite_user_match?) { invite_match }
        let(:subscription_user_match?) { subscription_match }
        let(:free_automatic_trial_match?) { free_automatic_trial_match }

        it 'routes to the correct controller for show and update' do
          expect(get: '/users/sign_up/welcome').to route_to(controller: expected_controller, action: 'show')
          expect(patch: '/users/sign_up/welcome').to route_to(controller: expected_controller, action: 'update')
        end
      end
    end
  end
end
