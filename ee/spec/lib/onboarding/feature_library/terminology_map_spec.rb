# frozen_string_literal: true

require 'fast_spec_helper'

# Validates that every feature_key in the YAML maps to a real Sidebars::MenuItem#item_id
# in the *declared panel* (project or group). It catches entries where a valid id is assigned to the wrong panel
# (e.g. a project-only id declared under panels: [group])
#
# The per-panel id sets are derived from the sidebar menu files for each panel
# (the source of truth). The regex captures both the standard `item_id: :x` form and
# the super-sidebar ternary `is_super_sidebar ? :x` form so ids like :issue_boards and
# :epic_boards (which are only emitted in super-sidebar mode) are correctly included.
RSpec.describe Onboarding::FeatureLibrary::TerminologyMap, feature_category: :onboarding do
  describe 'feature_key panel references' do
    let(:project_item_ids) do
      [
        Rails.root.join("lib/sidebars/projects/**/*.rb"),
        Rails.root.join("ee/lib/sidebars/projects/**/*.rb"),
        Rails.root.join("ee/lib/ee/sidebars/projects/**/*.rb")
      ].flat_map { |glob| Dir.glob(glob) }
        .flat_map { |f| File.read(f).scan(/item_id: :([a-z_]+)|is_super_sidebar \? :([a-z_]+)/).flatten.compact }
        .to_set
    end

    let(:group_item_ids) do
      [
        Rails.root.join("lib/sidebars/groups/**/*.rb"),
        Rails.root.join("ee/lib/sidebars/groups/**/*.rb"),
        Rails.root.join("ee/lib/ee/sidebars/groups/**/*.rb")
      ].flat_map { |glob| Dir.glob(glob) }
        .flat_map { |f| File.read(f).scan(/item_id: :([a-z_]+)|is_super_sidebar \? :([a-z_]+)/).flatten.compact }
        .to_set
    end

    let(:yaml_entries) do
      YAML.safe_load_file(
        Rails.root.join("data/feature_search_terms.yml"), permitted_classes: []
      ) || []
    end

    it 'has no [project] feature_keys that are not real project-panel item_ids' do
      unknown = yaml_entries
        .select { |e| Array(e['panels']).include?('project') }
        .map { |e| e['feature_key'] }
        .to_set - project_item_ids

      expect(unknown).to be_empty,
        "[project] feature_keys not found in project-panel sidebar menus: #{unknown.to_a.inspect}"
    end

    it 'has no [group] feature_keys that are not real group-panel item_ids' do
      unknown = yaml_entries
        .select { |e| Array(e['panels']).include?('group') }
        .map { |e| e['feature_key'] }
        .to_set - group_item_ids

      expect(unknown).to be_empty,
        "[group] feature_keys not found in group-panel sidebar menus: #{unknown.to_a.inspect}"
    end
  end
end
