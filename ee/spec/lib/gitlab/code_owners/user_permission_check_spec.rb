# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::UserPermissionCheck, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project, :in_group) }
  let(:limit) { Gitlab::CodeOwners::File::MAX_REFERENCES }
  let(:section) { Gitlab::CodeOwners::Section::DEFAULT }
  let(:group_entry) do
    Gitlab::CodeOwners::Entry.new(
      'file1',
      "@#{project.group.full_path}",
      section: section,
      optional: true,
      approvals_required: 0,
      exclusion: false,
      line_number: 1
    )
  end

  let(:entry) do
    Gitlab::CodeOwners::Entry.new(
      'file2',
      "@#{user.username}",
      section: section,
      optional: true,
      approvals_required: 0,
      exclusion: false,
      line_number: 3
    )
  end

  let(:entries) { [group_entry, entry] }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:group_developer) { create(:user, developer_of: project.group) }
  let(:not_persisted_user) { build(:user) }
  let(:non_member) { create(:user) }

  subject(:errors) { described_class.new(project, entries, limit: limit).errors }

  context 'when the entries mention a username' do
    shared_examples_for 'validation error for name without permissions' do
      it 'has warnings' do
        expect(errors).to contain_exactly({ error: :owner_without_permission, line_number: entry.line_number })
      end
    end

    shared_examples_for 'valid entries' do
      it { is_expected.to be_blank }
    end

    context 'when the user does not exist' do
      let(:user) { not_persisted_user }

      it_behaves_like 'validation error for name without permissions'
    end

    context 'when the user is not a member' do
      let(:user) { non_member }

      it_behaves_like 'validation error for name without permissions'
    end

    context 'when the user is directly invited' do
      let(:user) { guest }

      it_behaves_like 'validation error for name without permissions'

      context 'with sufficient access' do
        let(:user) { developer }

        it_behaves_like 'valid entries'
      end
    end

    context 'when the user inherits access from the parent group' do
      let(:user) { group_developer }

      it_behaves_like 'valid entries'
    end

    context 'when the user is from an invited group' do
      let(:access_level) { :guest }
      let(:project_group_link) { create :project_group_link, access_level, project: project }
      let(:user) { create(:user, developer_of: project_group_link.group) }

      it_behaves_like 'validation error for name without permissions'

      context 'with sufficient access' do
        let(:access_level) { :developer }

        it_behaves_like 'valid entries'
      end
    end
  end

  describe 'queries' do
    let(:multiple_reference_entry) do
      Gitlab::CodeOwners::Entry.new(
        'file1',
        "@#{project.group.full_path} @#{group_developer.username}",
        section: section,
        optional: true,
        approvals_required: 0,
        exclusion: false,
        line_number: 1
      )
    end

    let(:single_reference_entry) do
      Gitlab::CodeOwners::Entry.new(
        'file2',
        "@#{project.group.full_path}",
        section: section,
        optional: true,
        approvals_required: 0,
        exclusion: false,
        line_number: 1
      )
    end

    let(:invalid_entry_with_multiple_references) do
      Gitlab::CodeOwners::Entry.new(
        'file4',
        "@#{developer.username} @#{non_member.username} @#{guest.username}",
        section: section,
        optional: true,
        approvals_required: 0,
        exclusion: false,
        line_number: 2
      )
    end

    let(:invalid_entry) do
      Gitlab::CodeOwners::Entry.new(
        'file3',
        "@#{not_persisted_user.username}",
        section: section,
        optional: true,
        approvals_required: 0,
        exclusion: false,
        line_number: 3
      )
    end

    let!(:entries) do
      [
        multiple_reference_entry,
        single_reference_entry,
        invalid_entry_with_multiple_references,
        invalid_entry
      ]
    end

    context 'when limiting the number of references' do
      context 'when the number of references is within the limit' do
        it 'validates all the references' do
          expect(Gitlab::CodeOwners::UsersLoader).to receive(:new).with(
            project, names: [group_developer, developer, non_member, guest, not_persisted_user].map(&:username)
          ).and_call_original
          expect(errors.all? { |e| e[:error] == :owner_without_permission }).to be(true)
          expect(errors.pluck(:line_number)).to match_array([
            invalid_entry_with_multiple_references.line_number,
            invalid_entry.line_number
          ])
        end
      end

      context 'when there are more references than the limit' do
        before do
          stub_const('Gitlab::CodeOwners::File::MAX_REFERENCES', 4)
        end

        it 'only validates up to the maximum' do
          expect(Gitlab::CodeOwners::UsersLoader).to receive(:new).with(
            project, names: [group_developer, developer, non_member].map(&:username)
          ).and_call_original
          error = errors.first

          expect(errors.size).to eq(1)
          expect(error[:error]).to eq(:owner_without_permission)
          expect(error[:line_number]).to eq(invalid_entry_with_multiple_references.line_number)
        end
      end
    end

    it 'does not perform N+1 queries', :request_store, :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(query_recorder_debug: true, skip_cached: false) do
        described_class.new(project, [invalid_entry_with_multiple_references, multiple_reference_entry],
          limit: limit).errors
      end

      extra_developer = create(:user, developer_of: project)
      extra_guest = create(:user, guest_of: project)
      extra_non_member = create(:user)
      extra_invalid_entry = Gitlab::CodeOwners::Entry.new(
        'extra_file',
        "@#{extra_developer.username} @#{extra_non_member.username} @#{extra_guest.username}",
        section: section,
        optional: true,
        approvals_required: 0,
        exclusion: false,
        line_number: 10
      )

      project.reload

      expect do
        described_class.new(project, [
          invalid_entry_with_multiple_references,
          multiple_reference_entry,
          extra_invalid_entry
        ], limit: limit).errors
      end.not_to exceed_query_limit(control.count - 1)
    end
  end
end
