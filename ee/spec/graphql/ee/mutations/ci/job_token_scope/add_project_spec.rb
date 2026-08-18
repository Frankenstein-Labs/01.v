# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::JobTokenScope::AddProject, feature_category: :continuous_integration do
  include GraphqlHelpers

  let(:mutation) do
    described_class.new(object: nil, context: query_context, field: nil)
  end

  describe '#resolve' do
    let_it_be(:project) { create(:project, ci_outbound_job_token_scope_enabled: true) }
    let_it_be(:project_path) { project.full_path }

    let_it_be(:target_project) { create(:project) }
    let_it_be(:target_project_path) { target_project.full_path }

    let_it_be(:policies) { %w[read_deployments read_packages] }

    let_it_be(:current_user) { create(:user, maintainer_of: project, guest_of: target_project) }

    let(:expected_audit_context) do
      {
        name: event_name,
        author: current_user,
        scope: project,
        target: target_project,
        message: expected_audit_message
      }
    end

    let(:mutation_args) do
      {
        project_path: project.full_path,
        target_project_path: target_project_path,
        direction: :inbound
      }
    end

    subject(:resolver) do
      mutation.resolve(**mutation_args)
    end

    context 'when user adds target project to the inbound job token scope' do
      let(:expected_audit_message) do
        "Project #{target_project_path} was added to inbound list of allowed projects for #{project_path}"
      end

      let(:event_name) { 'secure_ci_job_token_project_added' }

      it 'logs an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

        subject
      end

      context 'and service returns an error' do
        it 'does not log an audit event' do
          expect_next_instance_of(::Ci::JobTokenScope::AddProjectService) do |service|
            expect(service)
              .to receive(:validate_source_project_and_target_project_access!)
            .with(project, target_project, current_user)
            .and_raise(ActiveRecord::RecordNotUnique)
          end

          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          subject
        end
      end
    end
  end
end
