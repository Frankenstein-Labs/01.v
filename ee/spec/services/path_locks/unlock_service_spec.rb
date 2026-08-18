# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PathLocks::UnlockService, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user) }

  let(:path) { 'app/models' }
  let!(:path_lock) { create(:path_lock, path: path, user: current_user, project: project) }
  let(:syncing_lfs_lock) { false }

  describe '#execute(path_lock)' do
    subject(:execute) do
      described_class.new(project, current_user, syncing_lfs_lock: syncing_lfs_lock).execute(path_lock)
    end

    context 'when the user can admin_path_locks' do
      before_all do
        project.add_developer(current_user)
      end

      it 'unlocks path' do
        expect { execute }.to change { project.path_locks.for_paths(path).count }.from(1).to(0)
      end

      it_behaves_like 'refreshes project.path_locks_changed_epoch value'

      describe 'Lfs File Lock integration' do
        let(:lfs_enabled) { true }
        let(:lfs_file_lock_service) { Lfs::UnlockFileService }

        before do
          allow(project).to receive(:lfs_enabled?).and_return(lfs_enabled)
          allow(lfs_file_lock_service).to receive(:new).and_call_original
          project.lfs_file_locks.create!(path: path, user: current_user)
        end

        context 'when the file is an lfs file' do
          let(:path) { 'files/lfs/lfs_object.iso' }

          before do
            allow(project.repository).to receive(:root_ref).and_return('lfs')
          end

          it 'destroys the Lfs File Lock', :aggregate_failures do
            expect { execute }.to change { LfsFileLock.count }.from(1).to(0)
            expect(lfs_file_lock_service)
              .to have_received(:new)
              .with(project, current_user, force: true, syncing_path_lock: true, path: path)
          end

          context 'when lfs is disabled' do
            let(:lfs_enabled) { false }

            it 'does not destroy the LfsFileLock' do
              expect { execute }.not_to change { LfsFileLock.count }
            end
          end

          context 'when syncing_lfs_lock is true' do
            let(:syncing_lfs_lock) { true }

            it 'does not destroy the LfsFileLock' do
              expect { execute }.not_to change { LfsFileLock.count }
            end
          end
        end

        context 'when the file is not an lfs file' do
          it 'does not destroy the LfsFileLock' do
            expect { execute }.not_to change { LfsFileLock.count }
          end
        end
      end
    end

    context 'when the user cannot unlock the path lock' do
      let(:current_user) { build(:user) }

      let(:exception) { PathLocks::UnlockService::AccessDenied }

      it 'raises exception if user has no permissions' do
        expect { execute }.to raise_exception(exception)
      end

      context 'when the exception has been handled' do
        subject do
          execute
        rescue exception
        end

        it_behaves_like 'does not refresh project.path_locks_changed_epoch'
      end
    end
  end
end
