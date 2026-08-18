# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::OwnerValidation::Process, feature_category: :source_code_management do
  include FakeBlobHelpers

  # container is required by fake_blob but we want to test when project is nil
  # so we name this container and alias as project
  let_it_be(:container) { create(:project, :in_group) }

  let(:project) { container }
  let(:file_content) { File.read(Rails.root.join('ee/spec/fixtures/codeowners_example')) }
  let(:codeowner_file_path) { 'CODEOWNERS' }
  let(:blob) { fake_blob(path: codeowner_file_path, data: file_content, container: container) }
  let(:file) { Gitlab::CodeOwners::File.new(blob) }

  subject(:process) { described_class.new(project, file) }

  describe '#execute' do
    subject(:execute) { process.execute }

    context 'when project is nil' do
      let(:project) { nil }

      it 'does not perform any queries' do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { execute }

        expect(control.count).to be_zero
      end
    end

    context 'when there are already errors on the file' do
      before do
        file.errors.add(:invalid_section_owner, 1)
      end

      it 'does not perform any queries' do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { execute }

        expect(control.count).to be_zero
      end
    end

    context 'when project is present and file has no errors' do
      let(:non_member) { create(:user) }
      let(:reporter) { create(:user, reporter_of: container) }

      let(:inaccessible_name_1) { '@not_a_user' }
      let(:inaccessible_name_2) { "@#{non_member.username}" }
      let(:inaccessible_name_3) { "@#{create(:group).full_path}" }
      let(:inaccessible_email_1) { 'not_a_user@mail.com' }
      let(:inaccessible_email_2) { non_member.email }
      let(:inaccessible_email_3) { non_member.private_commit_email }
      let(:inaccessible_email_4) { create(:email, :confirmed, :skip_validate, user: non_member).email }
      let(:owner_without_permission_name) { "@#{reporter.username}" }
      let(:owner_without_permission_email) { reporter.email }
      let(:unqualified_group_name) { "@#{create(:project_group_link, :reporter, project: project).group.full_path}" }
      let(:group_without_eligible_approvers_name) do
        "@#{create(:project_group_link, :developer, project: project).group.full_path}"
      end

      let(:file_content) do
        <<~CODEOWNERS
          path/one.rb #{inaccessible_name_1}
          path/two.rb #{inaccessible_email_1}

          [Section 1]
          path/three.rb #{inaccessible_name_2}
          path/four.rb #{inaccessible_email_2}

          [Section 2][2]
          path/five.rb #{inaccessible_name_3}
          path/six.rb #{inaccessible_email_3}

          [Section 3] #{inaccessible_name_3}
          path/seven.rb

          [Section 4][2] #{inaccessible_email_4}
          path/eight.rb

          [Section 5]
          path/nine.rb #{owner_without_permission_name}
          path/ten.rb #{owner_without_permission_email}

          [Section 6]
          path/eleven.rb #{unqualified_group_name}
          path/twelve.rb #{group_without_eligible_approvers_name}
        CODEOWNERS
      end

      before do
        execute
      end

      it 'adds an error to the file for each error' do
        inaccessible_owner_errors = [1, 2, 5, 6, 9, 10, 13, 16].map do |line_number|
          Gitlab::CodeOwners::Error.new(:inaccessible_owner, line_number)
        end
        owner_without_permission_errors = [19, 20].map do |line_number|
          Gitlab::CodeOwners::Error.new(:owner_without_permission, line_number)
        end
        unqualified_group_errors = [Gitlab::CodeOwners::Error.new(:unqualified_group, 23)]
        group_without_eligible_approvers_errors = [Gitlab::CodeOwners::Error.new(:group_without_eligible_approvers, 24)]
        expected_errors = inaccessible_owner_errors +
          owner_without_permission_errors +
          unqualified_group_errors +
          group_without_eligible_approvers_errors
        expect(file.errors).to match_array(expected_errors)
      end
    end
  end
end
