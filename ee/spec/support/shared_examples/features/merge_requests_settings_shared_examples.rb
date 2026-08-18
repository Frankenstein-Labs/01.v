# frozen_string_literal: true

RSpec.shared_examples_for 'MR checks settings' do
  let_it_be(:user, freeze: false) { create(:user) }

  before do
    sign_in(user)
    group.add_owner(user)
    stub_licensed_features(group_level_merge_checks_setting: true)
  end

  context 'when checkboxes are not locked', :js do
    it 'shows initial status' do
      visit(merge_requests_settings_path)

      expect(find_field('Pipelines must succeed', disabled: false)).not_to be_checked
      expect(find_field('Skipped pipelines are considered successful', disabled: true)).not_to be_checked
      expect(find_field('All threads must be resolved', disabled: false)).not_to be_checked
    end
  end

  context 'when checkboxes are locked', :js do
    before do
      group.namespace_settings.update!(
        only_allow_merge_if_pipeline_succeeds: true,
        allow_merge_on_skipped_pipeline: true,
        only_allow_merge_if_all_discussions_are_resolved: true
      )
    end

    it 'shows disabled status' do
      visit(merge_requests_settings_path)

      expect(find_field('Pipelines must succeed', disabled: true)).to be_checked
      expect(find_field('Skipped pipelines are considered successful', disabled: true)).to be_checked
      expect(find_field('All threads must be resolved', disabled: true)).to be_checked
    end
  end
end
