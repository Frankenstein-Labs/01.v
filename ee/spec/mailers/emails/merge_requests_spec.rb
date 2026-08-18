# frozen_string_literal: true

require 'spec_helper'
require 'email_spec'

RSpec.describe Emails::MergeRequests, feature_category: :code_review_workflow do
  include EmailSpec::Matchers

  # rubocop: disable RSpec/FactoryBot/AvoidCreate
  let_it_be_with_reload(:current_user) { create(:user, name: 'Jane Doe') }
  let_it_be_with_reload(:reviewer) { create(:user) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, author: current_user, reviewers: [reviewer]) }
  let_it_be(:merge_request_diff) { create(:merge_request_diff, merge_request: merge_request) }
  # rubocop: enable RSpec/FactoryBot/AvoidCreate

  describe '#added_as_approver_email' do
    # rubocop: disable RSpec/FactoryBot/AvoidCreate -- The underlying code searches the DB for the correct data
    let_it_be(:updated_by_user) { create(:user) }
    # rubocop: enable RSpec/FactoryBot/AvoidCreate

    subject { Notify.added_as_approver_email(current_user.id, merge_request.id, updated_by_user.id) }

    it 'has the correct subject and body' do
      aggregate_failures do
        path = project_merge_request_url(merge_request.target_project, merge_request)

        is_expected.to have_referable_subject(merge_request, reply: true)
        is_expected.to have_body_text(
          "<strong>#{current_user.name}</strong> has created a merge request that you can approve."
        )
        is_expected.to have_link("View it on GitLab", href: path)
      end
    end
  end
end
