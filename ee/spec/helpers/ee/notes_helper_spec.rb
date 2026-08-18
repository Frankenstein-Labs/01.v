# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NotesHelper, feature_category: :team_planning do
  let(:vulnerability) { build_stubbed(:vulnerability) }

  describe '#notes_url' do
    context 'for vulnerability' do
      it 'return vulnerability notes path for vulnerability' do
        @vulnerability = vulnerability

        expect(notes_url).to eq("/#{@vulnerability.project.full_path}/-/security/vulnerabilities/#{@vulnerability.id}/notes")
      end
    end
  end

  describe '#discussions_path' do
    subject { discussions_path(issuable) }

    context 'for vulnerability' do
      let(:issuable) { vulnerability }

      it { is_expected.to eq("/#{vulnerability.project.full_path}/-/security/vulnerabilities/#{vulnerability.id}/discussions.json") }
    end
  end

  describe '#notes_data' do
    let(:epic) { build_stubbed(:epic) }

    let(:notes_data) { helper.notes_data(epic) }

    before do
      @group = epic.group
      @noteable = @epic = epic

      allow(helper).to receive(:current_user).and_return(epic.author)
    end

    it 'includes info about the noteable', :aggregate_failures do
      expect(notes_data[:noteableType]).to eq('epic')
      expect(notes_data[:noteableId]).to eq(epic.id)
      expect(notes_data[:projectId]).to be_nil
      expect(notes_data[:groupId]).to eq(epic.group_id)
    end
  end

  describe '#description_diff_path' do
    let(:version) { build_stubbed(:description_version, issue: issuable) }

    subject { description_diff_path(issuable, version.id) }

    context 'when issuable is created at the project level' do
      let(:project) { build_stubbed(:project) }

      context 'when issuable is an Issue' do
        let(:issuable) { build_stubbed(:issue, project: project) }

        it { is_expected.to eq("/#{project.full_path}/-/issues/#{issuable.iid}/descriptions/#{version.id}/diff") }
      end

      context 'when issuable is a WorkItem' do
        let(:issuable) { build_stubbed(:work_item, project: project) }

        it { is_expected.to eq("/#{project.full_path}/-/issues/#{issuable.iid}/descriptions/#{version.id}/diff") }
      end
    end

    context 'when issuable is created at the group level' do
      let(:group) { build_stubbed(:group) }

      context 'when issuable is an Issue' do
        let(:issuable) { build_stubbed(:issue, :group_level, namespace: group) }

        it { is_expected.to eq("/groups/#{group.full_path}/-/work_items/#{issuable.iid}/descriptions/#{version.id}/diff") }
      end

      context 'when issuable is a WorkItem' do
        let(:issuable) { build_stubbed(:work_item, :group_level, namespace: group) }

        it { is_expected.to eq("/groups/#{group.full_path}/-/work_items/#{issuable.iid}/descriptions/#{version.id}/diff") }
      end
    end
  end

  describe '#delete_description_version_path' do
    let(:version) { build_stubbed(:description_version, issue: issuable) }

    subject { delete_description_version_path(issuable, version.id) }

    context 'when issuable is created at the project level' do
      let_it_be(:project) { build_stubbed(:project) }

      context 'when issuable is an Issue' do
        let(:issuable) { build_stubbed(:issue, project: project) }

        it { is_expected.to eq("/#{project.full_path}/-/issues/#{issuable.iid}/descriptions/#{version.id}") }
      end

      context 'when issuable is a WorkItem' do
        let(:issuable) { build_stubbed(:work_item, project: project) }

        it { is_expected.to eq("/#{project.full_path}/-/issues/#{issuable.iid}/descriptions/#{version.id}") }
      end
    end

    context 'when issuable is created at the group level' do
      let_it_be(:group) { build_stubbed(:group) }

      context 'when issuable is an Issue' do
        let(:issuable) { build_stubbed(:issue, :group_level, namespace: group) }

        it { is_expected.to eq("/groups/#{group.full_path}/-/work_items/#{issuable.iid}/descriptions/#{version.id}") }
      end

      context 'when issuable is a WorkItem' do
        let(:issuable) { build_stubbed(:work_item, :group_level, namespace: group) }

        it { is_expected.to eq("/groups/#{group.full_path}/-/work_items/#{issuable.iid}/descriptions/#{version.id}") }
      end
    end
  end
end
