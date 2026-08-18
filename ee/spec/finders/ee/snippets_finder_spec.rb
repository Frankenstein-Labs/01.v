# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SnippetsFinder, feature_category: :source_code_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organization: organization) }
  let_it_be(:group) { create(:group, :public, organization: organization) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:private_project_snippet) { create(:project_snippet, :private, project: project, author: user) }
  let_it_be(:internal_project_snippet) { create(:project_snippet, :internal, project: project, author: user) }
  let_it_be(:public_project_snippet) { create(:project_snippet, :public, :repository, project: project, author: user) }

  let(:finder_params) { {} }
  let(:finder_user) { user }

  subject { described_class.new(finder_user, finder_params.reverse_merge(organization_id: organization.id)).execute }

  context 'filter by project' do
    let_it_be(:user) { create(:user, :auditor) }

    let(:finder_params) { { project: project } }

    it 'returns all snippets for auditor users' do
      expect(subject).to match_array([private_project_snippet, internal_project_snippet, public_project_snippet])
    end
  end

  context 'filter by authorized snippet projects and authored personal' do
    let_it_be(:other_user) { create(:user) }
    let_it_be(:other_project) { create(:project, organization: organization) }
    let_it_be(:private_personal_snippet) { create(:personal_snippet, :private, author: user, organization: organization) }
    let_it_be(:internal_personal_snippet) { create(:personal_snippet, :internal, author: user, organization: organization) }
    let_it_be(:public_personal_snippet) { create(:personal_snippet, :public, author: user, organization: organization) }
    let_it_be(:other_private_personal_snippet) { create(:personal_snippet, :private, author: other_user, organization: organization) }
    let_it_be(:other_internal_personal_snippet) { create(:personal_snippet, :internal, author: other_user, organization: organization) }
    let_it_be(:other_public_personal_snippet) { create(:personal_snippet, :public, author: other_user, organization: organization) }
    let_it_be(:other_private_project_snippet) { create(:project_snippet, :private, project: other_project, author: other_user) }
    let_it_be(:other_internal_project_snippet) { create(:project_snippet, :internal, project: other_project, author: other_user) }
    let_it_be(:other_public_project_snippet) { create(:project_snippet, :public, project: other_project, author: other_user) }

    let(:finder_params) { { authorized_and_user_personal: true } }

    context 'when no user' do
      let(:finder_user) { nil }

      it 'returns only public personal snippets' do
        expect(subject).to contain_exactly(public_personal_snippet, other_public_personal_snippet)
      end
    end

    context 'when user is not a member of any project' do
      it 'returns only user personal snippets' do
        expect(subject).to match_array([public_personal_snippet, internal_personal_snippet, private_personal_snippet])
      end
    end

    context 'when the user is a member of a project' do
      [:guest, :reporter, :developer, :maintainer].each do |role|
        it 'returns all the authorized project snippets and authored personal ones' do
          project.add_role(user, role)

          expect(subject)
            .to contain_exactly(
              public_personal_snippet,
              internal_personal_snippet,
              private_personal_snippet,
              public_project_snippet,
              internal_project_snippet,
              private_project_snippet
            )
        end

        it 'returns all the authorized project snippets and authored personal ones' do
          project.add_role(user, role)
          other_project.add_role(user, role)

          expect(subject)
            .to contain_exactly(
              public_personal_snippet,
              internal_personal_snippet,
              private_personal_snippet,
              public_project_snippet,
              internal_project_snippet,
              private_project_snippet,
              other_private_project_snippet,
              other_internal_project_snippet,
              other_public_project_snippet
            )
        end
      end

      context 'when user cannot read_cross_project' do
        before do
          project.add_maintainer(user)

          allow(Ability).to receive(:allowed?)
                          .with(user, :read_all_resources)
                          .and_return(false)

          allow(Ability).to receive(:allowed?)
                          .with(user, :read_cross_project)
                          .and_return(false)
        end

        it 'returns only user personal snippets' do
          expect(subject).to contain_exactly(public_personal_snippet, internal_personal_snippet, private_personal_snippet)
        end
      end
    end

    context 'when the user is a member of a group' do
      [:guest, :reporter, :developer, :maintainer].each do |role|
        it 'returns all the authorized project snippets and authored personal ones' do
          group.add_member(user, role)

          expect(subject)
            .to contain_exactly(
              public_personal_snippet,
              internal_personal_snippet,
              private_personal_snippet,
              public_project_snippet,
              internal_project_snippet,
              private_project_snippet
            )
        end
      end
    end

    context 'when param author is passed' do
      let(:finder_params) { { author: other_user, authorized_and_user_personal: true } }

      context 'when user is not a member of any project' do
        it 'returns only the author visible personal snippets to the user' do
          expect(subject).to contain_exactly(other_public_personal_snippet, other_internal_personal_snippet)
        end
      end

      context 'when user is a member of a project' do
        [:guest, :reporter, :developer, :maintainer].each do |role|
          it 'returns all the authorized project and personal snippets authored by the author' do
            project.add_role(user, role)
            other_project.add_role(user, role)

            expect(subject)
              .to contain_exactly(
                other_public_personal_snippet,
                other_internal_personal_snippet,
                other_internal_project_snippet,
                other_public_project_snippet,
                other_private_project_snippet
              )
          end
        end
      end

      context 'when user is an auditor' do
        let_it_be(:auditor) { create(:user, :auditor) }
        let(:finder_user) { auditor }
        let(:finder_params) { { author: user, all_available: true } }

        it 'returns all snippets (everything) for an auditor when all_available="true" passed in' do
          expect(subject).to contain_exactly(
            other_public_project_snippet,
            other_internal_project_snippet,
            other_private_project_snippet,
            other_public_personal_snippet,
            other_internal_personal_snippet,
            other_private_personal_snippet,
            public_personal_snippet,
            internal_personal_snippet,
            private_personal_snippet,
            public_project_snippet,
            internal_project_snippet,
            private_project_snippet
          )
        end
      end
    end

    context 'when only_personal is passed' do
      let(:finder_params) { { authorized_and_user_personal: true, only_personal: true } }

      it 'returns only personal snippets' do
        group.add_maintainer(user)

        expect(subject)
          .to contain_exactly(
            public_personal_snippet,
            internal_personal_snippet,
            private_personal_snippet
          )
      end
    end

    context 'when only_project is passed' do
      let(:finder_params) { { authorized_and_user_personal: true, only_project: true } }

      it 'returns only project snippets' do
        group.add_maintainer(user)

        expect(subject)
          .to contain_exactly(
            public_project_snippet,
            internal_project_snippet,
            private_project_snippet
          )
      end

      context 'when no personal snippets are visible' do
        let(:user) { nil }

        it 'does not return any record' do
          expect(subject).to be_empty
        end
      end
    end
  end

  context 'for a user' do
    context 'when repository storage name is given' do
      let(:finder_params) { { project: project, repository_storage: public_project_snippet.repository_storage } }

      it 'the repository storage filter is ignored' do
        expect(subject).to eq([public_project_snippet, internal_project_snippet])
      end
    end
  end

  context 'for an admin', :enable_admin_mode do
    let_it_be(:user) { create(:user, :admin) }

    context 'when repository storage name is given' do
      let(:finder_params) { { project: project, repository_storage: public_project_snippet.repository_storage } }

      it 'filters by the repository storage name' do
        expect(subject).to eq([public_project_snippet])
      end
    end

    context 'when repository storage name is not given' do
      let(:finder_params) { { project: project } }

      it 'returns all snippets' do
        expect(subject).to match_array([public_project_snippet, internal_project_snippet, private_project_snippet])
      end
    end
  end

  context 'filter by restricted IPs' do
    let_it_be(:restricted_ip_organization) { create(:organization) }
    let_it_be(:private_group) { create(:group, :private, organization: restricted_ip_organization) }
    let_it_be(:group_without_ip_restriction) { create(:group, :private, organization: restricted_ip_organization) }
    let_it_be(:owner) { create(:user, owner_of: private_group) }
    let_it_be(:guest) { create(:user, guest_of: private_group) }
    let_it_be(:restricted_group_ip) { '10.0.0.0/8' }
    let_it_be(:ip_restriction) { create(:ip_restriction, group: private_group, range: restricted_group_ip) }
    let_it_be(:snippet_with_ip_restriction) do
      create(:project_snippet, project: create(:project, group: private_group), author: owner)
    end

    let_it_be(:snippet_without_ip_restriction) do
      create(:project_snippet, project: create(:project, group: group_without_ip_restriction), author: owner)
    end

    let(:user_ip) { '10.0.0.0/8' }

    subject { described_class.new(guest, author: owner, organization_id: restricted_ip_organization.id).execute }

    before do
      stub_licensed_features(group_ip_restriction: true)
      allow(Gitlab::IpAddressState).to receive(:current).and_return(user_ip)
      stub_application_setting(globally_allowed_ips: "")
      group_without_ip_restriction.add_guest(guest)
    end

    it 'returns all snippets' do
      expect(subject).to contain_exactly(snippet_with_ip_restriction, snippet_without_ip_restriction)
    end

    context 'when the user has no access to the group because of the restricted IP rules' do
      let(:user_ip) { '127.0.0.1' }

      it 'returns only the accessible snippets' do
        expect(subject).to contain_exactly(snippet_without_ip_restriction)
      end
    end
  end
end
