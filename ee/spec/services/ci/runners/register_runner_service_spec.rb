# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::RegisterRunnerService, '#execute', :freeze_time, feature_category: :fleet_visibility do
  let_it_be_with_reload(:group) { create(:group, :allow_runner_registration_token) }
  let_it_be_with_reload(:project) { create(:project, :allow_runner_registration_token, namespace: group) }

  let(:registration_token) { 'abcdefg123456' }
  let(:token) { nil }
  let(:runner) { execute.payload[:runner] }
  let(:expected_audit_kwargs) do
    {
      name: 'ci_runner_registered',
      message: 'Registered %{runner_type} CI runner',
      token_field: :runner_registration_token
    }
  end

  before do
    stub_application_setting(runners_registration_token: registration_token)
    stub_application_setting(valid_runner_registrars: ApplicationSetting::VALID_RUNNER_REGISTRAR_TYPES)
    stub_application_setting(allow_runner_registration_token: true)
  end

  subject(:execute) { described_class.new(token, {}).execute }

  RSpec::Matchers.define :last_ci_runner do
    match { |runner| runner.is_a?(::Ci::Runner) && runner == ::Ci::Runner.last }
  end

  RSpec::Matchers.define :a_ci_runner_with_errors do
    match { |runner| runner.errors.any? }
  end

  shared_examples 'a service logging a runner registration audit event' do
    it 'returns newly-created runner' do
      expect_next_instance_of(
        ::AuditEvents::RunnerAuditEventService,
        last_ci_runner, token, expected_token_scope, **expected_audit_kwargs
      ) do |service|
        expect(service).to receive(:track_event).once.and_call_original
      end

      expect(execute).to be_success
      expect(runner).not_to be_nil
      expect(runner).to eq(::Ci::Runner.last)
    end
  end

  context 'with a registration token' do
    let(:token) { registration_token }
    let(:expected_token_scope) { an_instance_of(Gitlab::Audit::InstanceScope) }

    it_behaves_like 'a service logging a runner registration audit event'
  end

  context 'when project token is used' do
    let_it_be(:token) { project.runners_token }
    let(:expected_token_scope) { project }

    it_behaves_like 'a service logging a runner registration audit event'
  end

  context 'when group token is used' do
    let_it_be(:token) { group.runners_token }
    let(:expected_token_scope) { group }

    it_behaves_like 'a service logging a runner registration audit event'
  end
end
