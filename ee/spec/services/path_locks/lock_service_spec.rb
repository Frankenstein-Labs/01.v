# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PathLocks::LockService, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user) }

  let(:syncing_lfs_lock) { false }
  let(:path) { 'app/models' }

  describe '#execute(path)' do
    subject(:execute) do
      described_class.new(project, current_user, syncing_lfs_lock: syncing_lfs_lock).execute(path)
    end

    context 'when user can push code' do
      before_all do
        project.add_developer(current_user)
      end

      it 'locks path' do
        expect { execute }.to change { project.path_locks.for_paths(path).count }.from(0).to(1)
      end

      it_behaves_like 'refreshes project.path_locks_changed_epoch value'

      describe 'Lfs File Lock integration' do
        let(:lfs_enabled) { true }
        let(:lfs_file_lock_service) { Lfs::LockFileService }

        before do
          allow(project).to receive(:lfs_enabled?).and_return(lfs_enabled)
          allow(lfs_file_lock_service).to receive(:new).and_call_original
        end

        context 'when the file is an lfs file' do
          let(:path) { 'files/lfs/lfs_object.iso' }

          before do
            allow(project.repository).to receive(:root_ref).and_return('lfs')
          end

          it 'creates the Lfs File Lock', :aggregate_failures do
            expect { execute }.to change { LfsFileLock.count }.from(0).to(1)
            expect(lfs_file_lock_service)
              .to have_received(:new)
              .with(project, current_user, syncing_path_lock: true, path: path)
          end

          context 'when lfs is disabled' do
            let(:lfs_enabled) { false }

            it 'does not create an LfsFileLock' do
              expect { execute }.not_to change { LfsFileLock.count }
            end
          end

          context 'when syncing_lfs_lock is true' do
            let(:syncing_lfs_lock) { true }

            it 'does not create an LfsFileLock' do
              expect { execute }.not_to change { LfsFileLock.count }
            end
          end
        end

        context 'when the file is not an lfs file' do
          it 'does not create an LfsFileLock' do
            expect { execute }.not_to change { LfsFileLock.count }
          end
        end
      end
    end

    context 'when user cannot push code' do
      let(:exception) { PathLocks::LockService::AccessDenied }

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
