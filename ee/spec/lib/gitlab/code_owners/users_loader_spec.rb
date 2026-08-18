# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::UsersLoader, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project) }

  let(:text) do
    <<~TXT
    This is a long text that mentions some users.
    @user-1, @user-2 and user@gitlab.org take a walk in the park.
    There they meet @user-4 that was out with other-user@gitlab.org.
    @user-1 thought it was late, so went home straight away
    TXT
  end

  let(:extractor) { Gitlab::CodeOwners::ReferenceExtractor.new(text) }
  let(:entry) { double('Entries') }

  describe '#load_to' do
    subject(:load_users) do
      described_class.new(project, names: extractor.names, emails: extractor.emails).load_to([entry])
    end

    before do
      allow(entry).to receive(:add_matching_users_from)
    end

    context 'input has no matching e-mail or usernames' do
      let(:text) { 'My test' }

      it 'returns an empty list of users' do
        load_users

        expect(entry).to have_received(:add_matching_users_from).with([])
      end
    end

    context 'nil input' do
      let(:text) { nil }

      it 'returns an empty relation when nil was passed' do
        load_users

        expect(entry).to have_received(:add_matching_users_from).with([])
      end
    end

    it 'returns the user case insensitive for usernames' do
      user = create(:user, username: "USER-4")
      project.add_developer(user)

      load_users

      expect(entry).to have_received(:add_matching_users_from).with([user])
    end

    it 'returns users for confirmed primary emails' do
      user = create(:user, email: 'user@gitlab.org')
      project.add_developer(user)

      load_users

      expect(entry).to have_received(:add_matching_users_from).with([user])
    end

    it 'returns users for unconfirmed primary emails' do
      user = create(:user, :unconfirmed, email: 'user@gitlab.org')
      project.add_developer(user)

      load_users

      expect(entry).to have_received(:add_matching_users_from).with([user])
    end

    it 'returns users for confirmed secondary emails' do
      user = create(:email, :confirmed, email: 'other-user@gitlab.org').user
      project.add_developer(user)

      load_users

      expect(entry).to have_received(:add_matching_users_from).with([user])
    end

    it 'does not return users for unconfirmed secondary emails' do
      user = create(:email, email: 'other-user@gitlab.org').user
      project.add_developer(user)

      load_users

      expect(entry).to have_received(:add_matching_users_from).with([])
    end

    context 'input as array of strings' do
      let(:text) { super().lines }

      it 'is treated as one string' do
        user_1 = create(:user, username: "USER-1")
        project.add_guest(user_1)

        user_4 = create(:user, username: "USER-4")
        project.add_reporter(user_4)

        user_email = create(:user, email: 'user@gitlab.org')
        project.add_maintainer(user_email)

        load_users

        expect(entry).to have_received(:add_matching_users_from) do |args|
          expect(args).to contain_exactly(user_1, user_4, user_email)
        end
      end
    end
  end

  describe '#members' do
    # Valid users - active project members
    let_it_be(:developer) { create(:user, developer_of: project) }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }

    # Invalid users - blocked, deactivated, or non-members
    let_it_be(:blocked_developer) { create(:user, :blocked, developer_of: project) }
    let_it_be(:deactivated_developer) { create(:user, :deactivated, developer_of: project) }
    let_it_be(:non_member) { create(:user) }

    let(:valid_users) { [developer, maintainer] }
    let(:invalid_users) { [blocked_developer, deactivated_developer, non_member] }

    let(:loader) do
      names = [
        developer.username,
        maintainer.username,
        blocked_developer.username,
        deactivated_developer.username,
        non_member.username
      ]

      emails = [
        developer.email,
        maintainer.email,
        blocked_developer.email,
        deactivated_developer.email,
        non_member.email
      ]

      described_class.new(project, names: names, emails: emails)
    end

    subject(:members) { loader.members }

    it 'returns only valid users' do
      expect(members).to match_array(valid_users)
    end

    it 'excludes blocked users' do
      expect(members).not_to include(blocked_developer)
    end

    it 'excludes deactivated users' do
      expect(members).not_to include(deactivated_developer)
    end

    it 'excludes non-members' do
      expect(members).not_to include(non_member)
    end

    context 'when matching by usernames case insensitively' do
      let(:loader) { described_class.new(project, names: [developer.username.upcase]) }

      it { is_expected.to contain_exactly(developer) }
    end

    context 'when no names or emails provided' do
      let(:loader) { described_class.new(project, names: [], emails: []) }

      it { is_expected.to be_empty }
    end

    context 'with internal users' do
      where(:internal_user_type) do
        User::INTERNAL_USER_TYPES
      end

      with_them do
        it 'excludes internal users' do
          internal_user = create(:user, user_type: internal_user_type)
          project.add_developer(internal_user)

          loader = described_class.new(project, names: [internal_user.username])

          expect(loader.members).not_to include(internal_user)
        end
      end
    end
  end
end
