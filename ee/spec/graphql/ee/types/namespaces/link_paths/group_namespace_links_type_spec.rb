# frozen_string_literal: true

require "spec_helper"

RSpec.describe Types::Namespaces::LinkPaths::GroupNamespaceLinksType, feature_category: :shared do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  shared_examples "group namespace link paths values" do
    it_behaves_like "common namespace link paths values"

    where(:field, :value) do
      :epics_list | lazy { "/groups/#{namespace.full_path}/-/epics" }
      :group_issues | lazy { "/groups/#{namespace.full_path}/-/issues" }
      :labels_fetch | lazy do
        "/groups/#{namespace.full_path}/-/labels.json?include_ancestor_groups=true&only_group_labels=true"
      end
      :epics_list_path | lazy { "/groups/#{namespace.full_path}/-/epics" }
    end

    with_them do
      it "expects to return the right value" do
        expect(resolve_field(field, namespace, current_user: user)).to eq(value)
      end
    end

    it 'returns work_items settings path' do
      expect(resolve_field(:issues_settings, namespace, current_user: user))
        .to eq("/groups/#{namespace.root_ancestor.full_path}/-/settings/work_items")
    end

    it_behaves_like "new trial path behavior" do
      let(:expected_namespace_id) { namespace.id }
    end
  end

  context 'when fetching public group' do
    let_it_be(:namespace) { create(:group, :nested, :public) }

    it_behaves_like "group namespace link paths values"

    describe '#new_trial_path' do
      context 'when on GitLab.com' do
        before do
          allow(::Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
        end

        it 'returns the new trial path with namespace_id' do
          expect(resolve_field(:new_trial_path, namespace, current_user: user))
            .to eq("/-/trials/new?namespace_id=#{namespace.id}")
        end
      end
    end
  end

  context "when fetching private group" do
    let_it_be(:namespace) { create(:group, :nested, :private) }

    context "when user is not member of the group" do
      it_behaves_like "group namespace link paths values"
    end

    context "when user is member of the group" do
      before_all do
        namespace.add_developer(user)
      end

      it_behaves_like "group namespace link paths values"
    end
  end
end
