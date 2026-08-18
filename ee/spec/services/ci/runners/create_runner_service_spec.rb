# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::CreateRunnerService, '#execute', feature_category: :runner_core do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:group_owner) { create(:user) }
  let_it_be(:group) { create(:group, owners: group_owner) }
  let_it_be(:project, freeze: false) { create(:project, namespace: group) }

  let(:runner) { execute.payload[:runner] }
  let(:expected_audit_kwargs) do
    {
      name: 'ci_runner_created',
      message: 'Created %{runner_type} CI runner'
    }
  end

  let(:service) { described_class.new(user: current_user, params: params) }

  subject(:execute) { service.execute }

  RSpec::Matchers.define :last_ci_runner do
    match { |runner| runner == ::Ci::Runner.last }
  end

  shared_examples 'runner creation transaction behavior' do
    context 'when runner save fails' do
      before do
        allow_next_instance_of(Ci::Runner) do |r|
          r.errors.add(:base, "Runner validation failed")
          allow(r).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(r))
        end
      end

      it 'returns error response with runner validation messages' do
        response = execute

        expect(response).to be_error
        expect(response.reason).to eq(:save_error)
        expect(response.message).to include("Runner validation failed")
      end

      it 'does not create any records' do
        expect { execute }
          .to not_change { Ci::Runner.count }
          .and not_change { Ci::HostedRunner.count }
      end
    end

    context 'when hosted runner creation fails' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
        params[:hosted_runner] = true

        allow(service).to receive(:create_hosted_runner!).and_raise(
          ActiveRecord::RecordInvalid.new(Ci::HostedRunner.new).tap do |e|
            e.record.errors.add(:base, "Hosted runner validation failed")
          end
        )
      end

      it 'returns error response with hosted runner validation messages' do
        response = execute

        expect(response).to be_error
        expect(response.reason).to eq(:save_error)
        expect(response.message).to include("Hosted runner validation failed")
      end

      it 'does not create any records' do
        expect { execute }
          .to not_change { Ci::Runner.count }
          .and not_change { Ci::HostedRunner.count }
      end
    end
  end

  shared_examples 'a service logging a runner audit event' do
    it 'returns newly-created runner' do
      expect_next_instance_of(
        ::AuditEvents::RunnerAuditEventService,
        last_ci_runner, current_user, expected_token_scope, **expected_audit_kwargs
      ) do |service|
        expect(service).to receive(:track_event).once.and_call_original
      end

      expect(execute).to be_success
      expect(runner).to eq(::Ci::Runner.last)
    end
  end

  shared_examples 'hosted runner created' do
    it 'creates a hosted runner record' do
      expect { subject }.to change { ::Ci::HostedRunner.count }.by(1)
    end

    it 'associates the hosted runner with the created runner' do
      response = subject
      runner = response.payload[:runner]

      expect(Ci::HostedRunner.last.runner_id).to eq(runner.id)
    end
  end

  shared_examples 'hosted runner not created' do
    it 'does not create a hosted runner record' do
      expect { subject }.not_to change { ::Ci::HostedRunner.count }
    end
  end

  shared_examples 'a service logging a token expiration validation failure' do |expected_runner_type:|
    it 'logs the validation failure' do
      expect(Gitlab::AppLogger).to receive(:info).with(
        hash_including(
          message: 'Token expiration validation failed',
          error_message: a_kind_of(String),
          runner_type: expected_runner_type
        )
      )

      expect(execute).to be_error
    end
  end

  context 'with :runner_type param set to instance_type' do
    let(:current_user) { admin }
    let(:params) { { runner_type: 'instance_type' } }
    let(:expected_token_scope) { an_instance_of(Gitlab::Audit::InstanceScope) }

    it 'runner payload is nil' do
      expect(runner).to be_nil
    end

    it { is_expected.to be_error }

    context 'when admin mode is enabled', :enable_admin_mode do
      it_behaves_like 'a service logging a runner audit event'
      it_behaves_like 'runner creation transaction behavior'

      context 'on a dedicated instance' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
        end

        context 'with hosted_runner param set to true' do
          before do
            params[:hosted_runner] = true
          end

          it_behaves_like 'hosted runner created'
        end

        context 'with hosted_runner param set to false' do
          before do
            params[:hosted_runner] = false
          end

          it_behaves_like 'hosted runner not created'
        end
      end

      context 'when not on a dedicated instance' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
          params[:hosted_runner] = true
        end

        it_behaves_like 'hosted runner not created'
      end

      context 'with token_expires_at param', :freeze_time do
        let(:params) { { runner_type: 'instance_type' }.merge(args) }

        before do
          stub_application_setting(runner_token_expiration_interval: 3600)
        end

        context 'when token_expires_at is capped by instance runner token expiration interval' do
          let(:args) { { token_expires_at: 2.hours.from_now } }

          it_behaves_like 'a service logging a token expiration validation failure',
            expected_runner_type: 'instance_type'

          it 'returns a validation error' do
            expect(execute).to be_error
            expect(execute.reason).to eq(:validation_error)
            expect(execute.message).to include('token_expires_at is too far in the future')
          end
        end

        context 'when token_expires_at is within instance runner token expiration interval' do
          let(:args) { { token_expires_at: 30.minutes.from_now } }

          it 'creates a runner successfully' do
            expect(execute).to be_success
            expect(runner.explicit_token_expires_at).to eq(args[:token_expires_at])
          end

          it 'includes token expiration tracking properties' do
            expect { execute }
              .to trigger_internal_events('create_ci_runner')
              .with(user: current_user, additional_properties: {
                label: 'instance_type',
                property: 'authenticated_user',
                has_token_expiration: 'true'
              })
          end

          context 'with token_rotation_deadline' do
            let(:args) { { token_expires_at: 30.minutes.from_now, token_rotation_deadline: 15.minutes.from_now } }

            it 'includes both tracking properties as true' do
              expect { execute }
                .to trigger_internal_events('create_ci_runner')
                .with(user: current_user, additional_properties: {
                  label: 'instance_type',
                  property: 'authenticated_user',
                  has_token_expiration: 'true',
                  has_rotation_deadline: 'true'
                })
            end
          end
        end
      end
    end
  end

  context 'with :runner_type param set to group_type' do
    let(:current_user) { group_owner }
    let(:params) { { runner_type: 'group_type', scope: group }.merge(args) }
    let(:args) { {} }
    let(:expected_token_scope) { group }

    it_behaves_like 'a service logging a runner audit event'
    it_behaves_like 'hosted runner not created'

    context 'with hosted_runner param set to true' do
      before do
        params[:hosted_runner] = true
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      it_behaves_like 'hosted runner not created'
    end

    context 'with token_expires_at param', :freeze_time do
      let(:token_expires_at) { 10.minutes.from_now }
      let(:args) { { token_expires_at: token_expires_at } }

      it 'includes token expiration tracking properties' do
        expect { execute }
          .to trigger_internal_events('create_ci_runner')
          .with(user: current_user, namespace: group, additional_properties: {
            label: 'group_type',
            property: 'authenticated_user',
            has_token_expiration: 'true'
          })
      end

      context 'with token_rotation_deadline' do
        let(:args) { { token_expires_at: token_expires_at, token_rotation_deadline: 5.minutes.from_now } }

        it 'includes both tracking properties as true' do
          expect { execute }
            .to trigger_internal_events('create_ci_runner')
            .with(user: current_user, namespace: group, additional_properties: {
              label: 'group_type',
              property: 'authenticated_user',
              has_token_expiration: 'true',
              has_rotation_deadline: 'true'
            })
        end
      end
    end
  end

  context 'with :runner_type param set to project_type' do
    let(:current_user) { group_owner }
    let(:params) { { runner_type: 'project_type', scope: project } }
    let(:expected_token_scope) { project }

    it_behaves_like 'a service logging a runner audit event'
    it_behaves_like 'hosted runner not created'

    it 'does not include token expiration tracking properties' do
      expect { execute }
        .to trigger_internal_events('create_ci_runner')
        .with(user: current_user, project: project, additional_properties: {
          label: 'project_type',
          property: 'authenticated_user'
        })
    end

    context 'with hosted_runner param set to true' do
      before do
        params[:hosted_runner] = true
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      it_behaves_like 'hosted runner not created'
    end

    context 'with token_expires_at param', :freeze_time do
      let(:params) { { runner_type: 'project_type', scope: project }.merge(args) }
      let(:args) { {} }

      context 'when token_expires_at is a valid future time' do
        let(:token_expires_at) { 10.minutes.from_now }
        let(:args) { { token_expires_at: token_expires_at } }

        it 'creates a runner with token_expires_at set' do
          expect(execute).to be_success
          expect(runner.explicit_token_expires_at).to eq(token_expires_at)
        end

        it 'includes token expiration tracking properties' do
          expect { execute }
            .to trigger_internal_events('create_ci_runner')
            .with(user: current_user, project: project, additional_properties: {
              label: 'project_type',
              property: 'authenticated_user',
              has_token_expiration: 'true'
            })
        end
      end

      context 'when token_expires_at is less than 5 minutes in the future' do
        let(:token_expires_at) { 4.minutes.from_now }
        let(:args) { { token_expires_at: token_expires_at } }

        it_behaves_like 'a service logging a token expiration validation failure',
          expected_runner_type: 'project_type'

        it 'returns a validation error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:validation_error)
          expect(execute.message).to include('token_expires_at must be at least 5 minutes in the future')
        end
      end

      context 'when token_expires_at is more than 15 days in the future' do
        let(:token_expires_at) { 16.days.from_now }
        let(:args) { { token_expires_at: token_expires_at } }

        it_behaves_like 'a service logging a token expiration validation failure',
          expected_runner_type: 'project_type'

        it 'returns a validation error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:validation_error)
          expect(execute.message).to include('token_expires_at is too far in the future')
        end
      end

      context 'when token_expires_at and token_rotation_deadline are valid' do
        let(:token_expires_at) { 10.minutes.from_now }
        let(:token_rotation_deadline) { 5.minutes.from_now }
        let(:args) { { token_expires_at: token_expires_at, token_rotation_deadline: token_rotation_deadline } }

        it 'creates a runner with rotation set' do
          expect(execute).to be_success
          expect(runner.explicit_token_expires_at).to eq(token_expires_at)
          expect(runner.token_rotation_deadline).to eq(token_rotation_deadline)
        end

        it 'includes both tracking properties as true' do
          expect { execute }
            .to trigger_internal_events('create_ci_runner')
            .with(user: current_user, project: project, additional_properties: {
              label: 'project_type',
              property: 'authenticated_user',
              has_token_expiration: 'true',
              has_rotation_deadline: 'true'
            })
        end
      end

      context 'when token_rotation_deadline is in the past' do
        let(:token_expires_at) { 10.minutes.from_now }
        let(:token_rotation_deadline) { 1.minute.ago }
        let(:args) { { token_expires_at: token_expires_at, token_rotation_deadline: token_rotation_deadline } }

        it_behaves_like 'a service logging a token expiration validation failure',
          expected_runner_type: 'project_type'

        it 'returns a validation error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:validation_error)
          expect(execute.message).to include('token_rotation_deadline cannot be in the past')
        end
      end

      context 'when token_rotation_deadline is after token_expires_at' do
        let(:token_expires_at) { 10.minutes.from_now }
        let(:token_rotation_deadline) { 11.minutes.from_now }
        let(:args) { { token_expires_at: token_expires_at, token_rotation_deadline: token_rotation_deadline } }

        it_behaves_like 'a service logging a token expiration validation failure',
          expected_runner_type: 'project_type'

        it 'returns a validation error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:validation_error)
          expect(execute.message).to include('token_rotation_deadline must be less than or equal to token_expires_at')
        end
      end

      context 'when token_rotation_deadline equals token_expires_at' do
        let(:token_expires_at) { 10.minutes.from_now }
        let(:token_rotation_deadline) { token_expires_at }
        let(:args) { { token_expires_at: token_expires_at, token_rotation_deadline: token_rotation_deadline } }

        it 'creates a runner with a rotation deadline equal to expiry' do
          expect(execute).to be_success
          expect(runner.explicit_token_expires_at).to eq(token_expires_at)
          expect(runner.token_rotation_deadline).to eq(token_rotation_deadline)
        end
      end

      context 'when runner token expiration interval is lower than token_expires_at' do
        let(:token_expires_at) { 2.hours.from_now }
        let(:args) { { token_expires_at: token_expires_at } }

        before do
          project.ci_cd_settings.update!(runner_token_expiration_interval: 3600)
        end

        it 'returns a validation error and logs the failure' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: 'Token expiration validation failed',
              error_message: a_kind_of(String),
              runner_type: 'project_type'
            )
          )

          expect(execute).to be_error
          expect(execute.reason).to eq(:validation_error)
          expect(execute.message).to include('token_expires_at is too far in the future')
        end
      end

      context 'when token_expires_at is not a valid time' do
        let(:args) { { token_expires_at: 'not-a-time' } }

        it_behaves_like 'a service logging a token expiration validation failure',
          expected_runner_type: 'project_type'

        it 'returns a validation error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:validation_error)
          expect(execute.message).to include('token_expires_at must be a valid time')
        end
      end

      context 'when token_rotation_deadline is not a valid time' do
        let(:token_expires_at) { 10.minutes.from_now }
        let(:args) { { token_expires_at: token_expires_at, token_rotation_deadline: 'not-a-time' } }

        it_behaves_like 'a service logging a token expiration validation failure',
          expected_runner_type: 'project_type'

        it 'returns a validation error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:validation_error)
          expect(execute.message).to include('token_rotation_deadline must be a valid time')
        end
      end

      context 'when token_rotation_deadline is provided without token_expires_at' do
        let(:args) { { token_rotation_deadline: 5.minutes.from_now } }

        it_behaves_like 'a service logging a token expiration validation failure',
          expected_runner_type: 'project_type'

        it 'returns a validation error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:validation_error)
          expect(execute.message).to include('token_expires_at is required when token_rotation_deadline is specified')
        end
      end
    end
  end
end
