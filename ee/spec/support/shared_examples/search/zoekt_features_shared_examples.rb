# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'zoekt feature' do |feature: nil|
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be_with_reload(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group) }

  describe '.feature_available?' do
    using RSpec::Parameterized::TableSyntax

    let(:min_version) { described_class.minimum_schema_version }
    let(:insufficient_version) { min_version - 1 }
    let(:a_user) { build(:user) }
    let(:scope) { ::Search::Zoekt::Repository }

    before do
      Rails.cache.clear
      allow(::Namespace).to receive(:find_by).with(id: group_id).and_return(group)
      allow(::Search::Zoekt::EnabledNamespace).to receive(:for_root_namespace_id)
        .with(group.root_ancestor.id).and_return([enabled_namespace])
      allow(::Search::Zoekt::Repository).to receive(:for_zoekt_indices).and_return(scope)
      allow(::Search::Zoekt::Repository).to receive(:for_project_id).with(project_id).and_return(scope)

      allow(scope).to receive(:minimum_schema_version).and_return(returned_min_version)

      feature_class = "Search::Zoekt::Features::#{feature.to_s.camelize}".safe_constantize
      allow_next_instance_of(feature_class) do |instance|
        allow(instance).to receive(:preflight_checks_passed?).and_return(feature_enabled)
      end
    end

    subject(:availability) do
      ::Search::Zoekt.feature_available?(feature, user, project_id: project_id, group_id: group_id)
    end

    where(:user, :feature_enabled, :project_id, :group_id, :returned_min_version, :expected_result) do
      # Feature disabled cases (should always be false)
      ref(:a_user)         | false  | 8675  | 309   | ref(:min_version)           | false
      ref(:a_user)         | false  | 8675  | 309   | ref(:insufficient_version)  | false
      ref(:a_user)         | false  | 8675  | nil   | ref(:min_version)           | false
      ref(:a_user)         | false  | nil   | 309   | ref(:min_version)           | false

      # Feature enabled cases
      # Project search
      ref(:a_user)         | true   | 8675  | nil   | ref(:min_version)           | true
      ref(:a_user)         | true   | 8675  | nil   | ref(:insufficient_version)  | false

      # Group search
      ref(:a_user)         | true   | nil   | 309   | ref(:min_version)           | true
      ref(:a_user)         | true   | nil   | 309   | ref(:insufficient_version)  | false

      # Global search
      ref(:a_user)         | true   | nil   | nil   | ref(:min_version)           | true
      ref(:a_user)         | true   | nil   | nil   | ref(:insufficient_version)  | false
    end

    with_them do
      it { is_expected.to eq(expected_result) }
    end
  end
end
