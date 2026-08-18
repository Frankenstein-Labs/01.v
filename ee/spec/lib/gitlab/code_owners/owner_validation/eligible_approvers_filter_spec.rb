# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::OwnerValidation::EligibleApproversFilter, feature_category: :source_code_management do
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:project, freeze: false) { create(:project, :in_group) }
  let_it_be(:invalid_username) { 'not_a_user' }
  let_it_be(:non_member, freeze: false) { create(:user) }
  let_it_be(:guest, freeze: false) { create(:user, guest_of: project) }
  let_it_be(:developer, freeze: false) { create(:user, developer_of: project) }
  let_it_be(:maintainer, freeze: false) { create(:user, maintainer_of: project) }
  let_it_be(:lowercase_name_developer, freeze: false) { create(:user, developer_of: project, username: 'testuser123') }
  let_it_be(:uppercase_name_developer, freeze: false) { create(:user, developer_of: project, username: 'UPPER') }
  let_it_be(:owner, freeze: false) { create(:user, owner_of: project) }
  let_it_be(:invalid_email) { 'not_a_user@mail.com' }
  let_it_be(:non_member_extra_email, freeze: false) do
    create(:email, :confirmed, :skip_validate, user: non_member).email
  end

  let_it_be(:develop_extra_email, freeze: false) { create(:email, :confirmed, :skip_validate, user: developer).email }
  let_it_be(:maintainer_unconfirmed_extra_email, freeze: false) do
    create(:email, :skip_validate, user: maintainer).email
  end

  let_it_be(:filter, freeze: false) do
    users = [
      non_member,
      guest,
      developer,
      maintainer,
      owner,
      lowercase_name_developer,
      uppercase_name_developer
    ]

    usernames = [
      invalid_username,
      guest.username,
      non_member.username,
      developer.username,
      maintainer.username,
      owner.username,
      lowercase_name_developer.username.upcase,
      uppercase_name_developer.username.downcase
    ]

    emails = [
      invalid_email,
      guest.email,
      non_member.private_commit_email,
      non_member_extra_email,
      developer.email,
      develop_extra_email,
      maintainer.private_commit_email,
      maintainer_unconfirmed_extra_email,
      owner.email,
      lowercase_name_developer.email,
      uppercase_name_developer.email
    ]

    described_class.new(project, users: users, usernames: usernames, emails: emails)
  end

  describe '#output_users' do
    it 'returns all users who can approve merge requests' do
      expect(filter.output_users).to contain_exactly(
        developer,
        maintainer,
        owner,
        lowercase_name_developer,
        uppercase_name_developer
      )
    end
  end

  describe '#invalid_username' do
    it 'returns all usernames that do not match an eligible approver' do
      expect(filter.invalid_usernames).to contain_exactly(
        invalid_username,
        non_member.username,
        guest.username
      )
    end
  end

  describe '#valid_usernames' do
    it 'returns all usernames that match an eligible approver regardless of case' do
      expect(filter.valid_usernames).to contain_exactly(
        developer.username,
        maintainer.username,
        owner.username,
        lowercase_name_developer.username.upcase,
        uppercase_name_developer.username.downcase
      )
    end
  end

  describe '#invalid_emails' do
    it 'returns all emails that do not belong to an eligible approver or are not verified' do
      expect(filter.invalid_emails).to contain_exactly(
        invalid_email,
        non_member.private_commit_email,
        non_member_extra_email,
        guest.email,
        maintainer_unconfirmed_extra_email
      )
    end
  end

  describe '#valid_emails' do
    it 'returns all verified emails that belong to an elibible approver' do
      expect(filter.valid_emails).to contain_exactly(
        developer.email,
        develop_extra_email,
        maintainer.private_commit_email,
        owner.email,
        lowercase_name_developer.email,
        uppercase_name_developer.email
      )
    end
  end

  describe '#error_message' do
    it 'returns an error message key to be applied to invalid entries' do
      expect(filter.error_message).to eq(:owner_without_permission)
    end
  end

  describe '#valid_entry?(references)' do
    let(:references) { instance_double(Gitlab::CodeOwners::ReferenceExtractor, names: names, emails: emails) }
    let(:names) { ['bar'] }
    let(:invalid_usernames) { ['foo'] }
    let(:emails) { ['bar@mail.com'] }
    let(:invalid_emails) { ['foo@mail.com'] }

    before do
      allow(filter).to receive_messages(invalid_usernames: invalid_usernames, invalid_emails: invalid_emails)
    end

    context 'when references contains no invalid references' do
      it 'returns true' do
        expect(filter.valid_entry?(references)).to be(true)
      end
    end

    context 'when references.names includes invalid_usernames' do
      let(:names) { %w[foo bar] }

      it 'returns false' do
        expect(filter.valid_entry?(references)).to be(false)
      end
    end

    context 'when references.emails includes invalid_emails' do
      let(:emails) { %w[foo@mail.com bar@mail.com] }

      it 'returns false' do
        expect(filter.valid_entry?(references)).to be(false)
      end
    end
  end

  it 'does not perform N+1 queries', :request_store, :use_sql_query_cache do
    project_id = project.id
    project = Project.find(project_id)

    input_users = [
      guest,
      developer,
      maintainer,
      non_member
    ]

    users = User.find(input_users.pluck(:id))

    usernames = [
      invalid_username,
      non_member.username,
      guest.username,
      developer.username,
      maintainer.username
    ]

    emails = [
      invalid_email,
      non_member.private_commit_email,
      non_member_extra_email,
      guest.email,
      developer.email,
      develop_extra_email,
      maintainer.private_commit_email,
      maintainer_unconfirmed_extra_email
    ]

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      filter = described_class.new(project, users: users, usernames: usernames, emails: emails)
      filter.output_users
      filter.invalid_usernames
      filter.valid_usernames
      filter.invalid_emails
      filter.valid_emails
    end

    extra_non_member = create(:user)
    extra_guest = create(:user, guest_of: project)
    extra_developer = create(:user, developer_of: project)
    create(:email, :confirmed, :skip_validate, user: extra_non_member)
    create(:email, :confirmed, :skip_validate, user: extra_guest)
    extra_developer_email = create(:email, :skip_validate, user: extra_developer)

    project = Project.find(project_id)
    user_ids = (input_users + [extra_non_member, extra_guest, extra_developer]).pluck(:id)
    users = User.find(user_ids)

    usernames += ['foo', extra_developer.username]
    emails += ['foo@mail.com', extra_developer_email]

    # project.team.max_member_access_for_user_ids warms up the SafeRequestStore
    # so we need to clear it out to ensure this spec is valid
    RequestStore.clear!

    expect do
      filter = described_class.new(project, users: users, usernames: usernames, emails: emails)
      filter.output_users
      filter.invalid_usernames
      filter.valid_usernames
      filter.invalid_emails
      filter.valid_emails
    end.not_to exceed_query_limit(control.count)
  end
end
