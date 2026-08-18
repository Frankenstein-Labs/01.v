# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/mirrors/_mirror_repos_list', feature_category: :source_code_management do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- rendering the partial requires persisted records and pagination
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository, :mirror) }
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  before do
    stub_licensed_features(repository_mirrors: true)
    project.import_state.update!(status: :finished)
    assign(:project, project)
    assign(:remote_mirrors, project.remote_mirrors.page(1))
    allow(view).to receive_messages(current_user: user, params: { page: '1' })
  end

  it 'renders the Vue mirror table root with pull mirror data without raising', :aggregate_failures do
    expect { render }.not_to raise_error

    element = Capybara.string(rendered).find('#js-mirror-table')

    expect(element['data-pull-mirror']).to be_present
    expect(element['data-repository-mirrors-available']).to eq('true')
  end

  it 'does not render the legacy HAML table when the feature flag is enabled', :aggregate_failures do
    render

    expect(rendered).to have_css('#js-mirror-table')
    expect(rendered).not_to have_css('.table-responsive')
  end

  it 'renders the legacy HAML table when the feature flag is disabled' do
    stub_feature_flags(vue_mirror_table: false)

    render

    expect(rendered).to have_css('.table-responsive')
  end
end
