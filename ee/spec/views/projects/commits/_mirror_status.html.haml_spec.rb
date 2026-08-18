# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/commits/_mirror_status.html.haml', feature_category: :source_code_management do
  include ApplicationHelper

  let_it_be(:project) { create(:project, :mirror) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needs persisted associations
  let(:developer) { create(:user, developer_of: project.team) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needs persisted associations
  let(:reporter) { create(:user, reporter_of: project.team) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needs persisted associations

  before do
    @project = project
    sign_in(project.first_owner)
  end

  it 'renders a notification if the last update succeeded' do
    allow(project).to receive(:mirror_last_update_succeeded?).and_return(true)
    allow(project.import_state).to receive(:last_successful_update_at) { Time.now }

    render 'projects/commits/mirror_status'

    expect(rendered).to have_content('Successfully updated')
  end

  it 'renders no notification if the last update did not succeed' do
    allow(project).to receive(:mirror_last_update_succeeded?).and_return(false)

    render 'projects/commits/mirror_status'

    expect(rendered).not_to have_content('Successfully updated')
  end

  it "renders mirror info if the user can push code" do
    sign_in(developer)

    render 'projects/commits/mirror_status'

    expect(rendered).to have_content('This project is mirrored from')
    expect(rendered).not_to eq('')
  end

  it "does not render mirror info if the user can't push code" do
    sign_in(reporter)

    render 'projects/commits/mirror_status'

    expect(rendered).not_to have_content('This project is mirrored from')
  end
end
