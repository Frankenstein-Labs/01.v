# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::CascadeWebBasedCommitSigningEnabledService, type: :service, feature_category: :source_code_management do
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:subgroup) { create(:group, parent: group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be_with_refind(:group2) { create(:group) }
  let_it_be_with_refind(:subgroup2) { create(:group, parent: group2) }
  let_it_be_with_refind(:project2) { create(:project, group: group2) }

  subject(:service) { described_class.new(web_based_commit_signing_enabled) }

  before do
    # Initialize with web_based_commit_signing_enabled
    [subgroup, subgroup2, group, group2].each do |g|
      g.namespace_settings.update!(web_based_commit_signing_enabled: initial_web_based_commit_signing_enabled)
    end
    [project2, project].each do |p|
      p.project_setting.update!(web_based_commit_signing_enabled: initial_web_based_commit_signing_enabled)
    end
  end

  describe '#execute' do
    context 'when web_based_commit_signing_enabled is true' do
      let(:web_based_commit_signing_enabled) { true }
      let(:initial_web_based_commit_signing_enabled) { false }

      it 'updates subgroups and projects for given group to true' do
        expect do
          service.execute(group)
        end.to change {
                 group.namespace_settings.reload.read_attribute(:web_based_commit_signing_enabled)
               }.from(false).to(true)
        .and change {
               subgroup.namespace_settings.reload.read_attribute(:web_based_commit_signing_enabled)
             }.from(false).to(true)
        .and change {
               project.project_setting.reload.read_attribute(:web_based_commit_signing_enabled)
             }.from(false).to(true)
        .and not_change { group2.namespace_settings.reload.read_attribute(:web_based_commit_signing_enabled) }
        .and not_change { subgroup2.namespace_settings.reload.read_attribute(:web_based_commit_signing_enabled) }
        .and not_change { project2.project_setting.reload.read_attribute(:web_based_commit_signing_enabled) }
      end
    end

    context 'when web_based_commit_signing_enabled is false' do
      let(:web_based_commit_signing_enabled) { false }
      let(:initial_web_based_commit_signing_enabled) { true }

      it 'updates subgroups and projects for given group to false' do
        expect do
          service.execute(group)
        end.to change {
                 group.namespace_settings.reload.read_attribute(:web_based_commit_signing_enabled)
               }.from(true).to(false)
        .and change {
               subgroup.namespace_settings.reload.read_attribute(:web_based_commit_signing_enabled)
             }.from(true).to(false)
        .and change {
               project.project_setting.reload.read_attribute(:web_based_commit_signing_enabled)
             }.from(true).to(false)
        .and not_change { group2.namespace_settings.reload.read_attribute(:web_based_commit_signing_enabled) }
        .and not_change { subgroup2.namespace_settings.reload.read_attribute(:web_based_commit_signing_enabled) }
        .and not_change { project2.project_setting.reload.read_attribute(:web_based_commit_signing_enabled) }
      end
    end
  end
end
