# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::DependencyPathsResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  let_it_be(:ancestor) { create(:sbom_occurrence, project: project) }
  let_it_be(:descendant) do
    create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
      input_file_path: ancestor.input_file_path, project: project)
  end

  subject(:dependency_paths) { sync(resolve_dependency_paths(args: args)) }

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)

    Sbom::BuildDependencyGraph.execute(project)
  end

  context 'when given a project' do
    let(:project_or_namespace) { project }

    context 'when feature flag is OFF' do
      before do
        stub_feature_flags(dependency_graph_graphql: false)
      end

      let(:args) do
        {
          occurrence: descendant.to_gid
        }
      end

      it { is_expected.to be_nil }
    end

    context 'when feature flag is ON' do
      let(:args) do
        {
          occurrence: descendant.to_gid
        }
      end

      let(:result) do
        {
          paths: [
            { path: [descendant], is_cyclic: false },
            { path: [ancestor, descendant], is_cyclic: false }
          ],
          has_previous_page: false,
          has_next_page: false
        }
      end

      it 'returns dependency path data along with page info' do
        is_expected.to eq result
      end

      context 'with pagination params', :aggregate_failures do
        context 'when fetching with after cursor' do
          let(:args) do
            {
              occurrence: descendant.to_gid,
              after: encode_cursor([descendant].map(&:id)),
              limit: 1
            }
          end

          it "calls dependency paths finder with after cursor parameter" do
            expect(Sbom::PathFinder).to receive(:execute).with(
              descendant,
              after_graph_ids: [descendant.id],
              before_graph_ids: nil,
              limit: 1
            ).and_call_original

            dependency_paths
          end
        end

        context 'when fetching with before cursor' do
          let(:args) do
            {
              occurrence: descendant.to_gid,
              before: encode_cursor([ancestor, descendant].map(&:id)),
              limit: 1
            }
          end

          it "calls dependency paths finder with after cursor parameter" do
            expect(Sbom::PathFinder).to receive(:execute).with(
              descendant,
              before_graph_ids: [ancestor.id, descendant.id],
              after_graph_ids: nil,
              limit: 1
            ).and_call_original

            dependency_paths
          end
        end

        context "with invalid cursor" do
          let(:args) do
            {
              occurrence: descendant.to_gid,
              before: Base64.encode64("invalid cursor").strip,
              limit: 1
            }
          end

          it "returns a GraphQL::ExecutionError" do
            result = dependency_paths

            expect(result).to be_a(GraphQL::ExecutionError)
            expect(result.message).to match(/Invalid cursor format/)
          end
        end

        context "with oversized cursor" do
          let(:args) do
            {
              occurrence: descendant.to_gid,
              after: Base64.encode64("a" * 3000).strip,
              limit: 1
            }
          end

          it "returns a GraphQL::ExecutionError" do
            result = dependency_paths

            expect(result).to be_a(GraphQL::ExecutionError)
            expect(result.message).to match(/cursor too large/)
          end
        end
      end
    end
  end

  private

  def resolve_dependency_paths(args: {})
    resolve(
      described_class,
      obj: project_or_namespace,
      args: args,
      ctx: { current_user: user }
    )
  end

  def encode_cursor(path_ids)
    Base64.encode64(path_ids.to_json).strip
  end
end
