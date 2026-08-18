# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:seed:group_seed rake task', :silence_stdout, feature_category: :groups_and_projects do
  let(:username) { 'group_seed' }
  let!(:organization) { create(:organization) }
  let!(:user) { create(:user, username: username, organizations: [organization]) }
  let(:task_params) { [2, username, organization.path] }

  before do
    stub_licensed_features(epics: true)
    Rake.application.rake_require('tasks/gitlab/seed/group_seed')
  end

  subject { run_rake_task('gitlab:seed:group_seed', task_params) }

  it 'performs group seed successfully' do
    # Disable actual import so we don't make HTTP requests
    allow(RepositoryImportWorker).to receive(:perform_async)

    expect { subject }.not_to raise_error

    group = user.groups.first

    expect(group.epics.count).to eq(2)
  end
end
