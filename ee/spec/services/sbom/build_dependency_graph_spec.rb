# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::BuildDependencyGraph, :unlimited_max_formatted_output_length, feature_category: :dependency_management do
  matcher :match_path do |ancestor, descendant, project_id, path_length, timestamp, top_level|
    match do |path|
      path.ancestor_id == ancestor \
        && path.descendant_id == descendant \
        && path.project_id == project_id \
        && path.path_length == path_length \
        && path.created_at == timestamp \
        && path.updated_at == timestamp \
        && path.top_level_ancestor == top_level
    end
  end

  describe "base test case" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:descendant) do
      create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
        input_file_path: ancestor.input_file_path, project: project)
    end

    let_it_be(:grandchild) do
      create(:sbom_occurrence,
        ancestors: [
          { name: descendant.component_name, version: descendant.version }
        ],
        input_file_path: descendant.input_file_path, project: project)
    end

    let_it_be(:grandgrandchild) do
      create(:sbom_occurrence, ancestors: [{ name: grandchild.component_name, version: grandchild.version }],
        input_file_path: grandchild.input_file_path, project: project)
    end

    let_it_be(:deep_one) do
      create(:sbom_occurrence, ancestors: [{ name: grandgrandchild.component_name, version: grandgrandchild.version },
        {}], input_file_path: grandgrandchild.input_file_path, project: project)
    end

    let_it_be(:branch_parent) do
      create(:sbom_occurrence,
        ancestors: [
          { name: descendant.component_name, version: descendant.version },
          { name: grandchild.component_name, version: grandchild.version }
        ],
        input_file_path: descendant.input_file_path, project: project)
    end

    let(:expected_cache_key) { Sbom::LatestGraphTimestampCacheKey.new(project: project).cache_key }

    subject(:service) { described_class.new(project) }

    it "builds a dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, descendant.id, project.id, 1, service.timestamp, true),
        match_path(descendant.id, grandchild.id, project.id, 1, service.timestamp, true),
        match_path(descendant.id, branch_parent.id, project.id, 1, service.timestamp, true),
        match_path(grandchild.id, grandgrandchild.id, project.id, 1, service.timestamp, false),
        match_path(grandchild.id, branch_parent.id, project.id, 1, service.timestamp, false),
        match_path(grandgrandchild.id, deep_one.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, grandchild.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, branch_parent.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, grandgrandchild.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, branch_parent.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, deep_one.id, project.id, 4, service.timestamp, true),
        match_path(descendant.id, grandgrandchild.id, project.id, 2, service.timestamp, true),
        match_path(descendant.id, branch_parent.id, project.id, 2, service.timestamp, true),
        match_path(descendant.id, deep_one.id, project.id, 3, service.timestamp, true)
      )
    end

    it "sets the created_at timestamp of all new records to the same timestamp", :freeze_time do
      service.execute
      expect(Sbom::GraphPath.by_projects(project).pluck(:created_at)).to all eq(service.timestamp)
    end

    it "writes latest graph key to cache", :freeze_time do
      now = service.timestamp
      expect(Rails.cache).to receive(:write).with(expected_cache_key, now,
        expires_in: 24.hours).once
      service.execute
    end

    it "invokes the remove job after building the tree" do
      expect(Sbom::RemoveOldDependencyGraphsWorker).to receive(:perform_async).with(project.id)
      service.execute
    end

    it "does not store duplicate graph paths" do
      expect { service.execute }.to change {
        Sbom::GraphPath.by_projects(project).where(ancestor: descendant, descendant: grandchild).count
      }.from(0).to(1)
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 14,
        mode: :exhaustive,
        cache_hit: 0,
        cache_hit_rate: 0.0,
        cache_miss: 9,
        cache_miss_rate: 1
      )
      service.execute
    end
  end

  describe "base test case variant" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:descendant) do
      create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
        input_file_path: ancestor.input_file_path, project: project)
    end

    let_it_be(:descendant2) do
      create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
        input_file_path: ancestor.input_file_path, project: project)
    end

    let_it_be(:grandchild) do
      create(:sbom_occurrence,
        ancestors: [
          { name: descendant.component_name, version: descendant.version }
        ],
        input_file_path: descendant.input_file_path, project: project)
    end

    let_it_be(:grandchild2) do
      create(:sbom_occurrence, ancestors: [{ name: descendant.component_name, version: descendant.version }],
        input_file_path: descendant.input_file_path, project: project)
    end

    let_it_be(:grandchild3) do
      create(:sbom_occurrence, ancestors: [{ name: descendant2.component_name, version: descendant2.version }],
        input_file_path: descendant2.input_file_path, project: project)
    end

    let_it_be(:grandchild4) do
      create(:sbom_occurrence, ancestors: [{ name: descendant2.component_name, version: descendant2.version }],
        input_file_path: descendant2.input_file_path, project: project)
    end

    let_it_be(:deep_one) do
      create(:sbom_occurrence, ancestors: [{ name: grandchild4.component_name, version: grandchild4.version }],
        input_file_path: grandchild4.input_file_path, project: project)
    end

    let(:expected_cache_key) { Sbom::LatestGraphTimestampCacheKey.new(project: project).cache_key }

    subject(:service) { described_class.new(project) }

    it "builds a dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, descendant.id, project.id, 1, service.timestamp, true),
        match_path(ancestor.id, descendant2.id, project.id, 1, service.timestamp, true),
        match_path(descendant.id, grandchild.id, project.id, 1, service.timestamp, true),
        match_path(descendant.id, grandchild2.id, project.id, 1, service.timestamp, true),
        match_path(descendant2.id, grandchild3.id, project.id, 1, service.timestamp, true),
        match_path(descendant2.id, grandchild4.id, project.id, 1, service.timestamp, true),
        match_path(grandchild4.id, deep_one.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, grandchild.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, grandchild2.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, grandchild3.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, grandchild4.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, deep_one.id, project.id, 3, service.timestamp, true),
        match_path(descendant2.id, deep_one.id, project.id, 2, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 13,
        mode: :exhaustive,
        cache_hit: 0,
        cache_hit_rate: 0.0,
        cache_miss: 6,
        cache_miss_rate: 1.0
      )
      service.execute
    end
  end

  describe "cyclic paths" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:cycle_3_sbom_component) { create(:sbom_component) }
    let_it_be(:cycle_3_sbom_component_version) { create(:sbom_component_version, component: cycle_3_sbom_component) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:cycle_1) do
      create(:sbom_occurrence,
        ancestors: [
          { name: ancestor.component_name, version: ancestor.version },
          { name: cycle_3_sbom_component.name, version: cycle_3_sbom_component_version.version }
        ],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:cycle_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: cycle_1.component_name, version: cycle_1.version }],
        input_file_path: cycle_1.input_file_path,
        project: project
      )
    end

    let_it_be(:cycle_3) do
      create(:sbom_occurrence,
        component: cycle_3_sbom_component,
        component_version: cycle_3_sbom_component_version,
        ancestors: [{ name: cycle_2.component_name, version: cycle_2.version }],
        input_file_path: cycle_2.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf) do
      create(:sbom_occurrence,
        ancestors: [{ name: cycle_3.component_name, version: cycle_3.version }],
        input_file_path: cycle_3.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, cycle_1.id, project.id, 1, service.timestamp, true),
        match_path(cycle_1.id, cycle_2.id, project.id, 1, service.timestamp, false),
        match_path(cycle_2.id, cycle_3.id, project.id, 1, service.timestamp, false),
        match_path(cycle_3.id, cycle_1.id, project.id, 1, service.timestamp, false),
        match_path(cycle_3.id, leaf.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, cycle_2.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, cycle_3.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, leaf.id, project.id, 4, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 8,
        mode: :exhaustive,
        cache_hit: 0,
        cache_hit_rate: 0.0,
        cache_miss: 3,
        cache_miss_rate: 1.0
      )
      service.execute
    end
  end

  describe "early branch with a long left branch" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:child) do
      create(:sbom_occurrence,
        ancestors: [{ name: ancestor.component_name, version: ancestor.version }],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:left_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:left_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: left_1.component_name, version: left_1.version }],
        input_file_path: left_1.input_file_path,
        project: project
      )
    end

    let_it_be(:left_3) do
      create(:sbom_occurrence,
        ancestors: [{ name: left_2.component_name, version: left_2.version }],
        input_file_path: left_2.input_file_path,
        project: project
      )
    end

    let_it_be(:right_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:union) do
      create(:sbom_occurrence,
        ancestors: [
          { name: left_3.component_name, version: left_3.version },
          { name: right_1.component_name, version: right_1.version }
        ],
        input_file_path: left_3.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, child.id, project.id, 1, service.timestamp, true),
        match_path(child.id, left_1.id, project.id, 1, service.timestamp, false),
        match_path(child.id, right_1.id, project.id, 1, service.timestamp, false),
        match_path(left_1.id, left_2.id, project.id, 1, service.timestamp, false),
        match_path(left_2.id, left_3.id, project.id, 1, service.timestamp, false),
        match_path(left_3.id, union.id, project.id, 1, service.timestamp, false),
        match_path(right_1.id, union.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_1.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_2.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, left_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, right_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, left_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, left_3.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 5, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 6, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 6, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 19,
        mode: :exhaustive,
        cache_hit: 4,
        cache_hit_rate: 0.3333333333333333,
        cache_miss: 8,
        cache_miss_rate: 0.6666666666666666
      )
      service.execute
    end
  end

  describe "early branch with a long right branch" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:child) do
      create(:sbom_occurrence,
        ancestors: [{ name: ancestor.component_name, version: ancestor.version }],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:left_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:right_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:right_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: right_1.component_name, version: right_1.version }],
        input_file_path: right_1.input_file_path,
        project: project
      )
    end

    let_it_be(:right_3) do
      create(:sbom_occurrence,
        ancestors: [{ name: right_2.component_name, version: right_2.version }],
        input_file_path: right_2.input_file_path,
        project: project
      )
    end

    let_it_be(:union) do
      create(:sbom_occurrence,
        ancestors: [
          { name: left_1.component_name, version: left_1.version },
          { name: right_3.component_name, version: right_3.version }
        ],
        input_file_path: left_1.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, child.id, project.id, 1, service.timestamp, true),
        match_path(child.id, left_1.id, project.id, 1, service.timestamp, false),
        match_path(child.id, right_1.id, project.id, 1, service.timestamp, false),
        match_path(left_1.id, union.id, project.id, 1, service.timestamp, false),
        match_path(right_1.id, right_2.id, project.id, 1, service.timestamp, false),
        match_path(right_2.id, right_3.id, project.id, 1, service.timestamp, false),
        match_path(right_3.id, union.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_1.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_2.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, left_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, right_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, right_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, right_3.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 5, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 6, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 6, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 19,
        mode: :exhaustive,
        cache_hit: 4,
        cache_hit_rate: 0.3333333333333333,
        cache_miss: 8,
        cache_miss_rate: 0.6666666666666666
      )
      service.execute
    end
  end

  describe "equal length branches" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:child) do
      create(:sbom_occurrence,
        ancestors: [{ name: ancestor.component_name, version: ancestor.version }],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:left_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:left_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: left_1.component_name, version: left_1.version }],
        input_file_path: left_1.input_file_path,
        project: project
      )
    end

    let_it_be(:right_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:right_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: right_1.component_name, version: right_1.version }],
        input_file_path: right_1.input_file_path,
        project: project
      )
    end

    let_it_be(:union) do
      create(:sbom_occurrence,
        ancestors: [
          { name: left_2.component_name, version: left_2.version },
          { name: right_2.component_name, version: right_2.version }
        ],
        input_file_path: left_1.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, child.id, project.id, 1, service.timestamp, true),
        match_path(child.id, left_1.id, project.id, 1, service.timestamp, false),
        match_path(child.id, right_1.id, project.id, 1, service.timestamp, false),
        match_path(left_1.id, left_2.id, project.id, 1, service.timestamp, false),
        match_path(left_2.id, union.id, project.id, 1, service.timestamp, false),
        match_path(right_1.id, right_2.id, project.id, 1, service.timestamp, false),
        match_path(right_2.id, union.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_1.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_2.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, left_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, right_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, left_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, right_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 5, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 5, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 16,
        mode: :exhaustive,
        cache_hit: 2,
        cache_hit_rate: 0.2,
        cache_miss: 8,
        cache_miss_rate: 0.8
      )
      service.execute
    end
  end

  describe "'I' shape graph'" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor_left) do
      create(:sbom_occurrence, project: project, input_file_path: 'package.json', ancestors: [{}])
    end

    let_it_be(:ancestor_right) do
      create(:sbom_occurrence, project: project, input_file_path: 'package.json', ancestors: [{}])
    end

    let_it_be(:ancestor_middle) do
      create(:sbom_occurrence,
        project: project,
        ancestors: [
          { name: ancestor_left.component_name, version: ancestor_left.version },
          { name: ancestor_right.component_name, version: ancestor_right.version },
          {}
        ],
        input_file_path: ancestor_left.input_file_path
      )
    end

    let_it_be(:child_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: ancestor_middle.component_name, version: ancestor_middle.version }],
        input_file_path: ancestor_middle.input_file_path,
        project: project
      )
    end

    let_it_be(:child_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: child_1.component_name, version: child_1.version }],
        input_file_path: child_1.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child_2.component_name, version: child_2.version }],
        input_file_path: child_2.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: child_2.component_name, version: child_2.version }],
        input_file_path: child_2.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        # All single paths
        match_path(ancestor_left.id, ancestor_middle.id, project.id, 1, service.timestamp, true),
        match_path(ancestor_right.id, ancestor_middle.id, project.id, 1, service.timestamp, true),
        match_path(ancestor_middle.id, child_1.id, project.id, 1, service.timestamp, true),
        match_path(child_1.id, child_2.id, project.id, 1, service.timestamp, false),
        match_path(child_2.id, leaf_1.id, project.id, 1, service.timestamp, false),
        match_path(child_2.id, leaf_2.id, project.id, 1, service.timestamp, false),
        # ancestor_left paths
        match_path(ancestor_left.id, child_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor_left.id, child_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor_left.id, leaf_1.id, project.id, 4, service.timestamp, true),
        match_path(ancestor_left.id, leaf_2.id, project.id, 4, service.timestamp, true),
        # ancestor_right paths
        match_path(ancestor_right.id, child_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor_right.id, child_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor_right.id, leaf_1.id, project.id, 4, service.timestamp, true),
        match_path(ancestor_right.id, leaf_2.id, project.id, 4, service.timestamp, true),
        # ancestor_middle paths
        match_path(ancestor_middle.id, child_2.id, project.id, 2, service.timestamp, true),
        match_path(ancestor_middle.id, leaf_1.id, project.id, 3, service.timestamp, true),
        match_path(ancestor_middle.id, leaf_2.id, project.id, 3, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 17,
        mode: :exhaustive,
        cache_hit: 3,
        cache_hit_rate: 0.2727272727272727,
        cache_miss: 8,
        cache_miss_rate: 0.7272727272727273
      )
      service.execute
    end
  end

  describe "fast mode (two tops converge then diverge / X-shape)" do
    # X / bowtie shape - two tops fan IN to one shared node, which then fans OUT to two leaves:
    #
    #   top_ancestor_a   top_ancestor_b
    #             \       /
    #              shared
    #              /    \
    #         leaf_1    leaf_2
    #
    # Every (descendant, top) pair has exactly one route here, so there is no redundant route to
    # collapse. This case pins WIDTH preservation: each leaf must resolve to BOTH top_ancestor_a
    # and top_ancestor_b. Collapsing redundant routes to the SAME top must never drop a distinct
    # top-level ancestor. Collapsing multiple routes to a single top is covered by the diamond
    # topology below.

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    let_it_be(:top_ancestor_a) do
      create(:sbom_occurrence, project: project, ancestors: [{}])
    end

    let_it_be(:top_ancestor_b) do
      create(:sbom_occurrence, project: project, ancestors: [{}],
        input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:shared) do
      create(:sbom_occurrence, project: project,
        ancestors: [
          { name: top_ancestor_a.component_name, version: top_ancestor_a.version },
          { name: top_ancestor_b.component_name, version: top_ancestor_b.version }
        ],
        input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: shared.component_name, version: shared.version }],
        input_file_path: shared.input_file_path)
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: shared.component_name, version: shared.version }],
        input_file_path: shared.input_file_path)
    end

    context 'when fast_dependency_paths_enabled is false (default exhaustive mode)' do
      subject(:service) { described_class.new(project) }

      it 'builds paths from both top-level ancestors to each leaf', :freeze_time do
        service.execute

        transitive_paths = Sbom::GraphPath.by_projects(project).where(top_level_ancestor: true)
        # Each leaf is reachable from both top_ancestor_a and top_ancestor_b via shared
        expect(transitive_paths.pluck(:ancestor_id).uniq).to contain_exactly(top_ancestor_a.id, top_ancestor_b.id)
        expect(transitive_paths.count).to be > 2
      end

      it 'logs mode as exhaustive', :freeze_time do
        expect(::Gitlab::AppLogger).to receive(:info).with(hash_including(mode: :exhaustive))
        service.execute
      end
    end

    context 'when fast_dependency_paths_enabled is true' do
      before do
        project.security_setting.update!(fast_dependency_paths_enabled: true)
      end

      subject(:service) { described_class.new(project) }

      it 'records at most one path per (descendant, top-level ancestor) pair', :freeze_time do
        service.execute

        # Fast mode collapses redundant paths to the same top-level ancestor: for any descendant
        # there must be no more than one top-level path to a given ancestor. (The exhaustive build
        # can record several with differing path_length; fast mode keeps one.)
        duplicate_pairs = Sbom::GraphPath.by_projects(project)
          .where(top_level_ancestor: true)
          .group(:descendant_id, :ancestor_id)
          .having('COUNT(*) > 1')
          .count

        expect(duplicate_pairs).to be_empty
      end

      it 'retains every top-level ancestor a descendant is reachable from', :freeze_time do
        service.execute

        # Every node below the fork must keep a path to each top-level ancestor: collapsing
        # redundant paths must not drop a distinct top. This includes the leaves, whose only
        # route to both tops runs through the single shared parent - a traversal that stops
        # exploring siblings after the first top is found loses top_ancestor_b here.
        [shared, leaf_1, leaf_2].each do |descendant|
          reachable_top_ancestor_ids = Sbom::GraphPath.by_projects(project)
            .where(descendant_id: descendant.id, top_level_ancestor: true)
            .pluck(:ancestor_id)

          expect(reachable_top_ancestor_ids).to contain_exactly(top_ancestor_a.id, top_ancestor_b.id),
            "expected #{descendant.component_name} to reach both tops, got ancestor_ids: #{reachable_top_ancestor_ids}"
        end
      end

      it 'produces no more paths than exhaustive mode while keeping the same top-level attribution',
        :freeze_time do
        # In this X-shape every (descendant, top) pair has exactly one route, so there is no
        # redundancy to collapse and fast mode produces the SAME count as exhaustive. Strict
        # reduction is exercised by the diamond topology below, where a redundant longer route
        # actually exists to drop. Here we pin the weaker-but-always-true invariant: fast never
        # exceeds exhaustive, and the set of top-level attributions matches.
        service.execute
        fast_count = Sbom::GraphPath.by_projects(project).count
        fast_top_ancestor_pairs = Sbom::GraphPath.by_projects(project)
          .where(top_level_ancestor: true)
          .pluck(:descendant_id, :ancestor_id)
          .to_set

        Sbom::GraphPath.by_projects(project).delete_all
        project.security_setting.update!(fast_dependency_paths_enabled: false)
        described_class.new(project).execute
        exhaustive_count = Sbom::GraphPath.by_projects(project).count
        exhaustive_top_ancestor_pairs = Sbom::GraphPath.by_projects(project)
          .where(top_level_ancestor: true)
          .pluck(:descendant_id, :ancestor_id)
          .to_set

        expect(fast_count).to be <= exhaustive_count
        expect(fast_top_ancestor_pairs).to eq(exhaustive_top_ancestor_pairs)
      end

      it 'logs mode as fast', :freeze_time do
        expect(::Gitlab::AppLogger).to receive(:info).with(hash_including(mode: :fast))
        service.execute
      end
    end
  end

  describe "fast mode (diamond: two routes of different lengths to the same top)" do
    # Diamond - a single top_ancestor reachable from leaf via both a short and a long route:
    #
    #   top_ancestor
    #      /  \
    #     A    B
    #     |    |
    #     |    C
    #      \  /
    #      leaf
    #
    # leaf -> A -> top_ancestor has length 2; leaf -> B -> C -> top_ancestor has length 3. Fast mode keeps one
    # path per (descendant, top) pair, and the retained path must be the SHORTEST (length 2),
    # not whichever traversal happens to reach first. This pins the min-depth merge behaviour.

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    let_it_be(:top_ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }

    let_it_be(:node_a) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: top_ancestor.component_name, version: top_ancestor.version }],
        input_file_path: top_ancestor.input_file_path)
    end

    let_it_be(:node_b) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: top_ancestor.component_name, version: top_ancestor.version }],
        input_file_path: top_ancestor.input_file_path)
    end

    let_it_be(:node_c) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: node_b.component_name, version: node_b.version }],
        input_file_path: top_ancestor.input_file_path)
    end

    let_it_be(:leaf) do
      create(:sbom_occurrence, project: project,
        ancestors: [
          { name: node_a.component_name, version: node_a.version },
          { name: node_c.component_name, version: node_c.version }
        ],
        input_file_path: top_ancestor.input_file_path)
    end

    before do
      project.security_setting.update!(fast_dependency_paths_enabled: true)
    end

    subject(:service) { described_class.new(project) }

    it 'retains the shortest path to the top, collapsing the longer route', :freeze_time do
      service.execute

      transitive_paths = Sbom::GraphPath.by_projects(project)
        .where(descendant_id: leaf.id, ancestor_id: top_ancestor.id, top_level_ancestor: true)
        .pluck(:path_length)

      expect(transitive_paths).to contain_exactly(2)
    end
  end

  describe "fast mode (descendant reachable via distinct direct parents)" do
    # Two-branch graph, where the descendant's top-level ancestors are reached through
    # *separate* direct parents rather than a shared one:
    #
    #   top_ancestor_a   top_ancestor_b
    #         |                |
    #       mid_a            mid_b
    #          \              /
    #               leaf
    #
    # leaf has two direct parents (mid_a, mid_b), each leading to a different top-level ancestor.
    # Fast mode keeps one path per (descendant, top-level-ancestor) pair, so leaf must resolve to
    # BOTH top_ancestor_a and top_ancestor_b. This graph guards against a traversal that resolves a descendant from
    # only its first direct parent and drops the rest, a regression the X-shape graph (single
    # shared parent) cannot catch.

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    let_it_be(:top_ancestor_a) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:top_ancestor_b) do
      create(:sbom_occurrence, project: project, ancestors: [{}], input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:mid_a) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: top_ancestor_a.component_name, version: top_ancestor_a.version }],
        input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:mid_b) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: top_ancestor_b.component_name, version: top_ancestor_b.version }],
        input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:leaf) do
      create(:sbom_occurrence, project: project,
        ancestors: [
          { name: mid_a.component_name, version: mid_a.version },
          { name: mid_b.component_name, version: mid_b.version }
        ],
        input_file_path: top_ancestor_a.input_file_path)
    end

    before do
      project.security_setting.update!(fast_dependency_paths_enabled: true)
    end

    subject(:service) { described_class.new(project) }

    it 'records a path to every top-level ancestor reachable through a distinct parent', :freeze_time do
      service.execute

      reachable_top_ancestor_ids = Sbom::GraphPath.by_projects(project)
        .where(descendant_id: leaf.id, top_level_ancestor: true)
        .pluck(:ancestor_id)

      expect(reachable_top_ancestor_ids).to contain_exactly(top_ancestor_a.id, top_ancestor_b.id)
    end
  end

  describe "fast mode (shared intermediate with sibling leaves)" do
    # Guards the case where multiple leaves share a single intermediate node that leads
    # to the same top-level ancestor:
    #
    #   top_ancestor
    #         |
    #         M
    #        / \
    #       X   Y
    #
    # In fast mode both X and Y must each resolve to top_ancestor. The fast_visited set is used
    # to skip already-resolved intermediate nodes; it must not include the top-level
    # ancestor itself, otherwise Y's traversal (Y -> M -> top_ancestor) would short-circuit on
    # top_ancestor (after X was processed) and produce no GraphPath row for Y.

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    let_it_be(:top_ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }

    let_it_be(:mid) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: top_ancestor.component_name, version: top_ancestor.version }],
        input_file_path: top_ancestor.input_file_path)
    end

    let_it_be(:leaf_x) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: mid.component_name, version: mid.version }],
        input_file_path: mid.input_file_path)
    end

    let_it_be(:leaf_y) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: mid.component_name, version: mid.version }],
        input_file_path: mid.input_file_path)
    end

    before do
      project.security_setting.update!(fast_dependency_paths_enabled: true)
    end

    subject(:service) { described_class.new(project) }

    it 'records a top-level path for every leaf, not just the first one processed', :freeze_time do
      service.execute

      [leaf_x, leaf_y].each do |leaf|
        reachable_top_ancestor_ids = Sbom::GraphPath.by_projects(project)
          .where(descendant_id: leaf.id, top_level_ancestor: true)
          .pluck(:ancestor_id)

        expect(reachable_top_ancestor_ids).to contain_exactly(top_ancestor.id),
          "expected #{leaf.component_name} to have a top-level path to #{top_ancestor.component_name}"
      end
    end
  end

  describe "fast mode (deep shared intermediate with sibling leaves)" do
    # Same shape as the single-intermediate case but two levels deep:
    #
    #   top_ancestor
    #         |
    #         A
    #         |
    #         B
    #        / \
    #       X   Y
    #
    # The extra depth matters: when X resolves (X -> B -> A -> top_ancestor), any visited-set that marks
    # the intermediate nodes of X's path marks B. Y's traversal starts at its direct edge into B,
    # so a guard keyed on the edge's ancestor short-circuits immediately and Y gets NO top-level
    # path at all. The single-intermediate spec above cannot catch this because there the marked
    # node is only the leaf itself.

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    let_it_be(:top_ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }

    let_it_be(:mid_a) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: top_ancestor.component_name, version: top_ancestor.version }],
        input_file_path: top_ancestor.input_file_path)
    end

    let_it_be(:mid_b) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: mid_a.component_name, version: mid_a.version }],
        input_file_path: top_ancestor.input_file_path)
    end

    let_it_be(:leaf_x) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: mid_b.component_name, version: mid_b.version }],
        input_file_path: top_ancestor.input_file_path)
    end

    let_it_be(:leaf_y) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: mid_b.component_name, version: mid_b.version }],
        input_file_path: top_ancestor.input_file_path)
    end

    before do
      project.security_setting.update!(fast_dependency_paths_enabled: true)
    end

    subject(:service) { described_class.new(project) }

    it 'records a top-level path for every leaf sharing the deep intermediate', :freeze_time do
      service.execute

      [leaf_x, leaf_y].each do |leaf|
        reachable_top_ancestor_ids = Sbom::GraphPath.by_projects(project)
          .where(descendant_id: leaf.id, top_level_ancestor: true)
          .pluck(:ancestor_id)

        expect(reachable_top_ancestor_ids).to contain_exactly(top_ancestor.id),
          "expected #{leaf.component_name} to have a top-level path to #{top_ancestor.component_name}"
      end
    end

    it 'records a top-level path for every intermediate node', :freeze_time do
      service.execute

      [mid_a, mid_b].each do |mid|
        reachable_top_ancestor_ids = Sbom::GraphPath.by_projects(project)
          .where(descendant_id: mid.id, top_level_ancestor: true)
          .pluck(:ancestor_id)

        expect(reachable_top_ancestor_ids).to contain_exactly(top_ancestor.id),
          "expected #{mid.component_name} to have a top-level path to #{top_ancestor.component_name}"
      end
    end
  end

  describe "fast mode (fork above a deep shared intermediate)" do
    # Combines the two failure shapes - a fork that is ABOVE the leaves' direct edges plus
    # sibling leaves sharing a deep intermediate:
    #
    #   top_ancestor_a   top_ancestor_b
    #             \       /
    #              shared
    #                |
    #               mid
    #               / \
    #              X   Y
    #
    # Contract: every node below the fork (shared, mid, X, Y) resolves to BOTH top_ancestor_a and top_ancestor_b,
    # with exactly one path per (descendant, top) pair. This fails under either bug:
    # - short-circuiting sibling edges at the fork drops top_ancestor_b for everything below it
    # - marking mid as visited during X's traversal drops Y entirely

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    let_it_be(:top_ancestor_a) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:top_ancestor_b) do
      create(:sbom_occurrence, project: project, ancestors: [{}], input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:shared) do
      create(:sbom_occurrence, project: project,
        ancestors: [
          { name: top_ancestor_a.component_name, version: top_ancestor_a.version },
          { name: top_ancestor_b.component_name, version: top_ancestor_b.version }
        ],
        input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:mid) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: shared.component_name, version: shared.version }],
        input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:leaf_x) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: mid.component_name, version: mid.version }],
        input_file_path: top_ancestor_a.input_file_path)
    end

    let_it_be(:leaf_y) do
      create(:sbom_occurrence, project: project,
        ancestors: [{ name: mid.component_name, version: mid.version }],
        input_file_path: top_ancestor_a.input_file_path)
    end

    before do
      project.security_setting.update!(fast_dependency_paths_enabled: true)
    end

    subject(:service) { described_class.new(project) }

    it 'resolves every node below the fork to both top-level ancestors', :freeze_time do
      service.execute

      [shared, mid, leaf_x, leaf_y].each do |descendant|
        reachable_top_ancestor_ids = Sbom::GraphPath.by_projects(project)
          .where(descendant_id: descendant.id, top_level_ancestor: true)
          .pluck(:ancestor_id)

        expect(reachable_top_ancestor_ids).to contain_exactly(top_ancestor_a.id, top_ancestor_b.id),
          "expected #{descendant.component_name} to reach both tops, got ancestor_ids: #{reachable_top_ancestor_ids}"
      end
    end

    it 'records exactly one path per (descendant, top-level ancestor) pair', :freeze_time do
      service.execute

      duplicate_pairs = Sbom::GraphPath.by_projects(project)
        .where(top_level_ancestor: true)
        .group(:descendant_id, :ancestor_id)
        .having('COUNT(*) > 1')
        .count

      expect(duplicate_pairs).to be_empty
    end
  end

  describe "fast mode (cyclic paths)" do
    # Same cyclic topology as the exhaustive "cyclic paths" case:
    #
    #   ancestor (top)
    #      |
    #   cycle_1 <-+
    #      |      |
    #   cycle_2   |
    #      |      |
    #   cycle_3 --+
    #      |
    #     leaf
    #
    # Fast mode must terminate despite the cycle and still resolve leaf and every cycle
    # member to the top-level ancestor.

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:cycle_3_sbom_component) { create(:sbom_component) }
    let_it_be(:cycle_3_sbom_component_version) { create(:sbom_component_version, component: cycle_3_sbom_component) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }

    let_it_be(:cycle_1) do
      create(:sbom_occurrence,
        ancestors: [
          { name: ancestor.component_name, version: ancestor.version },
          { name: cycle_3_sbom_component.name, version: cycle_3_sbom_component_version.version }
        ],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:cycle_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: cycle_1.component_name, version: cycle_1.version }],
        input_file_path: cycle_1.input_file_path,
        project: project
      )
    end

    let_it_be(:cycle_3) do
      create(:sbom_occurrence,
        component: cycle_3_sbom_component,
        component_version: cycle_3_sbom_component_version,
        ancestors: [{ name: cycle_2.component_name, version: cycle_2.version }],
        input_file_path: cycle_2.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf) do
      create(:sbom_occurrence,
        ancestors: [{ name: cycle_3.component_name, version: cycle_3.version }],
        input_file_path: cycle_3.input_file_path,
        project: project
      )
    end

    before do
      project.security_setting.update!(fast_dependency_paths_enabled: true)
    end

    subject(:service) { described_class.new(project) }

    it 'terminates and resolves every node in and below the cycle to the top-level ancestor', :freeze_time do
      service.execute

      [cycle_1, cycle_2, cycle_3, leaf].each do |descendant|
        reachable_top_ancestor_ids = Sbom::GraphPath.by_projects(project)
          .where(descendant_id: descendant.id, top_level_ancestor: true)
          .pluck(:ancestor_id)

        expect(reachable_top_ancestor_ids).to contain_exactly(ancestor.id),
          "expected #{descendant.component_name} to resolve to the top-level ancestor"
      end
    end
  end
end
