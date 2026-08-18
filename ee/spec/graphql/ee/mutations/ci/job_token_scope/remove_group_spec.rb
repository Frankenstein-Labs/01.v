# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::JobTokenScope::RemoveGroup, feature_category: :continuous_integration do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project, ci_outbound_job_token_scope_enabled: true) }
    let_it_be(:project_path) { project.full_path }

    let_it_be(:target_group) { create(:group) }
    let_it_be(:target_group_path) { target_group.full_path }

    let_it_be(:link) do
      create(:ci_job_token_group_scope_link,
        source_project: project,
        target_group: target_group,
        job_token_policies: %w[read_deployments read_packages]
      )
    end

    let_it_be(:current_user) { create(:user, maintainer_of: project, guest_of: target_group) }

    let(:expected_audit_context) do
      {
        name: event_name,
        author: current_user,
        scope: project,
        target: target_group,
        message: expected_audit_message
      }
    end

    let(:mutation_args) do
      {
        project_path: project_path,
        target_group_path: target_group_path
      }
    end

    let(:mutation) do
      described_class.new(object: nil, context: query_context, field: nil)
    end

    subject(:resolver) do
      mutation.resolve(**mutation_args)
    end

    context 'when removing group validate it triggers audits' do
      context 'when user removes target group to the job token scope' do
        let(:expected_audit_message) do
          "Group #{target_group_path} was removed from list of allowed groups for #{project_path}, " \
            "with job token policies: read_deployments, read_packages"
        end

        let(:event_name) { 'secure_ci_job_token_group_removed' }

        it 'logs an audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

          resolver
        end

        context 'when service returns an error' do
          let(:mutation_args) do
            { project_path: project.full_path, target_group_path: target_group_path }
          end

          it 'does not log an audit event' do
            expect_next_instance_of(::Ci::JobTokenScope::RemoveGroupService) do |service|
              expect(service)
                .to receive(:validate_group_remove!)
              .and_raise(::Ci::JobTokenScope::EditScopeValidations::ValidationError)
            end

            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

            resolver
          end
        end
      end
    end
  end
end
