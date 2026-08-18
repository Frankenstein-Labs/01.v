# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::PathFinder, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  # In this case we are modeling a dependency graph that looks like this:
  #
  # rubocop:disable Style/AsciiComments -- Model graph
  #                ┌─────┐
  #                │rails│
  #                └─────┘
  #                   │
  #        ┌──────────┴──────────┐
  #        │                     │
  #        ▼                     ▼
  # ┌─────────────┐        ┌────────────┐
  # │active_record│        │active_model│
  # └─────────────┘        └────────────┘
  #        │                      │
  #        └──────────┬───────────┘
  #                   ▼
  #            ┌──────────────┐
  #            │active_support│
  #            └──────────────┘
  #                   │
  #                   ▼
  #             ┌───────────┐
  #             │  tzinfo   │
  #             └───────────┘
  #                   │
  #                   ▼
  #           ┌───────────────┐
  #           │concurrent-ruby│
  #           └───────────────┘
  # rubocop:enable Style/AsciiComments

  # ex: Rails
  let_it_be(:ancestor) { create(:sbom_occurrence, project: project) }

  # ex: ActiveRecord
  let_it_be(:descendant) do
    create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
      input_file_path: ancestor.input_file_path, project: project)
  end

  # ex: ActiveModel
  let_it_be(:other_descendant) do
    create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
      input_file_path: ancestor.input_file_path, project: project)
  end

  # ex: ActiveSupport
  let_it_be(:grandchild) do
    create(:sbom_occurrence, ancestors: [
      { name: descendant.component_name, version: descendant.version },
      { name: other_descendant.component_name, version: other_descendant.version },
      {}
    ], input_file_path: descendant.input_file_path, project: project)
  end

  # ex: tzinfo
  let_it_be(:grandgrandchild) do
    create(:sbom_occurrence, ancestors: [{ name: grandchild.component_name, version: grandchild.version }],
      input_file_path: grandchild.input_file_path, project: project)
  end

  # concurrent-ruby
  let_it_be(:deep_one) do
    create(:sbom_occurrence, ancestors: [{ name: grandgrandchild.component_name, version: grandgrandchild.version },
      {}], input_file_path: grandgrandchild.input_file_path, project: project)
  end

  describe '#execute' do
    before do
      Sbom::BuildDependencyGraph.execute(project)
    end

    context 'when there is a timestamp in cache', :freeze_time do
      let(:timestamp) { DateTime.now }
      let(:expected_cache_key) { Sbom::LatestGraphTimestampCacheKey.new(project: project).cache_key }

      before do
        Rails.cache.write(expected_cache_key, timestamp)
      end

      it 'attempts to reads timestamp from cache' do
        expect(Rails.cache).to receive(:read).with(expected_cache_key).and_return(timestamp)

        described_class.execute(grandgrandchild)
      end
    end

    context 'without pagination (unscoped mode)' do
      it "returns proper paths structure with pagination info" do
        result = described_class.execute(grandgrandchild)

        expect(result).to include(
          paths: match_array([
            {
              path: [ancestor, descendant, grandchild, grandgrandchild],
              is_cyclic: false
            },
            {
              path: [ancestor, other_descendant, grandchild, grandgrandchild],
              is_cyclic: false
            },
            {
              path: [descendant, grandchild, grandgrandchild],
              is_cyclic: false
            },
            {
              path: [other_descendant, grandchild, grandgrandchild],
              is_cyclic: false
            },
            {
              path: [grandchild, grandgrandchild],
              is_cyclic: false
            }
          ]),
          has_previous_page: false,
          has_next_page: false
        )
      end

      context 'for a top level dependency' do
        it "includes a self reference path for top level dependencies" do
          result = described_class.execute(deep_one)

          expect(result).to include(
            paths: match_array([
              {
                path: [deep_one],
                is_cyclic: false
              },
              {
                path: [ancestor, descendant, grandchild, grandgrandchild, deep_one],
                is_cyclic: false
              },
              {
                path: [ancestor, other_descendant, grandchild, grandgrandchild, deep_one],
                is_cyclic: false
              },
              {
                path: [descendant, grandchild, grandgrandchild, deep_one],
                is_cyclic: false
              },
              {
                path: [other_descendant, grandchild, grandgrandchild, deep_one],
                is_cyclic: false
              },
              {
                path: [grandchild, grandgrandchild, deep_one],
                is_cyclic: false
              }
            ]),
            has_previous_page: false,
            has_next_page: false
          )
        end

        it "adds the self reference path to the front of paths for consistent pagination" do
          result = described_class.execute(deep_one, limit: 1)

          expect(result).to include(
            paths: match_array([
              {
                path: [deep_one],
                is_cyclic: false
              }
            ]),
            has_previous_page: false,
            has_next_page: true
          )
        end
      end

      context "for an isolated node" do
        let_it_be(:isolated_node) { create(:sbom_occurrence, project: project, ancestors: []) }

        it "handles returns the node itself" do
          result = described_class.execute(isolated_node)

          expect(result).to include(
            paths: match_array([
              {
                path: [isolated_node],
                is_cyclic: false
              }
            ]),
            has_previous_page: false,
            has_next_page: false
          )
        end
      end
    end

    context 'with pagination' do
      let_it_be(:root_occurrences) do
        create_list(:sbom_occurrence, 5, project: project, input_file_path: ancestor.input_file_path)
      end

      let_it_be(:target_node) do
        ancestor_list = root_occurrences.map do |occurrence|
          { name: occurrence.component_name, version: occurrence.version }
        end
        create(:sbom_occurrence, project: project, ancestors: ancestor_list,
          input_file_path: ancestor.input_file_path)
      end

      let_it_be(:paths_to_target) do
        root_occurrences.map { |occurrence| [occurrence.id, target_node.id] }.sort
      end

      context 'with forward pagination (after mode)', :aggregate_failures do
        it "returns paths after the cursor" do
          cursor_path = paths_to_target[1]

          result = described_class.execute(
            target_node,
            after_graph_ids: cursor_path,
            limit: 2
          )

          expect(result[:has_previous_page]).to be true
          expect(result[:has_next_page]).to be true
          expect(result[:paths].length).to eq 2

          # All returned paths should be lexicographically after cursor
          result[:paths].each do |path_entry|
            path_ids = path_entry[:path].map(&:id)
            expect(path_ids <=> cursor_path).to be > 0
          end
        end

        it "handles has_next_page correctly" do
          result = described_class.execute(
            target_node,
            after_graph_ids: paths_to_target[0],
            limit: 2
          )

          # Should have 4 paths after cursor, limit is 2, so has_next_page should be true
          expect(result[:has_next_page]).to be true
          expect(result[:paths].length).to eq 2
        end

        it "excludes the cursor path itself" do
          cursor_path = paths_to_target[1]

          result = described_class.execute(
            target_node,
            after_graph_ids: cursor_path,
            limit: 10
          )

          result[:paths].each do |path_entry|
            path_ids = path_entry[:path].map(&:id)
            expect(path_ids <=> cursor_path).to be > 0
          end
          path_ids_in_result = result[:paths].map { |p| p[:path].map(&:id) }
          expect(path_ids_in_result).not_to include(cursor_path)
          expect(result[:has_previous_page]).to be true
          expect(result[:has_next_page]).to be false
          expect(result[:paths].length).to eq 3
        end
      end

      context 'with backward pagination (before mode)', :aggregate_failures do
        it "returns paths before the cursor" do
          cursor_path = paths_to_target[3]

          result = described_class.execute(
            target_node,
            before_graph_ids: cursor_path,
            limit: 2
          )

          expect(result[:has_previous_page]).to be true
          expect(result[:has_next_page]).to be true
          expect(result[:paths].length).to eq 2

          # All returned paths should be lexicographically before cursor
          result[:paths].each do |path_entry|
            path_ids = path_entry[:path].map(&:id)
            expect(path_ids <=> cursor_path).to be < 0
          end
        end

        it "handles has_previous_page correctly" do
          # We have 5 paths total, get paths before the 4th one
          result = described_class.execute(
            target_node,
            before_graph_ids: paths_to_target[3],
            limit: 2
          )

          # Should have 3 paths before cursor, limit is 2, so has_previous_page should be true
          expect(result[:has_previous_page]).to be true
          expect(result[:paths].length).to eq 2
        end

        it "excludes the cursor path itself" do
          cursor_path = paths_to_target[1]

          result = described_class.execute(
            target_node,
            before_graph_ids: cursor_path,
            limit: 10
          )

          result[:paths].each do |path_entry|
            path_ids = path_entry[:path].map(&:id)
            expect(path_ids <=> cursor_path).to be < 0
          end
          path_ids_in_result = result[:paths].map { |p| p[:path].map(&:id) }
          expect(path_ids_in_result).not_to include(cursor_path)
          expect(result[:has_previous_page]).to be false
          expect(result[:has_next_page]).to be true
          expect(result[:paths].length).to eq 1
        end
      end
    end

    context 'with cycles' do
      let_it_be_with_reload(:cyclic_component_1) do
        create(:sbom_occurrence, input_file_path: ancestor.input_file_path, project: project)
      end

      let_it_be(:cyclic_component_2) do
        create(:sbom_occurrence,
          ancestors: [{ name: cyclic_component_1.component_name, version: cyclic_component_1.version }],
          input_file_path: ancestor.input_file_path, project: project)
      end

      let_it_be(:deep_component) do
        create(:sbom_occurrence,
          ancestors: [{ name: cyclic_component_2.component_name, version: cyclic_component_2.version }],
          input_file_path: ancestor.input_file_path, project: project)
      end

      before do
        cyclic_component_1.update!(
          ancestors: [
            { name: cyclic_component_2.component_name, version: cyclic_component_2.version },
            { name: ancestor.component_name, version: ancestor.version }
          ]
        )

        Sbom::BuildDependencyGraph.execute(project)
      end

      it 'detects cycles and includes them in results' do
        result = described_class.execute(deep_component)

        expect(result).to include(
          paths: match_array([
            {
              path: [ancestor, cyclic_component_1, cyclic_component_2, deep_component],
              is_cyclic: false
            },
            {
              path: [cyclic_component_2, cyclic_component_1, cyclic_component_2, deep_component],
              is_cyclic: true # Verify cycle detection
            }
          ]),
          has_previous_page: false,
          has_next_page: false
        )
      end
    end

    context 'with deterministic ordering' do
      it 'returns paths in consistent order across multiple calls with multiple ingestions' do
        result1 = described_class.execute(deep_one)
        Sbom::BuildDependencyGraph.execute(project)
        result2 = described_class.execute(deep_one)

        expect(result1[:paths].map { |p| p[:path].map(&:id) }).to eq(
          result2[:paths].map { |p| p[:path].map(&:id) }
        )
      end
    end

    context 'with pagination flow', :aggregate_failures do
      let_it_be(:root_occurrences) do
        create_list(:sbom_occurrence, 7, project: project, input_file_path: ancestor.input_file_path)
      end

      let_it_be(:pagination_target) do
        ancestor_list = root_occurrences.map do |occurrence|
          { name: occurrence.component_name, version: occurrence.version }
        end
        create(:sbom_occurrence, project: project, ancestors: ancestor_list,
          input_file_path: ancestor.input_file_path)
      end

      it 'supports navigating forward and backward through pages' do
        # Get first page
        page1 = described_class.execute(pagination_target, limit: 2)
        expect(page1[:has_previous_page]).to be false
        expect(page1[:has_next_page]).to be true
        expect(page1[:paths].length).to eq 2

        # Get second page using last path from page 1
        last_path_page1 = page1[:paths].last[:path].map(&:id)
        page2 = described_class.execute(pagination_target, after_graph_ids: last_path_page1, limit: 2)
        expect(page2[:has_previous_page]).to be true
        expect(page2[:has_next_page]).to be true
        expect(page2[:paths].length).to eq 2

        # Get third page using last path from page 2
        last_path_page2 = page2[:paths].last[:path].map(&:id)
        page3 = described_class.execute(pagination_target, after_graph_ids: last_path_page2, limit: 2)
        expect(page3[:has_previous_page]).to be true
        expect(page3[:has_next_page]).to be true
        expect(page3[:paths].length).to eq 2

        # Get fourth page using last path from page 3
        last_path_page3 = page3[:paths].last[:path].map(&:id)
        page4 = described_class.execute(pagination_target, after_graph_ids: last_path_page3, limit: 2)
        expect(page4[:has_previous_page]).to be true
        expect(page4[:has_next_page]).to be false
        expect(page4[:paths].length).to eq 1

        # Go back to get paths before page 2's first path
        first_path_page2 = page2[:paths].first[:path].map(&:id)
        back_page = described_class.execute(pagination_target, before_graph_ids: first_path_page2, limit: 2)
        expect(back_page[:has_previous_page]).to be false
        expect(back_page[:has_next_page]).to be true
        expect(back_page[:paths].length).to eq 2

        # The last path of back_page should be just before first path of page2
        back_page_paths = back_page[:paths].map { |p| p[:path].map(&:id) }
        page2_paths = page2[:paths].map { |p| p[:path].map(&:id) }
        expect(back_page_paths.last <=> page2_paths.first).to be < 0
      end
    end

    describe 'edge cases' do
      let_it_be(:root_occurrences) do
        create_list(:sbom_occurrence, 2, project: project, input_file_path: ancestor.input_file_path)
      end

      let_it_be(:target_occurrence) do
        ancestor_list = root_occurrences.map do |occurrence|
          { name: occurrence.component_name, version: occurrence.version }
        end
        create(:sbom_occurrence, project: project, ancestors: ancestor_list,
          input_file_path: ancestor.input_file_path)
      end

      it 'handles empty after_graph_ids' do
        result = described_class.execute(descendant, after_graph_ids: [])

        expect(result[:has_previous_page]).to be false
      end

      it 'handles empty before_graph_ids' do
        result = described_class.execute(descendant, before_graph_ids: [])

        expect(result[:has_next_page]).to be false
      end

      it 'returns empty paths for after pagination beyond last path', :aggregate_failures do
        # Get all paths first
        all_paths = described_class.execute(target_occurrence)[:paths]
        last_path_ids = all_paths.last[:path].map(&:id)

        # Try to get paths after the last one
        result = described_class.execute(
          target_occurrence,
          after_graph_ids: last_path_ids
        )

        expect(result[:paths]).to be_empty
        expect(result[:has_previous_page]).to be true
        expect(result[:has_next_page]).to be false
      end

      it 'returns empty paths for before pagination before first path', :aggregate_failures do
        # Get all paths first
        all_paths = described_class.execute(target_occurrence)[:paths]
        first_path_ids = all_paths.first[:path].map(&:id)

        # Try to get paths before the first one
        result = described_class.execute(
          target_occurrence,
          before_graph_ids: first_path_ids
        )

        expect(result[:paths]).to be_empty
        expect(result[:has_previous_page]).to be false
        expect(result[:has_next_page]).to be true
      end
    end

    describe "metric collection" do
      it 'records execution time metrics' do
        expect(Gitlab::Metrics).to receive(:measure)
              .with(:find_dependency_paths)
              .and_call_original

        described_class.execute(deep_one)
      end

      it 'records metrics on paths' do
        counter_double = instance_double(Prometheus::Client::Counter)
        expect(Gitlab::Metrics).to receive(:counter)
          .with(
            :gitlab_dependency_paths_found_total,
            'Counts the number of ancestor dependency paths found for a given dependency.'
          )
          .and_return(counter_double)

        expect(counter_double).to receive(:increment)
          .with({ cyclic: false }, 6)
        expect(counter_double).to receive(:increment)
          .with({ cyclic: true }, 0)

        described_class.execute(deep_one)
      end
    end
  end
end
