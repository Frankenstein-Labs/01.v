# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lfs::UnlockFileService, feature_category: :source_code_management do
  let(:project)      { create(:project) }
  let(:lock_author)  { create(:user) }
  let!(:lock)        { create(:lfs_file_lock, user: lock_author, project: project) }

  subject { described_class.new(project, current_user, params) }

  describe '#execute' do
    context 'when authorized' do
      before do
        project.add_developer(lock_author)
      end

      describe 'File Locking integration' do
        let(:syncing_path_lock) { false }
        let(:params) { { id: lock.id, syncing_path_lock: syncing_path_lock } }
        let(:current_user) { lock_author }
        let(:file_locks_license) { true }
        let(:path_lock_service) { PathLocks::UnlockService }

        before do
          stub_licensed_features(file_locks: file_locks_license)
          project.path_locks.create!(path: lock.path, user: lock_author)
          allow(path_lock_service).to receive(:new).and_call_original
        end

        context 'when File Locking is available' do
          it 'deletes the Path Lock', :aggregate_failures do
            expect { subject.execute }.to change { PathLock.count }.to(0)
            expect(path_lock_service)
              .to have_received(:new)
              .with(project, lock_author, syncing_lfs_lock: true)
          end

          context 'when the lfs file was not unlocked successfully' do
            before do
              allow(subject).to receive(:unlock_file).and_return({ status: :error })
            end

            it 'does not create a Path Lock' do
              expect { subject.execute }.not_to change { PathLock.count }
            end
          end

          context 'when syncing_path_lock is true' do
            let(:syncing_path_lock) { true }

            it 'does not delete the Path Lock' do
              expect { subject.execute }.not_to change { PathLock.count }
            end
          end
        end

        context 'when File Locking is not available' do
          let(:file_locks_license) { false }

          it 'does not delete the Path Lock' do
            expect { subject.execute }.not_to change { PathLock.count }
          end
        end
      end
    end
  end
end
