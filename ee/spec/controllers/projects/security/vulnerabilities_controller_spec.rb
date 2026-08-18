# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::VulnerabilitiesController, feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :small_repo, :public, namespace: group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  render_views

  before do
    stub_licensed_features(security_dashboard: true)
    sign_in(user)
  end

  describe 'GET #new' do
    subject(:request_new_vulnerability_page) do
      get :new, params: { namespace_id: project.namespace, project_id: project }
    end

    it_behaves_like 'security and compliance feature'

    it 'checks if the user can create a vulnerability' do
      allow(controller).to receive(:can?).and_call_original

      request_new_vulnerability_page

      expect(controller).to have_received(:can?).with(controller.current_user, :admin_vulnerability, project)
    end

    context 'when user can admin vulnerability' do
      it 'renders the add new finding page' do
        request_new_vulnerability_page

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when user can not admin vulnerability' do
      it 'renders 404 page not found' do
        sign_in(create(:user))

        request_new_vulnerability_page

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #show' do
    let_it_be(:pipeline) { create(:ci_pipeline, sha: project.commit.id, project: project, user: user) }
    let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }

    subject(:show_vulnerability) { get :show, params: { namespace_id: project.namespace, project_id: project, id: vulnerability.id } }

    it_behaves_like 'security and compliance feature'

    context "when there's an attached pipeline" do
      let_it_be(:finding) { create(:vulnerabilities_finding, :with_pipeline, vulnerability: vulnerability) }

      it 'renders the vulnerability page' do
        show_vulnerability

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
        expect(response.body).to have_text(vulnerability.title)
      end

      it 'renders the vulnerability component' do
        show_vulnerability

        expect(response.body).to have_css("#js-vulnerability-main")
      end

      it_behaves_like 'tracks govern usage event', 'security_vulnerabilities' do
        let(:request) { show_vulnerability }
      end
    end

    context "when there's no attached pipeline" do
      let_it_be(:finding) { create(:vulnerabilities_finding, vulnerability: vulnerability, project: vulnerability.project) }

      it 'renders the vulnerability page' do
        show_vulnerability

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
        expect(response.body).to have_text(vulnerability.title)
      end

      it_behaves_like 'tracks govern usage event', 'security_vulnerabilities' do
        let(:request) { show_vulnerability }
      end
    end

    context 'with policy dismissals' do
      context 'when there are matching policy dismissals' do
        let_it_be(:finding) { create(:vulnerabilities_finding, vulnerability: vulnerability, project: vulnerability.project) }
        let_it_be(:preserved_policy_dismissal) do
          create(:policy_dismissal, project: project, security_findings_uuids: [vulnerability.vulnerability_finding.uuid], status: 1)
        end

        it 'assigns policy dismissals for the vulnerability finding UUID' do
          show_vulnerability

          expect(assigns(:policy_dismissals)).to contain_exactly(preserved_policy_dismissal)
        end

        context 'when there are not preserved dismissals' do
          let_it_be(:open_policy_dismissal) do
            create(:policy_dismissal,
              project: project,
              security_findings_uuids: [vulnerability.vulnerability_finding.uuid], status: 0
            )
          end

          it 'only assigns policy dismissals with preserved status' do
            show_vulnerability

            expect(assigns(:policy_dismissals)).to contain_exactly(preserved_policy_dismissal)
            expect(assigns(:policy_dismissals)).not_to include(open_policy_dismissal)
          end
        end
      end

      context 'when finding_uuid is nil' do
        let_it_be(:finding) { create(:vulnerabilities_finding, vulnerability: vulnerability, project: vulnerability.project) }

        before do
          allow_next_found_instance_of(Vulnerability) do |vuln|
            allow(vuln).to receive(:vulnerability_finding).and_return(nil)
          end
        end

        it 'returns an empty array for policy dismissals' do
          show_vulnerability

          expect(assigns(:policy_dismissals)).to eq([])
        end
      end
    end
  end

  describe 'GET #discussions' do
    let_it_be(:vulnerability) { create(:vulnerability, project: project, author: user) }
    let_it_be(:discussion_note) { create(:discussion_note_on_vulnerability, noteable: vulnerability, project: vulnerability.project) }

    subject(:show_vulnerability_discussion_list) { get :discussions, params: { namespace_id: project.namespace, project_id: project, id: vulnerability } }

    it_behaves_like 'security and compliance feature'

    it 'renders discussions' do
      show_vulnerability_discussion_list

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('entities/discussions')
      expect(json_response.pluck('id')).to eq([discussion_note.discussion_id])
    end
  end
end
