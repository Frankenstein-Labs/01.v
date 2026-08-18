# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::BlobController, feature_category: :source_code_management do
  include ProjectForksHelper
  include FakeBlobHelpers

  let(:project) { create(:project, :public, :repository) }

  shared_examples_for "handling the codeowners interaction" do
    it "redirects to blob" do
      default_params[:file_path] = "docs/EXAMPLE_FILE"

      subject

      expect(flash[:alert]).to be_nil
      expect(response).to be_redirect
    end
  end

  describe 'show' do
    let(:id) { 'master/invalid-path.rb' }
    let(:params) { { namespace_id: project.namespace, project_id: project, id: id } }

    context 'when an exception is raised while parsing URI' do
      before do
        @request.env['HTTP_REFERER'] = "invalid url" # rubocop:disable RSpec/InstanceVariable -- We need to test referer
      end

      it 'does not call ProjectIndexIntegrityWorker' do
        expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_async)
        get(:show, params: params)
      end
    end

    context 'when a valid blob is requested' do
      let(:id) { 'master/README.md' }

      it 'does not call ProjectIndexIntegrityWorker' do
        expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_async)
        get(:show, params: params)
      end
    end

    context 'when a request is not coming from a search page' do
      it 'does not call ProjectIndexIntegrityWorker' do
        expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_async)
        get(:show, params: params)
      end
    end

    context 'when a request is coming from a search page' do
      before do
        @request.env['HTTP_REFERER'] = "#{@request.url}#{search_path}?scope=blobs" # rubocop:disable RSpec/InstanceVariable -- We need to test referer
      end

      it 'calls ProjectIndexIntegrityWorker' do
        expect(::Search::ProjectIndexIntegrityWorker).to receive(:perform_async).with(project.id,
          { force_repair_blobs: true }).once
        get(:show, params: params)
      end

      context 'when project is missing' do
        let(:params) { { namespace_id: project.namespace, project_id: non_existing_record_id, id: id } }

        it 'does not call ProjectIndexIntegrityWorker' do
          expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_async)
          get(:show, params: params)
        end
      end
    end
  end

  describe 'POST create' do
    let(:user) { create(:user) }
    let(:default_params) do
      {
        namespace_id: project.namespace,
        project_id: project,
        id: 'master',
        branch_name: 'master',
        file_name: 'docs/EXAMPLE_FILE',
        content: 'Added changes',
        commit_message: 'Create CHANGELOG'
      }
    end

    before do
      project.add_developer(user)

      sign_in(user)
    end

    it 'redirects to blob' do
      post :create, params: default_params

      expect(response).to be_redirect
    end

    it_behaves_like "handling the codeowners interaction" do
      subject { post :create, params: default_params }

      let(:expected_view) { :new }
    end
  end

  describe 'PUT update' do
    let(:user) { create(:user) }
    let(:default_params) do
      {
        namespace_id: project.namespace,
        project_id: project,
        id: 'master/CHANGELOG',
        branch_name: 'master',
        content: 'Added changes',
        commit_message: 'Update CHANGELOG'
      }
    end

    before do
      project.add_maintainer(user)

      sign_in(user)
    end

    it_behaves_like "handling the codeowners interaction" do
      subject { put :update, params: default_params }

      let(:expected_view) { :edit }
    end
  end
end
