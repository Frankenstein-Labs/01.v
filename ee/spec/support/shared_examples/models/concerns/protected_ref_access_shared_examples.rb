# frozen_string_literal: true

RSpec.shared_examples 'ee protected ref access' do
  include_context 'for protected ref access'

  let_it_be(:group, freeze: false) { project.group }
  let_it_be(:user, freeze: false) { create(:user, developer_of: project) }
  let_it_be(:test_group, freeze: false) { create(:group) }
  let_it_be(:test_user, freeze: false) { create(:user) }

  describe 'Validations:' do
    let(:access_user_id) { nil }
    let(:access_group_id) { nil }
    let(:access_user) { nil }
    let(:access_group) { nil }
    let(:importing) { false }

    subject do
      build(
        described_factory,
        protected_ref_name => protected_ref,
        user_id: access_user_id,
        group_id: access_group_id,
        importing: importing
      ).tap do |instance|
        # We need to assign manually after building because AR sets the
        # association to nil if the fk attributes are passed including nil.
        instance.user = access_user if access_user
        instance.group = access_group if access_group
      end
    end

    shared_context 'when feature :protected_refs_for_users is enabled' do
      before do
        allow(project).to receive(:feature_available?).with(:protected_refs_for_users).and_return(true)
      end
    end

    shared_context 'when feature :protected_refs_for_users is disabled' do
      before do
        allow(project).to receive(:feature_available?).with(:protected_refs_for_users).and_return(false)
      end
    end

    shared_context 'and not a role based access level' do
      before do
        allow(subject).to receive(:role?).and_return(false)
      end
    end

    shared_context 'and is a role based access level' do
      before do
        allow(subject).to receive(:role?).and_return(true)
      end
    end

    shared_examples 'validates user_id and group_id absence' do
      it { is_expected.to validate_absence_of(:group_id) }
      it { is_expected.to validate_absence_of(:user_id) }
    end

    shared_examples 'does not validate user_id and group_id absence' do
      it { is_expected.not_to validate_absence_of(:group_id) }
      it { is_expected.not_to validate_absence_of(:user_id) }
    end

    shared_examples 'validates user and group exist' do
      context 'and group_id is present' do
        let(:access_group_id) { 0 }

        it do
          is_expected.not_to be_valid
          expect(subject.errors.where(:group, :blank)).to be_present
        end
      end

      context 'and user_id is present' do
        let(:access_user_id) { 0 }

        it do
          is_expected.not_to be_valid
          expect(subject.errors.where(:user, :blank)).to be_present
        end
      end
    end

    shared_examples 'does not validate user and group exist' do
      context 'and group_id is present' do
        let(:access_group_id) { group.id }

        it { is_expected.not_to validate_presence_of(:group) }
      end

      context 'and user_id is present' do
        let(:access_user_id) { user.id }

        it { is_expected.not_to validate_presence_of(:user) }
      end
    end

    shared_examples 'validates user and group membership' do
      context 'and group is present' do
        let(:access_group) { group }

        before do
          allow(subject).to receive(:validate_group_membership)
          subject.valid?
        end

        it { is_expected.to have_received(:validate_group_membership) }
      end

      context 'and user is present' do
        let(:access_user) { user }

        before do
          allow(subject).to receive(:validate_user_membership)
          subject.valid?
        end

        it { is_expected.to have_received(:validate_user_membership) }
      end
    end

    shared_examples 'does not validate user and group membership' do
      context 'and group is present' do
        let(:access_group) { group }

        before do
          allow(subject).to receive(:validate_group_membership)
          subject.valid?
        end

        it { is_expected.not_to have_received(:validate_group_membership) }
      end

      context 'and user is present' do
        let(:access_user) { user }

        before do
          allow(subject).to receive(:validate_user_membership)
          subject.valid?
        end

        it { is_expected.not_to have_received(:validate_user_membership) }
      end
    end

    context 'when not importing' do
      let(:importing) { false }

      context 'when feature :protected_refs_for_users is enabled' do
        include_context 'when feature :protected_refs_for_users is enabled'

        context 'and not a role based access level' do
          include_context 'and not a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'validates user and group exist'
          it_behaves_like 'validates user and group membership'
        end

        context 'and is a role based access level' do
          include_context 'and is a role based access level'

          it_behaves_like 'validates user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end
      end

      context 'when feature :protected_refs_for_users is disabled' do
        include_context 'when feature :protected_refs_for_users is disabled'

        context 'and not a role based access level' do
          include_context 'and not a role based access level'

          it_behaves_like 'validates user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end

        context 'and is a role based access level' do
          include_context 'and is a role based access level'

          it_behaves_like 'validates user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end
      end
    end

    context 'when importing' do
      let(:importing) { true }

      context 'when feature :protected_refs_for_users is enabled' do
        include_context 'when feature :protected_refs_for_users is enabled'

        context 'and not a role based access level' do
          include_context 'and not a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end

        context 'and is a role based access level' do
          include_context 'and is a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end
      end

      context 'when feature :protected_refs_for_users is disabled' do
        include_context 'when feature :protected_refs_for_users is disabled'

        context 'and not a role based access level' do
          include_context 'and not a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end

        context 'and is a role based access level' do
          include_context 'and is a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end
      end
    end
  end

  describe 'scopes' do
    describe '::for_role' do
      subject(:for_role) { described_class.for_role }

      let_it_be(:developer_access, freeze: false) { create(described_factory, :developer_access) }
      let_it_be(:maintainer_access, freeze: false) { create(described_factory, :maintainer_access) }
      let_it_be(:user_access, freeze: false) do
        create(described_factory, protected_ref_name => protected_ref, user: create(:user, developer_of: project))
      end

      let_it_be(:group_access, freeze: false) do
        group = create(:project_group_link, :developer, project: project).group
        create(described_factory, protected_ref_name => protected_ref, group: group)
      end

      it 'includes all role based access levels' do
        expect(described_class.all).to contain_exactly(developer_access, maintainer_access, user_access, group_access)

        expect(for_role).to contain_exactly(developer_access, maintainer_access)
      end
    end
  end

  describe '#type' do
    using RSpec::Parameterized::TableSyntax

    where(
      :group,            :group_id, :user,            :user_id, :expectation
    ) do
      ref(:test_group) | nil      | nil             | nil     | :group
      nil              | 0        | nil             | nil     | :group
      nil              | nil      | ref(:test_user) | nil     | :user
      nil              | nil      | nil             | 0       | :user
    end

    with_them do
      let(:access_level) do
        build(described_factory, group_id: group_id, user_id: user_id).tap do |access_level|
          access_level.group = group if group
          access_level.user = user if user
        end
      end

      subject { access_level.type }

      it { is_expected.to eq(expectation) }
    end
  end

  describe '#humanize' do
    using RSpec::Parameterized::TableSyntax

    where(
      :group,            :group_id, :user,            :user_id, :expectation
    ) do
      ref(:test_group) | nil      | nil             | nil     | lazy { test_group.name }
      nil              | 0        | nil             | nil     | 'Group'
      nil              | nil      | ref(:test_user) | nil     | lazy { test_user.name }
      nil              | nil      | nil             | 0       | 'User'
    end

    with_them do
      let(:access_level) do
        build(described_factory, group_id: group_id, user_id: user_id).tap do |access_level|
          access_level.group = group if group
          access_level.user = user if user
        end
      end

      subject { access_level.humanize }

      it { is_expected.to eq(expectation) }
    end
  end

  describe '#check_access(current_user, current_project)' do
    let_it_be(:current_user, freeze: false) { create(:user, maintainer_of: project) }

    let(:user) { nil }
    let(:group) { nil }
    let(:current_project) { project }

    subject do
      described_class.new(
        protected_ref_name => protected_ref, user: user, group: group
      ).check_access(current_user, current_project)
    end

    context 'when user is assigned' do
      context 'when current_user is the user' do
        let(:user) { current_user }

        context 'when user is a project member' do
          it { is_expected.to eq(true) }
        end

        context 'when user is not a project member' do
          before do
            allow(project).to receive(:member?).with(user).and_return(false)
          end

          it { is_expected.to eq(false) }
        end
      end

      context 'when current_user is another user' do
        let(:user) { create(:user) }

        it { is_expected.to eq(false) }
      end
    end

    context 'when group is assigned' do
      let(:group) { create(:group) }

      context 'when the group is not invited' do
        it { is_expected.to eq(false) }
      end

      context 'when current_user is not in the group' do
        it { is_expected.to eq(false) }

        context 'when group has no access to project' do
          context 'and the user is a developer in the group' do
            before do
              group.add_developer(current_user)
            end

            it { is_expected.to eq(false) }
          end
        end
      end

      context 'when group is invited' do
        let!(:project_group_link) do
          create(:project_group_link, invited_group_access_level, project: project, group: group)
        end

        context 'and the group has max role less than developer' do
          let(:invited_group_access_level) { :reporter }

          context 'and the user is a developer in the group' do
            before do
              group.add_developer(current_user)
            end

            it { is_expected.to eq(false) }
          end
        end

        context 'and the group has max role of at least developer' do
          let(:invited_group_access_level) { :developer }

          context 'when current_user is a developer the group' do
            before do
              group.add_developer(current_user)
            end

            it { is_expected.to eq(true) }
          end

          context 'when current_user is a guest in the group' do
            before do
              group.add_guest(current_user)
            end

            it { is_expected.to eq(false) }
          end

          context 'when current_user is not in the group' do
            it { is_expected.to eq(false) }
          end

          context 'when current_user is a member of another group that has access to group' do
            using RSpec::Parameterized::TableSyntax

            let(:group_group_link) do
              create(:group_group_link, other_group_access_level, shared_group: project_group_link.group)
            end

            let(:other_group) { group_group_link.shared_with_group }

            context 'when current user has develop access to the other group' do
              where(
                :invited_group_access_level, :other_group_access_level, :expected_access
              ) do
                :developer                 | :developer               | false
                :developer                 | :guest                   | false
                :guest                     | :guest                   | false
                :guest                     | :developer               | false
              end

              before do
                other_group.add_developer(current_user)
              end

              with_them do
                it { is_expected.to eq(expected_access) }
              end
            end
          end
        end

        context 'when group is a subgroup' do
          let(:subgroup) { create(:group, :nested) }
          let(:parent_group) { subgroup.parent }
          let(:parent_group_developer) { create(:user) }
          let(:invited_group_access_level) { :developer }
          let(:group) { subgroup }

          before do
            parent_group.add_developer(parent_group_developer)
          end

          context 'when user is a developer of the parent group' do
            let(:user) { parent_group_developer }

            it { is_expected.to eq(false) }
          end
        end
      end
    end
  end
end
