# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::JobTokenScope::AddGroupOrProject, feature_category: :continuous_integration do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project, ci_outbound_job_token_scope_enabled: true) }
    let_it_be(:project_path) { project.full_path }

    let_it_be(:target_group) { create(:group) }
    let_it_be(:target_group_path) { target_group.full_path }

    let_it_be(:target_project) { create(:project) }
    let_it_be(:target_project_path) { target_project.full_path }

    let_it_be(:policies) { %w[read_deployments read_packages] }

    let_it_be(:current_user) { create(:user) }

    let(:expected_audit_context) do
      {
        name: event_name,
        author: current_user,
        scope: project,
        target: target,
        message: expected_audit_message
      }
    end

    let(:mutation_args) do
      {
        project_path: project.full_path,
        target_path: target.full_path,
        default_permissions: false,
        job_token_policies: policies
      }
    end

    let(:mutation) do
      described_class.new(object: nil, context: query_context, field: nil)
    end

    subject(:resolver) do
      mutation.resolve(**mutation_args)
    end

    context 'when user adds target group to the job token scope' do
      let(:target) { target_group }

      let(:expected_audit_message) do
        "Group #{target_group_path} was added to list of allowed groups for #{project_path}, " \
          "with default permissions: false, job token policies: read_deployments, read_packages"
      end

      let(:event_name) { 'secure_ci_job_token_group_added' }

      before_all do
        project.add_maintainer(current_user)
        target_group.add_guest(current_user)
      end

      it 'logs an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

        resolver
      end

      context 'when service returns an error' do
        it 'does not log an audit event' do
          expect_next_instance_of(::Ci::JobTokenScope::AddGroupService) do |service|
            expect(service)
              .to receive(:validate_source_project_and_target_group_access!)
            .with(project, target_group, current_user)
            .and_raise(ActiveRecord::RecordNotUnique)
          end

          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          resolver
        end
      end
    end

    context 'when user adds target project to the inbound job token scope' do
      let(:target) { target_project }

      let(:expected_audit_message) do
        "Project #{target_project_path} was added to inbound list of allowed projects for #{project_path}, " \
          "with default permissions: false, job token policies: read_deployments, read_packages"
      end

      let(:event_name) { 'secure_ci_job_token_project_added' }

      before_all do
        project.add_maintainer(current_user)
        target_project.add_guest(current_user)
      end

      it 'logs an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

        resolver
      end
    end
  end
end
