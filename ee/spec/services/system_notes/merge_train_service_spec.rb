# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::MergeTrainService, feature_category: :merge_trains do
  let_it_be(:author) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:project_merge_trains_link) do
    "[merge train](#{Rails.application.routes.url_helpers.project_merge_trains_url(project)})"
  end

  shared_examples 'creates a removed merge train TODO' do
    it 'creates Todo of MERGE_TRAIN_REMOVED' do
      expect { subject }.to change { Todo.count }.to(1)

      todo = Todo.last
      expect(todo.target).to eq(noteable)
      expect(todo.action).to eq(Todo::MERGE_TRAIN_REMOVED)
    end
  end

  describe '#enqueue' do
    subject { described_class.new(noteable: noteable, container: project, author: author).enqueue(noteable.merge_train_car) }

    let(:noteable) { create(:merge_request, :on_train, source_project: project, target_project: project) }

    it_behaves_like 'a system note' do
      let(:action) { 'merge' }
    end

    it "posts the 'merge train' system note" do
      expect(subject.note).to eq("started a #{project_merge_trains_link}")
    end

    context 'when index of the merge request is not zero' do
      before do
        allow(noteable.merge_train_car).to receive(:index).and_return(1)
      end

      it "posts the 'merge train' system note" do
        expect(subject.note).to eq("added this merge request to the #{project_merge_trains_link} at position 2")
      end
    end
  end

  describe '#cancel' do
    subject { described_class.new(noteable: noteable, container: project, author: author).cancel }

    let(:noteable) { create(:merge_request, :on_train, source_project: project, target_project: project) }

    it_behaves_like 'a system note' do
      let(:action) { 'merge' }
    end

    it "posts the 'merge train' system note" do
      expect(subject.note).to eq('removed this merge request from the merge train')
    end
  end

  describe '#abort' do
    subject do
      described_class.new(noteable: noteable, container: project, author: author)
                     .abort('the source branch was updated. ' \
                       '[Learn more](http://localhost/help/ci/pipelines/merge_trains#merge-request-dropped-from-the-merge-train).')
    end

    let(:noteable) { create(:merge_request, :on_train, source_project: project, target_project: project) }

    it_behaves_like 'a system note' do
      let(:action) { 'merge' }
    end

    it "posts the 'merge train' system note" do
      expect(subject.note).to eq(
        'removed this merge request from the merge train because the source branch was updated. ' \
          '[Learn more](http://localhost/help/ci/pipelines/merge_trains#merge-request-dropped-from-the-merge-train).'
      )
    end

    it_behaves_like 'creates a removed merge train TODO'
  end

  describe '#add_when_checks_pass' do
    subject { described_class.new(noteable: noteable, container: project, author: author).add_when_checks_pass(pipeline.sha) }

    let(:pipeline) { build(:ci_pipeline) }

    let(:noteable) do
      create(:merge_request, source_project: project, target_project: project)
    end

    it_behaves_like 'a system note' do
      let(:action) { 'merge' }
    end

    it "posts the 'add to merge train when checks pass' system note" do
      expect(subject.note).to match(%r{enabled automatic add to merge train when checks pass})
    end
  end

  describe '#cancel_add_when_checks_pass' do
    subject { described_class.new(noteable: noteable, container: project, author: author).cancel_add_when_checks_pass }

    let(:noteable) do
      create(:merge_request, source_project: project, target_project: project)
    end

    it_behaves_like 'a system note' do
      let(:action) { 'merge' }
    end

    it "posts the 'add to merge train when checks pass' system note" do
      expect(subject.note).to eq 'cancelled automatic add to merge train'
    end
  end

  describe '#abort_add_when_checks_pass' do
    subject { described_class.new(noteable: noteable, container: project, author: author).abort_add_when_checks_pass('target branch was changed') }

    let(:noteable) do
      create(:merge_request, source_project: project, target_project: project)
    end

    it_behaves_like 'a system note' do
      let(:action) { 'merge' }
    end

    it "posts the 'add to merge train when checks pass' system note" do
      expect(subject.note).to eq 'aborted automatic add to merge train because target branch was changed'
    end

    it_behaves_like 'creates a removed merge train TODO'
  end
end
