# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:nav:dump_structure', :silence_stdout, :enable_admin_mode, feature_category: :navigation do
  let!(:admin) { create(:admin) }
  let!(:group) { create(:group, owners: [admin]) }

  before do
    # Build out scaffold records required for rake task
    create(:project)
    create(:organization)

    Rake.application.rake_require 'tasks/gitlab/nav/dump_structure'
  end

  it 'outputs YAML describing the current nav structure' do
    # Sample items that _hopefully_ won't change very often.
    expected = {
      "generated_at" => an_instance_of(String),
      "commit_sha" => an_instance_of(String),
      "contexts" => a_collection_including(a_hash_including({
        "title" => "Admin area",
        "items" => a_collection_including(a_hash_including({
          "id" => "admin_settings_menu",
          "title" => "Settings",
          "icon" => "settings",
          "link" => "/admin/application_settings/general",
          "items" => a_collection_including(a_hash_including({
            "id" => "admin_integrations",
            "title" => "Integrations",
            "link" => "/admin/application_settings/integrations",
            "tags" => a_collection_including("sm")
          }))
        }))
      }))
    }
    expect(YAML).to receive(:dump).with(expected)

    # The native Gitlab.simulate_com? method explicitly ignores the
    # GITLAB_SIMULATE_SAAS environment variable outside of the development
    # environment. This has been debated and iterated on over the years, yet the
    # override remains limited to development only. The most recent MR for this
    # was to revert an attempt to make it universally available:
    # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/110178
    #
    # Since this feature is only in service of internal documentation, I'm
    # opting to mock the original method with the desired dynamic behavior.
    #
    allow(Gitlab).to receive(:simulate_com?) do
      Gitlab::Utils.to_boolean(ENV['GITLAB_SIMULATE_SAAS'])
    end

    run_rake_task('gitlab:nav:dump_structure', [admin.id])
  end
end
