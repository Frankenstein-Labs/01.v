# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::UnregisterRunnerService, '#execute', feature_category: :runner_core do
  let_it_be(:group) { create(:group) }

  let(:current_user) { nil }
  let(:token) { 'abc123' }
  let(:expected_message) do
    if runner.contacted_at.nil?
      'Unregistered %{runner_type} CI runner, never contacted'
    else
      'Unregistered %{runner_type} CI runner, last contacted %{runner_contacted_at}'
    end
  end

  let(:expected_audit_kwargs) do
    {
      name: 'ci_runner_unregistered',
      message: expected_message,
      runner_contacted_at: runner.contacted_at
    }
  end

  subject(:execute) { described_class.new(runner, current_user || token).execute }

  shared_examples 'a service logging a runner audit event' do
    it 'logs an audit event with the instance scope' do
      expect_next_instance_of(
        ::AuditEvents::RunnerAuditEventService,
        runner, expected_author, expected_token_scope, **expected_audit_kwargs
      ) do |service|
        expect(service).to receive(:track_event).once.and_call_original
      end

      expect(execute).to be_success
    end
  end

  context 'on an instance runner' do
    let(:runner) { create(:ci_runner) }
    let(:expected_author) { token }
    let(:expected_token_scope) { an_instance_of(::Gitlab::Audit::InstanceScope) }

    it_behaves_like 'a service logging a runner audit event'
  end

  context 'on a group runner' do
    let(:runner) { create(:ci_runner, :group, groups: [group]) }
    let(:current_user) { create(:user) }
    let(:expected_author) { current_user }
    let(:expected_token_scope) { group }

    it_behaves_like 'a service logging a runner audit event'
  end

  context 'on a project runner' do
    let(:projects) { create_list(:project, 2, namespace: group) }
    let(:runner) { create(:ci_runner, :project, projects: projects) }

    it 'logs an audit event for each project' do
      projects.each do |project|
        expect_next_instance_of(
          ::AuditEvents::RunnerAuditEventService, runner, token, project, **expected_audit_kwargs
        ) do |service|
          expect(service).to receive(:track_event).once.and_call_original
        end
      end

      execute
    end
  end
end
