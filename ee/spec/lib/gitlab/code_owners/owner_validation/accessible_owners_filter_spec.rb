# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::OwnerValidation::AccessibleOwnersFilter, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :in_subgroup) }
  let_it_be(:invalid_name) { 'not_a_user' }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:lowercase_name_developer) { create(:user, developer_of: project, username: 'testuser123') }
  let_it_be(:uppercase_name_developer) { create(:user, developer_of: project, username: 'UPPER') }
  let_it_be(:owner) { create(:user, owner_of: project) }
  let_it_be(:invalid_email) { 'not_a_user@mail.com' }
  let_it_be(:blocked_developer) { create(:user, :blocked, developer_of: project) }
  let_it_be(:deactivated_developer) { create(:user, :deactivated, developer_of: project) }
  let_it_be(:non_member_extra_email) { create(:email, :confirmed, :skip_validate, user: non_member).email }
  let_it_be(:maintainer_extra_email) { create(:email, :confirmed, :skip_validate, user: maintainer).email }
  let_it_be(:owner_unconfirmed_extra_email) { create(:email, :skip_validate, user: owner).email }
  let_it_be(:external_group) { create(:group) }
  let_it_be(:invited_group) { create(:project_group_link, project: project).group }
  let_it_be(:project_group) { project.group }
  let_it_be(:parent_group) { project_group.parent }

  let(:filter) do
    names = [
      invalid_name,
      non_member.username,
      external_group.full_path,
      developer.username,
      lowercase_name_developer.username.upcase,
      uppercase_name_developer.username.downcase,
      maintainer.username,
      blocked_developer.username,
      deactivated_developer.username,
      invited_group.full_path,
      invited_group.full_path.upcase,
      project_group.full_path,
      parent_group.full_path
    ]

    emails = [
      invalid_email,
      non_member.private_commit_email,
      non_member_extra_email,
      owner_unconfirmed_extra_email,
      guest.email,
      developer.email,
      maintainer.private_commit_email,
      maintainer_extra_email,
      lowercase_name_developer.email,
      uppercase_name_developer.email
    ]
    described_class.new(project, names: names, emails: emails)
  end

  describe '#output_groups' do
    it 'returns invited and ancestral groups' do
      expect(filter.output_groups).to contain_exactly(
        invited_group,
        project_group,
        parent_group
      )
    end
  end

  describe '#output_users' do
    it 'returns project members' do
      expect(filter.output_users).to contain_exactly(
        guest,
        developer,
        maintainer,
        lowercase_name_developer,
        uppercase_name_developer
      )
    end
  end

  describe '#invalid_names' do
    it 'returns all names that do not match an accessible group or user' do
      expect(filter.invalid_names).to contain_exactly(
        invalid_name,
        non_member.username,
        blocked_developer.username,
        deactivated_developer.username,
        external_group.full_path
      )
    end
  end

  describe '#invalid_emails' do
    it 'returns all emails that do not match an accessible user or are not verified' do
      expect(filter.invalid_emails).to contain_exactly(
        invalid_email,
        non_member.private_commit_email,
        non_member_extra_email,
        owner_unconfirmed_extra_email
      )
    end
  end

  describe '#valid_group_names' do
    it 'returns all names that match an accessible group' do
      expect(filter.valid_group_names).to contain_exactly(
        invited_group.full_path,
        project_group.full_path,
        parent_group.full_path
      )
    end
  end

  describe '#valid_usernames' do
    it 'returns all names that match an accessible user regardless of case' do
      expect(filter.valid_usernames).to contain_exactly(
        developer.username,
        maintainer.username,
        lowercase_name_developer.username.upcase,
        uppercase_name_developer.username.downcase
      )
    end
  end

  describe '#valid_emails' do
    it 'returns all verified emails that match an accessible user' do
      expect(filter.valid_emails).to contain_exactly(
        guest.email,
        developer.email,
        maintainer.private_commit_email,
        maintainer_extra_email,
        lowercase_name_developer.email,
        uppercase_name_developer.email
      )
    end
  end

  describe '#error_message' do
    it 'returns an error message key to be applied to invalid entries' do
      expect(filter.error_message).to eq(:inaccessible_owner)
    end
  end

  describe '#valid_entry?(reference_extractor)' do
    let(:reference_extractor) { instance_double(Gitlab::CodeOwners::ReferenceExtractor, names: names, emails: emails) }
    let(:names) { ['bar'] }
    let(:invalid_names) { ['foo'] }
    let(:emails) { ['bar@mail.com'] }
    let(:invalid_emails) { ['foo@mail.com'] }

    before do
      allow(filter).to receive_messages(invalid_names: invalid_names, invalid_emails: invalid_emails)
    end

    context 'when reference_extractor contains no invalid references' do
      it 'returns true' do
        expect(filter.valid_entry?(reference_extractor)).to be(true)
      end
    end

    context 'when reference_extractor.names includes invalid_names' do
      let(:names) { %w[foo bar] }

      it 'returns false' do
        expect(filter.valid_entry?(reference_extractor)).to be(false)
      end
    end

    context 'when reference_extractor.emails includes invalid_emails' do
      let(:emails) { %w[foo@mail.com bar@mail.com] }

      it 'returns false' do
        expect(filter.valid_entry?(reference_extractor)).to be(false)
      end
    end
  end

  it 'avoids N+1 queries', :request_store, :use_sql_query_cache do
    # Reload the project manually, outside of the control
    project_id = project.id
    project = Project.find(project_id)

    names = [
      invalid_name,
      non_member.username,
      external_group.full_path,
      guest.username,
      developer.username,
      maintainer.username,
      invited_group.full_path,
      project_group.full_path,
      parent_group.full_path
    ]

    emails = [
      invalid_email,
      non_member.private_commit_email,
      non_member_extra_email,
      guest.email,
      developer.email,
      maintainer.private_commit_email,
      maintainer_extra_email
    ]

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      filter = described_class.new(project, names: names, emails: emails)
      filter.output_groups
      filter.output_users
      filter.valid_group_names
      filter.valid_usernames
      filter.valid_emails
      filter.invalid_emails
      filter.invalid_names
    end

    extra_developer = create(:user, developer_of: project)
    extra_developer_email = create(:email, :skip_validate, user: extra_developer).email
    extra_group = create(:project_group_link, project: project).group

    names += ['foo', extra_developer.username, extra_group.full_path]
    emails += ['foo@mail.com', extra_developer_email]

    create(:email, :confirmed, :skip_validate, user: create(:user))
    create(:email, :confirmed, :skip_validate, user: create(:user, guest_of: project))
    create(:group)
    create(:project_group_link, project: project)

    # Clear the RequestStore to ensure we do not have a warm cache
    RequestStore.clear!

    # Refind the project to reset the associations
    project = Project.find(project_id)

    expect do
      filter = described_class.new(project, names: names, emails: emails)
      filter.output_groups
      filter.output_users
      filter.valid_group_names
      filter.valid_usernames
      filter.valid_emails
      filter.invalid_names
      filter.invalid_emails
    end.to issue_same_number_of_queries_as(control)
  end
end
