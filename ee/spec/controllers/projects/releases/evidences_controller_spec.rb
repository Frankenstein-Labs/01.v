# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Releases::EvidencesController, :with_license, feature_category: :release_evidence do
  let_it_be_with_reload(:project) { create(:project, :small_repo, :public) }
  let(:user) { create(:user, :auditor) }

  describe 'GET #show' do
    let(:tag_name) { "v1.1.0-evidence" }
    let(:issue) { create(:issue, project: project) }
    let(:milestone) { create(:milestone, project: project, issues: [issue]) }
    let(:release) { create(:release, project: project, tag: tag_name, milestones: [milestone]) }
    let(:evidence) { release.evidences.first }
    let(:tag) { CGI.escape(release.tag) }

    subject do
      get :show, params: {
        namespace_id: project.namespace.to_param,
        project_id: project,
        tag: tag,
        id: evidence.id,
        format: :json
      }
    end

    before do
      ::Releases::CreateEvidenceService.new(release).execute
      sign_in(user)
    end

    shared_examples_for 'does not show the issue in evidence' do
      it 'does not show the issue in evidence' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['release']['milestones']
          .all? { |milestone| milestone['issues'].nil? }).to be(true)
      end
    end

    context 'when release is associated to a milestone which includes an issue' do
      context 'when user is auditor' do
        it_behaves_like 'does not show the issue in evidence'

        context 'when project is private' do
          let(:project) { create(:project, :small_repo, :private) }

          it_behaves_like 'does not show the issue in evidence'
        end

        context 'when project restricts the visibility of issues to project members only' do
          let(:project) { create(:project, :small_repo, :issues_private) }

          it_behaves_like 'does not show the issue in evidence'
        end
      end
    end
  end
end
