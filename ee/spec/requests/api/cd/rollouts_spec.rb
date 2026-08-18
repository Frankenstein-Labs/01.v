# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Cd::Rollouts, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }

  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::JwtAuthenticatable::SECRET_LENGTH) }

  let(:rollout) do
    create(:cd_rollout, application: application, version_set: version_set, state: :in_progress,
      workflow_ref: 'wk:1/abc')
  end

  let(:headers) { { 'Authorization' => "Bearer #{Cd::Rollouts::CallbackToken.encode(rollout)}" } }

  before do
    allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)
  end

  describe 'POST /rollouts/:id' do
    subject(:request) { post api("/rollouts/#{rollout.id}"), params: params, headers: headers }

    let(:params) do
      { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_started',
        data: { position: [1], step_type: 'com.gitlab.cd.steps.wait' } }
    end

    context 'when no callback token is given' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the callback token was issued for a different rollout' do
      let(:other_rollout) { create(:cd_rollout) }
      let(:headers) { { 'Authorization' => "Bearer #{Cd::Rollouts::CallbackToken.encode(other_rollout)}" } }

      it 'returns unauthorized' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the callback token is malformed' do
      let(:headers) { { 'Authorization' => 'Bearer not-a-real-jwt' } }

      it 'returns unauthorized' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the callback token has expired' do
      let(:headers) do
        travel_to(Cd::Rollouts::CallbackToken::EXPIRE_IN.ago - 1.minute) do
          { 'Authorization' => "Bearer #{Cd::Rollouts::CallbackToken.encode(rollout)}" }
        end
      end

      it 'returns unauthorized' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the rollout does not exist' do
      subject(:request) { post api("/rollouts/#{non_existing_record_id}"), params: params, headers: headers }

      it 'returns unauthorized, the same as an existing rollout with a non-matching token' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the event topic is not recognised' do
      let(:params) do
        { topic: 'com.gitlab.cd.something_unknown', type: 'com.gitlab.cd.step_started', data: { position: [0] } }
      end

      it 'returns bad_request' do
        request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when an event other than rollout_succeeded omits its position' do
      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_started',
          data: { step_type: 'com.gitlab.cd.steps.wait' } }
      end

      it 'returns bad_request' do
        request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when the event type is not recognised' do
      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.something_unknown', data: { position: [0] } }
      end

      it 'returns accepted' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
      end
    end

    context 'with a step_started event outside any stage' do
      it 'acknowledges the event and returns accepted' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
      end

      it 'does not open an approval gate' do
        request

        expect(rollout.reload.open_approval_gate?).to be(false)
      end
    end

    context 'with a step_started event for an approval step' do
      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_started',
          data: { stage_name: 'production', position: [0, 0], step_type: 'com.gitlab.cd.steps.approval' } }
      end

      it 'opens an approval gate and returns accepted' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout.reload.open_approval_gate?).to be(true)
      end

      it 'records a request_approval transition attributed to the workflow' do
        request

        expect(rollout.rollout_transitions.last).to have_attributes(
          event: 'request_approval',
          from_state: rollout.state,
          to_state: rollout.state,
          principal: 'system:autoflow'
        )
      end

      context 'when retried after already opening the gate' do
        it 'treats the retry as a no-op and does not duplicate the transition' do
          post api("/rollouts/#{rollout.id}"), params: params, headers: headers

          expect { request }.not_to change { rollout.rollout_transitions.count }
          expect(response).to have_gitlab_http_status(:accepted)
        end
      end

      context 'when the rollout already reached a terminal state' do
        before do
          rollout.cancel!
        end

        it 'does not open an approval gate on the stale/late-arriving event' do
          expect { request }.not_to change { rollout.rollout_transitions.count }

          expect(response).to have_gitlab_http_status(:accepted)
          expect(rollout.reload.open_approval_gate?).to be(false)
        end
      end
    end

    context 'with a step_started event inside a stage' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :in_progress)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_started',
          data: { stage_name: 'production', position: [0, 0], step_type: 'com.gitlab.cd.argo.canary.deploy' } }
      end

      it 'acknowledges the event without changing the rollout environment' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('in_progress')
      end
    end

    context 'with a step_started event that names its environment' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :pending)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_started',
          data: { stage_name: 'production', environment: 'production', position: [0, 0],
                  step_type: 'com.gitlab.cd.argo.canary.deploy' } }
      end

      it 'transitions the named rollout environment to in_progress' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('in_progress')
      end
    end

    context 'with a step_succeeded event that names its environment' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :in_progress)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_succeeded',
          data: { stage_name: 'production', environment: 'production', position: [0, 0],
                  step_type: 'com.gitlab.cd.argo.canary.deploy' } }
      end

      it 'transitions the named rollout environment to completed' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('completed')
      end
    end

    context 'with a stage_started event' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :pending)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.stage_started',
          data: { stage_name: 'production', environment: 'production', position: [0] } }
      end

      it 'transitions the named rollout environment to in_progress and returns accepted' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('in_progress')
      end

      context 'when retried after already being applied' do
        it 'treats the retry as a no-op and returns accepted' do
          post api("/rollouts/#{rollout.id}"), params: params, headers: headers

          request

          expect(response).to have_gitlab_http_status(:accepted)
          expect(rollout_environment.reload.state).to eq('in_progress')
        end
      end

      context 'when the environment does not match any rollout environment' do
        let(:params) do
          { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.stage_started',
            data: { stage_name: 'production', environment: 'unknown-environment', position: [0] } }
        end

        it 'returns accepted without changing any rollout environment' do
          request

          expect(response).to have_gitlab_http_status(:accepted)
          expect(rollout_environment.reload.state).to eq('pending')
        end
      end

      context 'when the event carries a stage_name but no environment' do
        let(:params) do
          { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.stage_started',
            data: { stage_name: 'production', position: [0] } }
        end

        it 'acknowledges the event without changing any rollout environment' do
          request

          expect(response).to have_gitlab_http_status(:accepted)
          expect(rollout_environment.reload.state).to eq('pending')
        end
      end

      context 'when the stage has more than one environment' do
        let(:environment_eu) { create(:cd_environment, organization: organization, name: 'production-eu') }
        let!(:rollout_environment_eu) do
          create(:cd_rollout_environment, rollout: rollout, environment: environment_eu, state: :pending)
        end

        let(:params_eu) do
          { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.stage_started',
            data: { stage_name: 'production', environment: 'production-eu', position: [0] } }
        end

        it 'resolves the rollout environment by the exact environment name, not the shared stage name' do
          post api("/rollouts/#{rollout.id}"), params: params_eu, headers: headers

          expect(response).to have_gitlab_http_status(:accepted)
          expect(rollout_environment_eu.reload.state).to eq('in_progress')
          expect(rollout_environment.reload.state).to eq('pending')
        end
      end
    end

    context 'with a stage_succeeded event' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :in_progress)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.stage_succeeded',
          data: { stage_name: 'production', environment: 'production', position: [0] } }
      end

      it 'transitions the named rollout environment to completed and returns accepted' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('completed')
      end
    end

    context 'with a step_failed event that names a stage' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :in_progress)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_failed',
          data: { stage_name: 'production', environment: 'production', position: [0, 0],
                  step_type: 'com.gitlab.cd.argo.rolling.deploy',
                  error: 'environment 42 not found in environments' } }
      end

      it 'transitions the named rollout environment to failed and returns accepted' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('failed')
      end
    end

    context 'with a step_failed event outside any stage' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :in_progress)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_failed',
          data: { position: [1], step_type: 'com.gitlab.cd.steps.wait',
                  error: 'unsupported step type: com.gitlab.cd.steps.wait' } }
      end

      it 'acknowledges the event without changing any rollout environment' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('in_progress')
      end
    end

    context 'with a rollout_succeeded event' do
      # Posted as JSON rather than form params, which drop an empty nested hash and so
      # would exercise a missing `data` instead of the empty one this event carries.
      subject(:request) do
        post api("/rollouts/#{rollout.id}"), params: params.to_json,
          headers: headers.merge('Content-Type' => 'application/json')
      end

      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :completed)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.rollout_succeeded', data: {} }
      end

      # The orchestrator fails the flow when a report is not accepted, so refusing the
      # terminal event for its empty payload would abort a deploy that had succeeded.
      it 'accepts the empty payload and returns accepted' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('completed')
      end
    end

    context 'when a stale event arrives after the environment already finished' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :completed)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.stage_started',
          data: { stage_name: 'production', environment: 'production', position: [0] } }
      end

      it 'leaves the already-terminal rollout environment unchanged' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('completed')
      end
    end

    context 'when a step_started event names a rollout step' do
      let!(:rollout_step) { create(:cd_rollout_step, rollout: rollout, path: '1', state: :pending) }

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_started',
          data: { position: [1], step_type: 'com.gitlab.cd.steps.wait' } }
      end

      it 'transitions the rollout step to running' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_step.reload.state).to eq('running')
      end
    end

    context 'when a step_succeeded event completes the only step in the rollout' do
      let!(:rollout_step) { create(:cd_rollout_step, rollout: rollout, path: '0', state: :running) }

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_succeeded',
          data: { position: [0], step_type: 'com.gitlab.cd.steps.wait' } }
      end

      it 'completes the rollout step and the rollout itself' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_step.reload.state).to eq('success')
        expect(rollout.reload.state).to eq('completed')
      end
    end

    context 'when a step_failed event names a rollout step' do
      let!(:rollout_step) { create(:cd_rollout_step, rollout: rollout, path: '0', state: :running) }
      let!(:other_step) { create(:cd_rollout_step, rollout: rollout, path: '1', state: :pending) }

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.step_failed',
          data: { position: [0], step_type: 'com.gitlab.cd.steps.wait', error: 'boom' } }
      end

      it 'fails the rollout step, records the error, and fails the rollout immediately' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_step.reload).to have_attributes(state: 'failed', error: 'boom')
        expect(other_step.reload.state).to eq('pending')
        expect(rollout.reload.state).to eq('failed')
      end
    end

    context 'when a stage_failed event names the stage step' do
      let!(:stage_step) { create(:cd_rollout_step, rollout: rollout, path: '0', state: :running) }

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.stage_failed',
          data: { stage_name: 'production', position: [0] } }
      end

      it 'fails the stage step and the rollout' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(stage_step.reload.state).to eq('failed')
        expect(rollout.reload.state).to eq('failed')
      end
    end

    context 'with a stage_failed event that names its environment' do
      let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
      let!(:rollout_environment) do
        create(:cd_rollout_environment, rollout: rollout, environment: environment, state: :in_progress)
      end

      let(:params) do
        { topic: 'com.gitlab.cd.deployment', type: 'com.gitlab.cd.stage_failed',
          data: { stage_name: 'production', environment: 'production', position: [0] } }
      end

      it 'transitions the named rollout environment to failed' do
        request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(rollout_environment.reload.state).to eq('failed')
      end
    end
  end
end
