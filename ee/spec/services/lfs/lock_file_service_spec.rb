# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lfs::LockFileService, feature_category: :source_code_management do
  let(:project)      { create(:project) }
  let(:current_user) { create(:user) }

  subject { described_class.new(project, current_user, params) }

  describe '#execute' do
    context 'when authorized' do
      before do
        project.add_developer(current_user)
      end

      describe 'File Locking integration' do
        let(:syncing_path_lock) { false }
        let(:params) { { path: 'README.md', syncing_path_lock: syncing_path_lock } }
        let(:file_locks_license) { true }
        let(:path_lock_service) { PathLocks::LockService }

        before do
          stub_licensed_features(file_locks: file_locks_license)
          allow(path_lock_service).to receive(:new).and_call_original
        end

        context 'when File Locking is available' do
          it 'creates the Path Lock', :aggregate_failures do
            expect { subject.execute }.to change { PathLock.count }.to(1)
            expect(path_lock_service)
              .to have_received(:new)
              .with(project, current_user, syncing_lfs_lock: true)
          end

          context 'when the lfs file was not locked successfully' do
            before do
              allow(subject).to receive(:create_lock!).and_return({ status: :error })
            end

            it 'does not create a Path Lock' do
              expect { subject.execute }.not_to change { PathLock.count }
            end
          end

          context 'when syncing_path_lock is true' do
            let(:syncing_path_lock) { true }

            it 'does not create a Path Lock' do
              expect { subject.execute }.not_to change { PathLock.count }
            end
          end
        end

        context 'when File Locking is not available' do
          let(:file_locks_license) { false }

          it 'does not create the Path Lock' do
            expect { subject.execute }.not_to change { PathLock.count }
          end
        end
      end
    end
  end
end
