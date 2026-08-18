# frozen_string_literal: true

RSpec.shared_examples 'refreshes project.path_locks_changed_epoch value' do
  it 'updates the path_locks_changed_epoch value', :clean_gitlab_redis_cache do
    travel_to(1.hour.ago) { project.refresh_path_locks_changed_epoch }

    original_epoch = project.path_locks_changed_epoch

    subject

    expect(project.path_locks_changed_epoch).to be > original_epoch
  end
end

RSpec.shared_examples 'does not refresh project.path_locks_changed_epoch' do
  it 'does not update the path_locks_changed_epoch value', :clean_gitlab_redis_cache do
    travel_to(1.hour.ago) { project.refresh_path_locks_changed_epoch }

    original_epoch = project.path_locks_changed_epoch

    subject

    expect(project.path_locks_changed_epoch).to eq original_epoch
  end
end
