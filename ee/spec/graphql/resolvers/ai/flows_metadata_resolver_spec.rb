# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::FlowsMetadataResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: create(:group)) }

  before_all do
    namespace.add_developer(user)
    project.add_developer(user)
  end

  describe '#resolve' do
    subject(:capabilities) { result.capabilities }

    it 'delegates capability computation to Ai::FlowsMetadataService' do
      expect_next_instance_of(
        ::Ai::FlowsMetadataService, current_user: user, namespace: nil, project: nil
      ) do |service|
        expect(service).to receive(:execute).and_return([{ name: 'job_trace_pagination', metadata: nil }])
      end

      result = resolve(described_class, ctx: { current_user: user })

      expect(result.capabilities).to eq([{ name: 'job_trace_pagination', metadata: nil }])
    end

    context 'when neither namespace_id nor project_id is provided' do
      let(:result) { resolve(described_class, ctx: { current_user: user }) }

      it 'does not set a group or project boundary' do
        expect(result.group).to be_nil
        expect(result.project).to be_nil
      end
    end

    context 'when namespace_id is provided' do
      let(:result) do
        resolve(described_class, args: { namespace_id: namespace.to_global_id }, ctx: { current_user: user })
      end

      it 'sets the namespace as the group boundary' do
        expect(result.group).to eq(namespace)
      end

      it 'does not set a project boundary' do
        expect(result.project).to be_nil
      end

      it 'passes the namespace to the service' do
        expect_next_instance_of(
          ::Ai::FlowsMetadataService, current_user: user, namespace: namespace, project: nil
        ) do |service|
          expect(service).to receive(:execute).and_return([])
        end

        result.capabilities
      end

      context 'when namespace_id refers to a personal namespace' do
        let_it_be(:user_with_namespace) { create(:user, :with_namespace) }

        let(:result) do
          resolve(described_class, args: { namespace_id: user_with_namespace.namespace.to_global_id },
            ctx: { current_user: user_with_namespace })
        end

        it 'does not set a group or project boundary (falls back to instance-wide)' do
          expect(result.group).to be_nil
          expect(result.project).to be_nil
        end
      end

      context 'when the user cannot read the namespace' do
        let_it_be(:other_namespace) { create(:group, :private) }

        let(:result) do
          resolve(described_class, args: { namespace_id: other_namespace.to_global_id }, ctx: { current_user: user })
        end

        it 'returns a resource not available error' do
          expect(result).to be_a(::Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when project_id is provided' do
      let(:result) do
        resolve(described_class, args: { project_id: project.to_global_id }, ctx: { current_user: user })
      end

      it 'does not set a group boundary' do
        expect(result.group).to be_nil
      end

      it 'sets the project as the project boundary' do
        expect(result.project).to eq(project)
      end

      it 'passes the resolved project to the service' do
        expect_next_instance_of(
          ::Ai::FlowsMetadataService, current_user: user, namespace: nil, project: project
        ) do |service|
          expect(service).to receive(:execute).and_return([])
        end

        result.capabilities
      end

      context 'when the user cannot read the project' do
        let_it_be(:other_project) { create(:project, :private) }

        let(:result) do
          resolve(described_class, args: { project_id: other_project.to_global_id }, ctx: { current_user: user })
        end

        it 'returns a resource not available error' do
          expect(result).to be_a(::Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when both namespace_id and project_id are provided' do
      let(:result) do
        resolve(described_class, args: { namespace_id: namespace.to_global_id, project_id: project.to_global_id },
          ctx: { current_user: user })
      end

      it 'passes both the namespace and the project to the service' do
        expect_next_instance_of(
          ::Ai::FlowsMetadataService, current_user: user, namespace: namespace, project: project
        ) do |service|
          expect(service).to receive(:execute).and_return([])
        end

        result.capabilities
      end
    end
  end
end
