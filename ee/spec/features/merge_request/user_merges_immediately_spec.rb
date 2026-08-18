# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge requests > User merges immediately', :js, feature_category: :code_review_workflow do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline,
      source_project: project, source_branch: 'feature',
      target_project: project, target_branch: 'master')
  end

  let_it_be(:ci_yaml) do
    { test: { stage: 'test', script: 'echo', only: ['merge_requests'] } }
  end

  before_all do
    project.add_maintainer(user)
    project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true, merge_trains_skip_train_allowed: true)
  end

  before do
    merge_request.all_pipelines.first.succeed!
    merge_request.update_head_pipeline
  end

  def merge_button
    find('[data-testid="ready_to_merge_state"] .accept-merge-request.btn-confirm')
  end

  def open_warning_dialog(confirm_button: 'Merge immediately', dialog_id: '#merge-immediately-confirmation-dialog')
    find('[data-testid="ready_to_merge_state"] .gl-new-dropdown-toggle').click

    click_button confirm_button

    expect(page).to have_selector(dialog_id)
  end

  def merge_from_warning_dialog(
    confirm_button: 'Merge now and restart train',
    dropdown_button: "Merge now and restart train")
    Sidekiq::Testing.fake! do
      open_warning_dialog(confirm_button: confirm_button,
        dialog_id: '#merge-train-restart-train-confirmation-dialog')

      click_button dropdown_button

      wait_for_requests

      expect(find_by_testid('merging-state')).to have_content('Merging!')
    end
  end

  context 'when the merge request is on the merge train and the merge_trains_skip_train feature flag is disabled' do
    before do
      stub_licensed_features(merge_pipelines: true, merge_trains: true)
      stub_feature_flags(merge_trains_skip_train: false)
      stub_ci_pipeline_yaml_file(YAML.dump(ci_yaml))

      sign_in(user)
      visit project_merge_request_path(project, merge_request)
      wait_for_requests
    end

    it 'shows a warning dialog and does nothing if the user selects "Cancel"' do
      Sidekiq::Testing.fake! do
        open_warning_dialog

        find(':focus').send_keys :enter

        expect(merge_button).to have_content('Set to auto-merge')
      end
    end

    it 'shows a warning dialog and merges immediately after the user confirms' do
      Sidekiq::Testing.fake! do
        open_warning_dialog

        click_button 'Merge immediately'

        expect(find_by_testid('merging-state')).to have_content('Merging!')
      end
    end
  end

  context 'when the merge request is on the merge train and the merge_trains_skip_train feature flag is enabled' do
    before do
      stub_licensed_features(merge_pipelines: true, merge_trains: true)
      stub_feature_flags(merge_trains_skip_train: true)
      stub_ci_pipeline_yaml_file(YAML.dump(ci_yaml))

      sign_in(user)
      visit project_merge_request_path(project, merge_request)
      wait_for_requests
    end

    it 'shows a warning dialog and does nothing if the user selects "Cancel"' do
      Sidekiq::Testing.fake! do
        open_warning_dialog(confirm_button: 'Merge now and restart train',
          dialog_id: '#merge-train-restart-train-confirmation-dialog')

        find(':focus').send_keys :enter

        expect(merge_button).to have_content('Set to auto-merge')
      end
    end

    it 'shows a warning dialog and merges immediately while restarting the train after the user confirms' do
      merge_from_warning_dialog
    end

    it 'shows a warning dialog and merges immediately without restarting the train after the user confirms' do
      merge_from_warning_dialog(confirm_button: "Merge now and don't restart train",
        dropdown_button: "Merge now and don't restart train")
    end
  end
end
