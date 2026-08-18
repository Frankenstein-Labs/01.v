# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ClustersController, feature_category: :deployment_management do
  include AccessMatchersForController

  let_it_be(:project) { create(:project) }

  let(:user) { create(:user, maintainer_of: project) }

  before do
    sign_in(user)
  end

  describe 'GET environments' do
    let(:cluster) { create(:cluster, projects: [project]) }

    before do
      create(:deployment, :success)
    end

    def get_cluster_environments
      get :environments,
        params: {
          namespace_id: project.namespace,
          project_id: project,
          id: cluster
        },
        format: :json
    end

    describe 'functionality' do
      it 'responds successfully' do
        get_cluster_environments

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Poll-Interval']).to eq("5000")
      end
    end

    describe 'security' do
      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect { get_cluster_environments }.to be_allowed_for(:admin) }
      end

      context 'when admin mode is disabled' do
        it { expect { get_cluster_environments }.to be_denied_for(:admin) }
      end

      it { expect { get_cluster_environments }.to be_allowed_for(:owner).of(project) }
      it { expect { get_cluster_environments }.to be_allowed_for(:maintainer).of(project) }
      it { expect { get_cluster_environments }.to be_denied_for(:developer).of(project) }
      it { expect { get_cluster_environments }.to be_denied_for(:reporter).of(project) }
      it { expect { get_cluster_environments }.to be_denied_for(:guest).of(project) }
      it { expect { get_cluster_environments }.to be_denied_for(:user) }
      it { expect { get_cluster_environments }.to be_denied_for(:external) }
    end
  end
end
