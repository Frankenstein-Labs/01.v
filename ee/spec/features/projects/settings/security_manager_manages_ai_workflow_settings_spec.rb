# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project > Settings > GitLab Duo > AI Workflow Settings', :js,
  feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:security_manager) { create(:user, :with_namespace, security_manager_of: project) }

  before do
    stub_licensed_features(ai_features: true)
    project.project_setting.update!(duo_features_enabled: true)
    sign_in(security_manager)
  end

  it 'lets the security manager enable and save the SAST VR workflow setting' do
    visit edit_project_path(project)

    sast_vr_toggle = find('[data-testid="duo-sast-vr-workflow-enabled"] button')
    expect(sast_vr_toggle['aria-checked']).to eq('false')

    expect(page).not_to have_css('[data-testid="duo_features_enabled_toggle"]')

    sast_vr_toggle.click
    find_by_testid('gitlab-duo-save-button').click

    expect(page).to have_content('was successfully updated')
    expect(project.reload.project_setting.duo_sast_vr_workflow_enabled).to be(true)
  end
end
