# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::PathLocksController, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:user)    { project.first_owner }

  let(:path) { 'files/lfs/lfs_object.iso' }
  let(:lfs_enabled) { true }

  before do
    sign_in(user)

    allow_next_instance_of(Repository) do |instance|
      allow(instance).to receive(:root_ref).and_return('lfs')
    end
    allow_next_found_instance_of(Project) do |project|
      allow(project).to receive(:lfs_enabled?) { lfs_enabled }
    end
  end

  describe 'GET #index' do
    let(:params) { { namespace_id: project.namespace, project_id: project } }

    subject(:get_index) { get :index, params: params }

    it 'displays the lock paths' do
      get_index

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when file locks feature is not licensed' do
      before do
        stub_licensed_features(file_locks: false)
      end

      it 'redirects to the admin subscription page' do
        get_index

        expect(response).to redirect_to(admin_subscription_path)
      end
    end

    context 'when the user does not have access' do
      let(:project) { create(:project, :small_repo, :public, :repository_private) }

      it 'does not allow access' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when page has an invalid value' do
      let(:params) do
        { namespace_id: project.namespace, project_id: project, page: { invalid: :format } }
      end

      it 'ignores an invalid param' do
        get_index

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe 'POST #toggle' do
    subject(:toggle_lock) do
      post(:toggle, params: { namespace_id: project.namespace, project_id: project, path: path })
    end

    context 'when file locks feature is not licensed' do
      before do
        stub_licensed_features(file_locks: false)
      end

      it 'redirects to the admin subscription page' do
        toggle_lock

        expect(response).to redirect_to(admin_subscription_path)
      end
    end

    context 'when LFS is enabled' do
      let(:lfs_enabled) { true }

      context 'when locking a file' do
        it 'locks the file' do
          toggle_lock

          expect(PathLock.count).to eq(1)
          expect(response).to have_gitlab_http_status(:ok)
        end

        it "locks the file in LFS" do
          expect { toggle_lock }.to change { LfsFileLock.count }.to(1)
        end

        it "tries to create the PathLock only once" do
          expect(PathLocks::LockService).to receive(:new).once.and_return(double.as_null_object)

          toggle_lock
        end
      end

      context 'when locking a directory' do
        let(:path) { 'bar/' }

        it 'locks the directory' do
          expect { toggle_lock }.to change { PathLock.count }.to(1)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'does not locks the directory through LFS' do
          expect { toggle_lock }.not_to change { LfsFileLock.count }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when file does not exist' do
        let(:path) { 'unknown-file' }

        it 'locks the file' do
          toggle_lock

          expect(PathLock.count).to eq(1)
          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'does not lock the file in LFS' do
          expect { toggle_lock }.not_to change { LfsFileLock.count }
        end
      end

      context 'when unlocking a file' do
        before do
          create(:path_lock, project: project, path: path, user: user)
          create(:lfs_file_lock, project: project, path: path, user: user)
        end

        it 'unlocks the file' do
          expect { toggle_lock }.to change { PathLock.count }.from(1).to(0)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it "unlocks the file in LFS" do
          expect { toggle_lock }.to change { LfsFileLock.count }.from(1).to(0)
        end
      end

      context 'when unlocking a directory' do
        let(:path) { 'bar/' }

        before do
          create(:path_lock, project: project, path: path, user: user)
        end

        it 'unlocks the directory' do
          expect { toggle_lock }.to change { PathLock.count }.from(1).to(0)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'does not call the LFS unlock service' do
          expect(Lfs::UnlockFileService).not_to receive(:new)

          toggle_lock
        end
      end
    end

    context 'when LFS is not enabled' do
      let(:lfs_enabled) { false }

      it 'locks the file' do
        expect { toggle_lock }.to change { PathLock.count }.to(1)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it "doesn't lock the file in LFS" do
        expect { toggle_lock }.not_to change { LfsFileLock.count }
      end

      it 'unlocks the file' do
        create(:path_lock, project: project, path: path, user: user)

        expect { toggle_lock }.to change { PathLock.count }.to(0)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the user does not have access' do
      let(:project) { create(:project, :small_repo, :public, :repository_private) }
      let(:user) { create(:user) }

      it 'does not allow access' do
        toggle_lock

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:path_lock) { create(:path_lock, project: project, path: path, user: user) }

    subject(:destroy_lock) do
      delete(:destroy, params: { namespace_id: project.namespace, project_id: project, id: path_lock.id })
    end

    context 'when LFS is enabled' do
      let(:lfs_enabled) { true }

      context 'with files' do
        before do
          create(:lfs_file_lock, project: project, path: path, user: user)
        end

        it 'unlocks the file' do
          expect { destroy_lock }.to change { PathLock.count }.from(1).to(0)

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to(project_path_locks_path(project))
        end

        it 'unlocks the file in LFS' do
          expect { destroy_lock }.to change { LfsFileLock.count }.from(1).to(0)
        end
      end

      context 'when unlocking a directory' do
        let(:path) { 'bar/' }

        it 'unlocks the directory' do
          expect { destroy_lock }.to change { PathLock.count }.from(1).to(0)

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to(project_path_locks_path(project))
        end

        it 'does not call the LFS unlock service' do
          expect(Lfs::UnlockFileService).not_to receive(:new)

          destroy_lock
        end
      end
    end

    context 'when LFS is not enabled' do
      let(:lfs_enabled) { false }

      it 'unlocks the file' do
        expect { destroy_lock }.to change { PathLock.count }.from(1).to(0)

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(project_path_locks_path(project))
      end

      it 'does not call the LFS unlock service' do
        expect(Lfs::UnlockFileService).not_to receive(:new)

        destroy_lock
      end
    end

    context 'when the user does not have access' do
      let(:user) { create(:user) }

      it 'does not allow access' do
        destroy_lock

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
