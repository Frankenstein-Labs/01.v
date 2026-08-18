# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::Aggregation::EngineResolver, feature_category: :value_stream_management do
  describe '#aggregation_scope' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be(:subgroup) { create(:group, parent: group, organization: organization) }
    let_it_be(:other_group) { create(:group, organization: organization) }
    let_it_be(:project) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project, group: other_group) }
    let_it_be(:user) { create(:user) }

    let(:engine) { double('engine') } # rubocop:disable RSpec/VerifiedDoubles -- engine classes are built dynamically
    let(:resolver_class) do
      Class.new(Resolvers::Analytics::Aggregation::EngineResolver::BaseEngineResolver).tap do |klass|
        klass.engine = engine
        klass.resource_ability = :read_ci_cd_analytics
      end
    end

    let(:query_context) { double.as_null_object }

    subject(:resolver) { resolver_class.new(object: parent, context: query_context, field: nil) }

    before do
      allow(query_context).to receive(:[]).with(:current_user).and_return(user)
      allow(Ability).to receive(:allowed?).with(user, :read_ci_cd_analytics, anything).and_return(true)
      allow(engine).to receive(:prepare_base_aggregation_scope) { |sources| sources }
    end

    context 'with a group parent' do
      let(:parent) { group }

      it 'defaults to the group itself when no sources are requested' do
        expect(resolver.send(:aggregation_scope, {})).to eq([group])
      end

      it 'resolves groups and projects from the group hierarchy' do
        scope = resolver.send(:aggregation_scope,
          { descendants_scope: { group_full_paths: [subgroup.full_path], project_full_paths: [project.full_path] } })

        expect(scope).to contain_exactly(subgroup, project)
      end

      it 'reports sources outside the group hierarchy as inaccessible' do
        expect do
          resolver.send(:aggregation_scope, { descendants_scope: { group_full_paths: [other_group.full_path] } })
        end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, /#{Regexp.escape(other_group.full_path)}/)
      end

      it 'reports projects outside the group hierarchy as inaccessible' do
        expect do
          resolver.send(:aggregation_scope, { descendants_scope: { project_full_paths: [other_project.full_path] } })
        end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, /#{Regexp.escape(other_project.full_path)}/)
      end
    end

    context 'with a project parent' do
      let(:parent) { project }

      it 'always scopes to the project itself' do
        expect(resolver.send(:aggregation_scope, {})).to eq([project])
      end

      it 'rejects source arguments' do
        expect do
          resolver.send(:aggregation_scope, { descendants_scope: { group_full_paths: [group.full_path] } })
        end.to raise_error(Gitlab::Graphql::Errors::ArgumentError,
          'groupFullPaths and projectFullPaths arguments are not supported at project level')
      end
    end

    context 'with an organization parent' do
      let(:parent) { organization }

      it 'requires at least one source' do
        expect do
          resolver.send(:aggregation_scope, {})
        end.to raise_error(Gitlab::Graphql::Errors::ArgumentError,
          /at least one of the groupFullPaths or projectFullPaths/)
      end

      it 'resolves groups and projects across the organization' do
        scope = resolver.send(:aggregation_scope,
          { descendants_scope: { group_full_paths: [group.full_path, other_group.full_path],
                                 project_full_paths: [other_project.full_path] } })

        expect(scope).to contain_exactly(group, other_group, other_project)
      end

      context 'when a group belongs to another organization' do
        let_it_be(:foreign_group) { create(:group, organization: create(:organization)) }

        it 'reports the group as inaccessible' do
          expect do
            resolver.send(:aggregation_scope, { descendants_scope: { group_full_paths: [foreign_group.full_path] } })
          end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, /#{Regexp.escape(foreign_group.full_path)}/)
        end
      end
    end
  end
end
