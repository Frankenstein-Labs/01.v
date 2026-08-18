# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Projects::SetLocked, feature_category: :source_code_management do
  include GraphqlHelpers
  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }

  describe '#resolve' do
    subject(:resolve) { mutation.resolve(project_path: project.full_path, file_path: file_path, lock: lock) }

    let(:file_path) { 'README.md' }
    let(:lock) { true }
    let(:mutated_path_locks) { resolve[:project].path_locks }

    it 'raises an error if the resource is not accessible to the user' do
      expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end

    context 'when the user can lock the file' do
      let(:lock) { true }

      before do
        project.add_developer(current_user)
      end

      context 'when file_locks feature is not available' do
        before do
          stub_licensed_features(file_locks: false)
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when file is not locked' do
        it 'sets path locks for the project' do
          expect { resolve }.to change { project.path_locks.count }.from(0).to(1)
          expect(mutated_path_locks.first).to have_attributes(path: file_path, user: current_user)
          expect(resolve[:errors]).to be_empty
        end
      end

      context 'when file is already locked' do
        before do
          create(:path_lock, project: project, path: file_path)
        end

        it 'does not change the lock' do
          expect { resolve }.not_to change { project.path_locks.count }
          expect(mutated_path_locks.first).to have_attributes(path: file_path)
          expect(resolve[:errors]).to be_empty
        end
      end

      context 'when LFS is enabled' do
        let(:file_path) { 'files/lfs/lfs_object.iso' }

        before do
          allow_next_found_instance_of(Project) do |project|
            allow(project).to receive(:lfs_enabled?).and_return(true)
          end
        end

        it 'locks the file in LFS' do
          expect { resolve }.to change { project.lfs_file_locks.count }.by(1)
        end

        context 'when file is not tracked in LFS' do
          let(:file_path) { 'README.md' }

          it 'does not lock the file' do
            expect { resolve }
              .to change { project.path_locks.count }.from(0).to(1)
              .and not_change { project.lfs_file_locks.count }
            expect(mutated_path_locks.first).to have_attributes(path: file_path, user: current_user)
            expect(resolve[:errors]).to be_empty
          end
        end

        context 'when locking a directory' do
          let(:file_path) { 'lfs/' }

          it 'locks the directory' do
            expect { resolve }.to change { project.path_locks.count }.by(1)
          end

          it 'does not locks the directory through LFS' do
            expect { resolve }.not_to change { project.lfs_file_locks.count }
          end
        end
      end
    end

    context 'when the user can unlock the file' do
      let(:lock) { false }

      before do
        project.add_developer(current_user)
      end

      context 'when file is already locked by the same user' do
        before do
          create(:path_lock, project: project, path: file_path, user: current_user)
        end

        it 'unlocks the file' do
          expect { resolve }.to change { project.path_locks.count }.from(1).to(0)
          expect(mutated_path_locks).to be_empty
          expect(resolve[:errors]).to be_empty
        end
      end

      context 'when file is already locked by somebody else' do
        before do
          create(:path_lock, project: project, path: file_path)
        end

        it 'returns an error' do
          expect(resolve[:project]).to be_nil
          expect(resolve[:errors]).to eq(['You have no permissions'])
        end
      end

      context 'when file is not locked' do
        it 'does nothing' do
          expect { resolve }.not_to change { project.path_locks.count }
          expect(mutated_path_locks).to be_empty
          expect(resolve[:errors]).to be_empty
        end
      end

      context 'when LFS is enabled' do
        let(:file_path) { 'files/lfs/lfs_object.iso' }

        before do
          allow_next_found_instance_of(Project) do |project|
            allow(project).to receive(:lfs_enabled?).and_return(true)
          end
        end

        context 'when file is locked' do
          before do
            create(:lfs_file_lock, project: project, path: file_path, user: current_user)
            create(:path_lock, project: project, path: file_path, user: current_user)
          end

          it 'unlocks the file and syncs with lfs', :aggregate_failures do
            expect { resolve }
              .to change { project.path_locks.count }.from(1).to(0)
              .and change { project.lfs_file_locks.count }.from(1).to(0)
          end

          context 'when file is not tracked in LFS' do
            let(:file_path) { 'README.md' }

            it 'unlocks the file but does not sync with lfs' do
              expect { resolve }
                .to change { project.path_locks.count }.from(1).to(0)
                .and not_change { project.lfs_file_locks.count }
            end
          end

          context 'when unlocking a directory' do
            let(:file_path) { 'lfs/' }

            it 'unlocks the directory and does not call the lfs unlock service', :aggregate_failures do
              expect(Lfs::UnlockFileService).not_to receive(:new)

              expect { resolve }.to change { project.path_locks.count }.from(1).to(0)
            end
          end
        end
      end
    end
  end
end
