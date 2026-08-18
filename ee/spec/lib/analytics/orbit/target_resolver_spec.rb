# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::Orbit::TargetResolver, feature_category: :knowledge_graph do
  let(:resolver) { Class.new { include Analytics::Orbit::TargetResolver }.new }

  describe '#resolve_graph_status_context' do
    context 'with namespace_id' do
      let_it_be(:group) { create(:group) }

      it 'returns context with group traversal_path' do
        result = resolver.resolve_graph_status_context(namespace_id: group.id)

        expect(result[:target]).to eq(group)
        expect(result[:traversal_path]).to eq(group.traversal_path(with_organization: true))
      end

      it 'returns nil for non-existent namespace' do
        expect(resolver.resolve_graph_status_context(namespace_id: non_existing_record_id)).to be_nil
      end
    end

    context 'with project_id' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group) }

      it 'returns context with project_namespace traversal_path' do
        result = resolver.resolve_graph_status_context(project_id: project.id)

        expect(result[:target]).to eq(project)
        expect(result[:traversal_path]).to eq(project.project_namespace.traversal_path(with_organization: true))
      end

      it 'returns nil for non-existent project' do
        expect(resolver.resolve_graph_status_context(project_id: non_existing_record_id)).to be_nil
      end
    end

    context 'with full_path' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group) }

      it 'resolves group by full_path' do
        result = resolver.resolve_graph_status_context(full_path: group.full_path)

        expect(result[:target]).to eq(group)
        expect(result[:traversal_path]).to eq(group.traversal_path(with_organization: true))
      end

      it 'resolves project by full_path' do
        result = resolver.resolve_graph_status_context(full_path: project.full_path)

        expect(result[:target]).to eq(project)
        expect(result[:traversal_path]).to eq(project.project_namespace.traversal_path(with_organization: true))
      end

      it 'returns nil for non-existent path' do
        expect(resolver.resolve_graph_status_context(full_path: 'does/not/exist')).to be_nil
      end

      context 'when full_path resolves to a user namespace' do
        let_it_be(:user_with_namespace) { create(:user, :with_namespace) }

        it 'returns nil' do
          expect(resolver.resolve_graph_status_context(full_path: user_with_namespace.namespace.full_path)).to be_nil
        end
      end
    end

    context 'with personal namespace' do
      let_it_be(:user_with_namespace) { create(:user, :with_namespace) }

      it 'returns nil for user namespace' do
        expect(resolver.resolve_graph_status_context(namespace_id: user_with_namespace.namespace.id)).to be_nil
      end
    end

    context 'with personal project' do
      let_it_be(:user_with_namespace) { create(:user, :with_namespace) }
      let_it_be(:personal_project) { create(:project, namespace: user_with_namespace.namespace) }

      it 'returns nil for project under user namespace' do
        expect(resolver.resolve_graph_status_context(project_id: personal_project.id)).to be_nil
      end
    end

    context 'with no params' do
      it 'returns nil' do
        expect(resolver.resolve_graph_status_context({})).to be_nil
      end
    end
  end
end
