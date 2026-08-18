# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Runner, :clean_gitlab_redis_shared_state, feature_category: :fleet_visibility do # rubocop:disable RSpec/SpecFilePathFormat -- spec split into per-endpoint files under runner/
  include StubGitlabCalls
  include RedisHelpers

  before do
    stub_gitlab_calls
    stub_application_setting(valid_runner_registrars: ApplicationSetting::VALID_RUNNER_REGISTRAR_TYPES)
  end

  describe 'POST /runners/reset_authentication_token', :freeze_time do
    subject(:perform_request) do
      post api('/runners/reset_authentication_token'), params: { token: runner.reload.token }
    end

    context 'when runner has a token_rotation_deadline' do
      let_it_be_with_reload(:runner) do
        create(:ci_runner, :instance, token_expires_at: 10.days.from_now)
      end

      before do
        runner.update_column(:token_rotation_deadline, token_rotation_deadline)
      end

      context 'when token_rotation_deadline has passed' do
        let(:token_rotation_deadline) { 1.minute.ago }

        it 'returns forbidden and does not reset the token' do
          expect do
            perform_request

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['error']).to eq('Token rotation deadline has passed')
          end.not_to change { runner.reload.token }
        end
      end

      context 'when token_rotation_deadline is in the future' do
        let(:token_rotation_deadline) { 1.day.from_now }

        it 'resets the token and clears the deadline' do
          expect do
            perform_request

            expect(response).to have_gitlab_http_status(:success)
          end.to change { runner.reload.token }

          expect(runner.reload.token_rotation_deadline).to be_nil
        end
      end
    end
  end
end
