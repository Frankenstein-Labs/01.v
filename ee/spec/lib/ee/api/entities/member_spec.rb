# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Member, feature_category: :groups_and_projects do
  subject(:entity_representation) { described_class.new(member, options).as_json }

  let_it_be(:group) { create(:group) }
  let_it_be(:saml_provider) { create(:saml_provider, group: group) }

  let_it_be(:current_user) { create(:user) }

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:member) { create(:group_member, :owner, user: user, group: group) }

  let(:options) do
    {
      current_user: current_user
    }
  end

  context 'when current_user option is nil' do
    let(:current_user) { nil }

    it 'exposes basic attributes' do
      expect(entity_representation).to be_kind_of(Hash)
    end
  end

  context 'when member record is invited member' do
    let_it_be(:member) { create(:group_member, :invited, :owner, group: group) }

    it 'exposes basic attributes' do
      expect(entity_representation).to be_kind_of(Hash)
    end

    context 'when current_user is an admin' do
      let_it_be(:current_user) { create(:user, :admin) }

      context 'when admin mode enabled', :enable_admin_mode do
        it 'exposes basic attributes' do
          expect(entity_representation).to be_kind_of(Hash)
        end
      end

      context 'when admin mode disabled' do
        it 'exposes basic attributes' do
          expect(entity_representation).to be_kind_of(Hash)
        end
      end
    end
  end

  context 'when member record is member request' do
    let_it_be(:member) { create(:group_member, :access_request, group: group) }

    it 'exposes basic attributes' do
      expect(entity_representation).to be_kind_of(Hash)
    end
  end

  # This case is valid until https://gitlab.com/gitlab-org/gitlab/-/issues/329841 is resolved.
  context 'when member have orphaned source' do
    let(:member) { create(:group_member, :owner, group: group) }

    before do
      member.update_column(:source_id, -42)
    end

    it 'exposes basic attributes' do
      expect(entity_representation).to be_kind_of(Hash)
    end
  end

  context 'for group_saml_identity' do
    let_it_be(:group_saml_identity) { build_stubbed(:group_saml_identity, extern_uid: 'TESTIDENTITY') }

    before do
      allow(member).to receive(:group_saml_identity).and_return(group_saml_identity)
    end

    context 'when current user is allowed to read group saml identity' do
      before do
        create(:group_member, :owner, user: current_user, group: group)
      end

      it 'exposes group_saml_identity' do
        expect(entity_representation[:group_saml_identity]).to include(extern_uid: 'TESTIDENTITY')
      end

      context 'when member source is subgroup' do
        let_it_be(:subgroup) { create :group, parent: group }
        let_it_be(:member) { create(:group_member, :owner, user: user, group: subgroup) }

        it 'does not expose group saml identity' do
          expect(entity_representation.keys).not_to include(:group_saml_identity)
        end
      end

      context 'when member source is project' do
        let_it_be(:project) { create(:project, group: group) }
        let_it_be(:member) { create(:project_member, :owner, user: user, project: project) }

        it 'does not expose group saml identity' do
          expect(entity_representation.keys).not_to include(:group_saml_identity)
        end
      end
    end

    context 'when current user is not allowed to read group saml identity' do
      before do
        create(:group_member, :maintainer, user: current_user, group: group)
      end

      it 'does not expose group saml identity' do
        expect(entity_representation.keys).not_to include(:group_saml_identity)
      end
    end
  end

  context 'for group_scim_identity' do
    let_it_be(:group_scim_identity) { build_stubbed(:group_scim_identity, extern_uid: 'TESTIDENTITY') }

    before do
      allow(member).to receive(:group_scim_identity).and_return(group_scim_identity)
    end

    context 'when current user is allowed to read group scim identity' do
      before do
        create(:group_member, :owner, user: current_user, group: group)
      end

      it 'exposes group_scim_identity' do
        expect(entity_representation[:group_scim_identity]).to include(extern_uid: 'TESTIDENTITY')
      end

      context 'when member source is subgroup' do
        let_it_be(:subgroup) { create :group, parent: group }
        let_it_be(:member) { create(:group_member, :owner, user: user, group: subgroup) }

        it 'does not expose group scim identity' do
          expect(entity_representation.keys).not_to include(:group_scim_identity)
        end
      end

      context 'when member source is project' do
        let_it_be(:project) { create(:project, group: group) }
        let_it_be(:member) { create(:project_member, :owner, user: user, project: project) }

        it 'does not expose group scim identity' do
          expect(entity_representation.keys).not_to include(:group_scim_identity)
        end
      end
    end

    context 'when current user is not allowed to read group saml identity' do
      before do
        create(:group_member, :maintainer, user: current_user, group: group)
      end

      it 'does not expose group saml identity' do
        expect(entity_representation.keys).not_to include(:group_scim_identity)
      end
    end
  end

  context 'for email' do
    shared_examples "exposes the user's email" do
      it "exposes the user's email" do
        expect(entity_representation.keys).to include(:email)
        expect(entity_representation[:email]).to eq(user.email)
      end
    end

    shared_examples "does not expose the user's email" do
      it "does not expose the user's email" do
        expect(entity_representation.keys).not_to include(:email)
      end
    end

    context 'when the current_user is a group owner' do
      before do
        create(:group_member, :owner, user: current_user, group: group)
      end

      include_examples "does not expose the user's email"
    end

    context 'when the current_user is an admin' do
      let_it_be(:current_user) { create(:user, :admin) }

      context 'when admin mode enabled', :enable_admin_mode do
        include_examples "exposes the user's email"
      end

      context 'when admin mode disabled' do
        include_examples "does not expose the user's email"
      end
    end

    context 'on SaaS', :saas do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:another_group) { create(:group_member, :owner, user: current_user).group }

      where(
        :domain_verification_availabe_for_group,
        :user_is_enterprise_user_of_the_group,
        :current_user_is_group_owner,
        :shared_examples
      ) do
        false | false | false | "does not expose the user's email"
        false | false | true  | "does not expose the user's email"
        false | true  | false | "does not expose the user's email"
        false | true  | true  | "does not expose the user's email"
        true  | false | false | "does not expose the user's email"
        true  | false | true  | "does not expose the user's email"
        true  | true  | false | "does not expose the user's email"
        true  | true  | true  | "exposes the user's email"
      end

      with_them do
        before do
          stub_licensed_features(domain_verification: domain_verification_availabe_for_group)

          user.user_detail.enterprise_group_id = user_is_enterprise_user_of_the_group ? group.id : another_group.id

          if current_user_is_group_owner
            create(:group_member, :owner, user: current_user, group: group)
          else
            create(:group_member, :maintainer, user: current_user, group: group)
          end
        end

        include_examples params[:shared_examples]

        context 'when member source is subgroup' do
          let_it_be(:subgroup) { create :group, parent: group }
          let_it_be(:member) { create(:group_member, :owner, user: user, group: subgroup) }

          include_examples params[:shared_examples]
        end

        context 'when member source is project' do
          let_it_be(:project) { create(:project, group: group) }
          let_it_be(:member) { create(:project_member, :owner, user: user, project: project) }

          include_examples params[:shared_examples]
        end
      end
    end
  end

  context 'with state' do
    it 'exposes human_state_name as membership_state' do
      expect(entity_representation.keys).to include(:membership_state)
      expect(entity_representation[:membership_state]).to eq member.human_state_name
    end
  end

  context 'with member role' do
    let_it_be(:member_role) { create(:member_role) }

    it 'exposes member role' do
      allow(member).to receive(:member_role).and_return(member_role)

      expect(entity_representation[:member_role][:id]).to eq member_role.id
      expect(entity_representation[:member_role][:base_access_level]).to eq member_role.base_access_level
      expect(entity_representation[:member_role][:group_id]).to eq(member_role.namespace.id)
    end
  end

  context 'without member role' do
    it 'does not expose member role' do
      expect(entity_representation[:member_role]).to be_nil
    end
  end
end
