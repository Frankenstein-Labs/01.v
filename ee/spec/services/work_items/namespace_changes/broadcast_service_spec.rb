# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::NamespaceChanges::BroadcastService, feature_category: :planning_views do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:guest) { create(:user, guest_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:requirement) { create(:work_item, :requirement, project: project) }

  before do
    allow(GitlabSchema.subscriptions).to receive(:trigger)
  end

  context 'when the work item is a requirement the project does not expose' do
    before do
      stub_licensed_features(requirements: false)
    end

    it 'does not broadcast namespace work item changes', :aggregate_failures do
      expect(Ability.allowed?(guest, :read_work_item, requirement)).to be(false)

      described_class.new(requirement, action: :created).execute
      described_class.new(requirement, action: :updated, updated_changes: %w[title]).execute
      described_class.new(requirement, action: :deleted).execute

      expect(GitlabSchema.subscriptions).not_to have_received(:trigger)
    end
  end

  context 'when the work item is a readable requirement' do
    before do
      stub_licensed_features(requirements: true)
    end

    it 'broadcasts namespace work item changes', :aggregate_failures do
      expect(Ability.allowed?(guest, :read_work_item, requirement)).to be(true)

      described_class.new(requirement, action: :created).execute

      expect(GitlabSchema.subscriptions).to have_received(:trigger).with(
        'namespaceWorkItemChanges',
        { namespace_id: requirement.namespace.to_gid },
        { work_item_id: requirement.id, action: :created }
      )
    end
  end
end
