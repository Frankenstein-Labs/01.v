# frozen_string_literal: true

RSpec.shared_examples 'protected ref with ee access levels for' do |type|
  describe "scopes" do
    let_it_be(:project, freeze: false) { create(:project) }
    let_it_be(:user, freeze: false) { create(:user, developer_of: project) }
    let_it_be(:group) { create(:project_group_link, :developer, project: project).group }
    let_it_be(:user_access_level, freeze: false) do
      create(
        "#{described_class.model_name.singular}_#{type}_access_level",
        protected_branch: build(:protected_branch, project: project),
        user: user
      )
    end

    let_it_be(:group_access_level) do
      create(
        "#{described_class.model_name.singular}_#{type}_access_level",
        protected_branch: build(:protected_branch, project: project),
        group: group
      )
    end

    type_access_by_user = :"#{type}_access_by_user"
    describe "#{type_access_by_user}(user)" do
      subject { described_class.send(type_access_by_user, user) }

      it { is_expected.to match_array([user_access_level]) }
    end

    type_access_by_group = :"#{type}_access_by_group"
    describe "#{type_access_by_group}(group)" do
      subject { described_class.send(type_access_by_group, group) }

      it { is_expected.to match_array([group_access_level]) }
    end
  end
end
