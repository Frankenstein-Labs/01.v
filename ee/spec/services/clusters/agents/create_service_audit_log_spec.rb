# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agents::CreateService, feature_category: :deployment_management do
  describe '#execute' do
    let_it_be(:name) { 'some-agent' }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }

    context 'when user is authorized' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when user creates agent' do
        it 'creates AuditEvent with success message' do
          expect_to_audit(
            'cluster_agent_created',
            user,
            project,
            an_object_having_attributes(class: Clusters::Agent, name: 'some-agent'),
            /Created cluster agent 'some-agent' with id \d+/
          )

          described_class.new(project, user, { name: name }).execute
        end
      end
    end

    context 'when user is not authorized' do
      let_it_be(:unauthorized_user) { create(:user) }

      before_all do
        project.add_guest(unauthorized_user)
      end

      context 'when user attempts to create agent' do
        it 'creates audit logs with failure message' do
          expect_to_audit(
            'cluster_agent_create_failed',
            unauthorized_user,
            project,
            project,
            "Attempted to create cluster agent 'some-agent' but failed with message: " \
              'You have insufficient permissions to create a cluster agent for this project'
          )

          described_class.new(project, unauthorized_user, { name: name }).execute
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
