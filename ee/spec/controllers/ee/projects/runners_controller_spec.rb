# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::RunnersController, feature_category: :fleet_visibility do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: user) }
  let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }

  before do
    sign_in(user)
  end

  shared_examples 'controller pushes maintenance note feature' do
    before do
      allow(controller).to receive(:push_licensed_feature)
    end

    it 'enables runner_maintenance_note_for_namespace licensed feature' do
      make_request

      is_expected.to have_received(:push_licensed_feature).with(:runner_maintenance_note_for_namespace, project)
    end
  end

  describe '#new' do
    let(:make_request) do
      get :new, params: { namespace_id: project.namespace, project_id: project }
    end

    it_behaves_like 'controller pushes maintenance note feature'
  end

  describe '#show' do
    let(:make_request) do
      get :show, params: { namespace_id: project.namespace, project_id: project, id: runner }
    end

    it_behaves_like 'controller pushes maintenance note feature'
  end

  describe '#edit' do
    let(:make_request) do
      get :edit, params: { namespace_id: project.namespace, project_id: project, id: runner }
    end

    it_behaves_like 'controller pushes maintenance note feature'
  end
end
