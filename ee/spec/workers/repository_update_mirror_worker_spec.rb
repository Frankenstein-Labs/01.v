# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RepositoryUpdateMirrorWorker, feature_category: :source_code_management do
  describe '#perform' do
    let(:jid) { '12345678' }
    let!(:project) { create(:project) }
    let!(:import_state) { create(:import_state, :mirror, :scheduled, project: project) }

    subject(:worker) { described_class.new }

    before do
      allow(worker).to receive(:jid).and_return(jid)
    end

    it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

    it 'sets status as finished when update mirror service executes successfully', :prometheus do
      expect_next_instance_of(Projects::UpdateMirrorService) do |instance|
        expect(instance).to receive(:execute).and_return(status: :success)
      end

      allow(Gitlab::AppLogger).to receive(:info).and_call_original
      expect(Gitlab::AppLogger).to receive(:info).with(
        hash_including(message: /successfully finished/, async_branch_creation: false, jid: jid)
      )

      expect { subject.perform(project.id) }.to change { import_state.reload.status }.to('finished')
    end

    it 'observes the mirror update duration metric on success' do
      expect_next_instance_of(Projects::UpdateMirrorService) do |instance|
        expect(instance).to receive(:execute).and_return(status: :success)
      end

      histogram = instance_double(Prometheus::Client::Histogram)
      allow(Gitlab::Metrics).to receive(:histogram).and_call_original
      allow(Gitlab::Metrics).to receive(:histogram)
        .with(:gitlab_repository_mirror_update_duration_seconds, 'Mirror update duration', {}, anything)
        .and_return(histogram)
      expect(histogram).to receive(:observe).with({}, a_value >= 0)

      subject.perform(project.id)
    end

    it 'sets status as started when the mirror service creates branches asynchronously' do
      expect_next_instance_of(Projects::UpdateMirrorService) do |instance|
        expect(instance).to receive(:execute).and_return(status: :success, async: true)
      end

      expect { subject.perform(project.id) }.to change { import_state.reload.status }.to('started')
    end

    it 'sets status as failed when update mirror service executes with errors' do
      allow_next_instance_of(Projects::UpdateMirrorService) do |instance|
        allow(instance).to receive(:execute).and_return(status: :error, message: 'error')
      end

      expect(Gitlab::AppLogger).to receive(:error).with(message: /failed/, jid: jid)
      expect { subject.perform(project.id) }.to raise_error(RepositoryUpdateMirrorWorker::UpdateError, 'error')
      expect(project.reload.import_status).to eq('failed')
    end

    context 'when service returns an GRPC::Core::CallError' do
      it 'fails correctly' do
        allow_next_instance_of(Projects::UpdateMirrorService) do |instance|
          allow(instance).to receive(:execute).and_raise(GRPC::Core::CallError)
        end

        expect { subject.perform(project.id) }.to raise_error(RepositoryUpdateMirrorWorker::UpdateError)
        expect(import_state.reload.status).to eq('failed')
      end
    end

    context 'with association preloading' do
      it 'loads association before the first write operation' do
        project = create(:project, :mirror, :import_started)

        query_count = ActiveRecord::QueryRecorder.new { subject.perform(project.id) }.count
        expect(query_count).to eq 8
      end
    end

    context 'with another worker already running' do
      it 'returns nil' do
        mirror = create(:project, :mirror, :import_started)

        expect(Gitlab::AppLogger).to receive(:info).with(message: /inconsistent state/, jid: jid)
        expect(subject.perform(mirror.id)).to be_nil
      end
    end

    it 'marks mirror as failed when an error occurs' do
      allow_next_instance_of(Projects::UpdateMirrorService) do |instance|
        allow(instance).to receive(:execute).and_raise(RuntimeError)
      end

      expect { subject.perform(project.id) }.to raise_error(RepositoryUpdateMirrorWorker::UpdateError)
      expect(import_state.reload.status).to eq('failed')
    end

    context 'when worker was reset without cleanup' do
      let(:started_project) { create(:project) }
      let(:import_state) { create(:import_state, :mirror, :started, project: started_project, jid: jid) }

      it 'sets status as finished when update mirror service executes successfully' do
        expect_next_instance_of(Projects::UpdateMirrorService) do |instance|
          expect(instance).to receive(:execute).and_return(status: :success)
        end

        expect { subject.perform(started_project.id) }.to change { import_state.reload.status }.to('finished')
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [project.id] }

      before do
        allow_next_instance_of(Projects::UpdateMirrorService) do |instance|
          allow(instance).to receive(:execute).and_return(status: :success)
        end
      end
    end
  end
end
