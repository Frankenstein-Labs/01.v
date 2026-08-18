# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::JobTokenScope::RemoveProject, feature_category: :continuous_integration do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project, ci_outbound_job_token_scope_enabled: true) }
    let_it_be(:project_path) { project.full_path }

    let_it_be(:target_project) { create(:project) }
    let_it_be(:target_project_path) { target_project.full_path }

    let_it_be(:link) do
      create(:ci_job_token_project_scope_link,
        direction: :inbound,
        source_project: project,
        target_project: target_project,
        job_token_policies: %w[read_deployments read_packages]
      )
    end

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
        project_path: project_path,
        target_project_path: target_project_path
      }
    end

    let(:mutation) do
      described_class.new(object: nil, context: query_context, field: nil)
    end

    subject(:resolver) do
      mutation.resolve(**mutation_args)
    end

    context 'when user removes target project to the inbound job token scope' do
      let(:mutation_args) do
        {
          project_path: project_path,
          target_project_path: target_project_path,
          direction: :inbound
        }
      end

      let(:expected_audit_message) do
        "Project #{target_project_path} was removed from inbound list of allowed projects for #{project_path}, " \
          "with job token policies: read_deployments, read_packages"
      end

      let(:event_name) { 'secure_ci_job_token_project_removed' }

      it 'logs an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

        resolver
      end

      context 'when service returns an error' do
        it 'does not log an audit event' do
          expect_next_instance_of(::Ci::JobTokenScope::RemoveProjectService) do |service|
            expect(service)
             .to receive(:validate_group_remove!)
            .and_raise(::Ci::JobTokenScope::EditScopeValidations::ValidationError)
          end

          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          resolver
        end
      end
    end

    context 'when user removes target project from the outbound job token scope' do
      let(:mutation_args) do
        {
          project_path: project_path,
          target_project_path: target_project_path,
          direction: :outbound
        }
      end

      it 'does not log an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        resolver
      end
    end
  end
end
