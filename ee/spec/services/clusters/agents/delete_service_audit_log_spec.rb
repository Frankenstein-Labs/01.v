# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agents::DeleteService, feature_category: :deployment_management do
  describe '#execute' do
    let_it_be(:agent) { create(:cluster_agent, name: 'some-agent') }

    let(:user) { agent.created_by_user }
    let(:project) { agent.project }

    context 'when user is authorized' do
      before do
        project.add_maintainer(user)
      end

      context 'when user deletes agent' do
        it 'creates AuditEvent with success message' do
          expect_to_audit(
            'cluster_agent_deleted',
            user,
            project,
            agent,
            /Deleted cluster agent 'some-agent' with id \d+/
          )

          described_class.new(container: project, current_user: user, params: { cluster_agent: agent }).execute
        end
      end
    end

    context 'when user is not authorized' do
      let(:unauthorized_user) { create(:user) }

      before do
        project.add_guest(unauthorized_user)
      end

      context 'when user attempts to delete agent' do
        it 'creates audit logs with failure message' do
          expect_to_audit(
            'cluster_agent_delete_failed',
            unauthorized_user,
            project,
            agent,
            "Attempted to delete cluster agent 'some-agent' but failed with message: " \
              'You have insufficient permissions to delete this cluster agent'
          )

          described_class
            .new(container: project, current_user: unauthorized_user, params: { cluster_agent: agent })
            .execute
        end
      end
    end
  end

  def expect_to_audit(event_type, current_user, scope, target, message)
    audit_context = {
      name: event_type,
      author: current_user,
      scope: scope,
      target: target,
      message: message
    }

    expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)
      .and_call_original
  end
end
