# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::GroupPolicy, :enable_admin_mode, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  include_context 'GroupPolicy context'

  let_it_be(:status_related_actions) { %i[admin_work_item_lifecycle] }
  let_it_be(:type_related_actions) { %i[create_work_item_type update_work_item_type] }
  let_it_be(:visibility_actions) { %i[update_work_item_type_visibility] }
  let_it_be(:settings_update_actions) { %i[update_work_item_setting] }

  let(:policy_subject) { group }

  subject { ::GroupPolicy.new(current_user, policy_subject) }

  shared_examples 'allows status-related actions for maintainers and above on root group when licensed' do
    before do
      stub_licensed_features(work_item_status: true)
    end

    where(:role, :allowed) do
      :guest      | false
      :developer  | false
      :maintainer | true
      :owner      | true
      :admin      | true
    end

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to(allowed ? be_allowed(*status_related_actions) : be_disallowed(*status_related_actions)) }
    end
  end

  shared_examples 'disallows status-related actions for all roles on subgroup' do
    before do
      stub_licensed_features(work_item_status: true)
    end

    where(:role) { [:guest, :subgroup_developer, :subgroup_maintainer, :subgroup_owner, :admin] }

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to be_disallowed(*status_related_actions) }
    end
  end

  shared_examples 'allows type-related actions for maintainers and above on root group when licensed' do
    before do
      stub_licensed_features(configurable_work_item_types: true)
    end

    where(:role, :allowed) do
      :guest      | false
      :developer  | false
      :maintainer | true
      :owner      | true
      :admin      | true
    end

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to(allowed ? be_allowed(*type_related_actions) : be_disallowed(*type_related_actions)) }
    end
  end

  shared_examples 'allows visibility-related actions for maintainers and above on root group when licensed' do
    before do
      stub_licensed_features(configurable_work_item_types: true)
    end

    where(:role, :allowed) do
      :guest      | false
      :developer  | false
      :maintainer | true
      :owner      | true
      :admin      | true
    end

    with_them do
      let(:current_user) { try(role) }

      it "allows or disallows visibility actions based on role" do
        is_expected.to(allowed ? be_allowed(*visibility_actions) : be_disallowed(*visibility_actions))
      end
    end
  end

  shared_examples 'allows visibility-related actions for subgroup maintainers when licensed' do
    before do
      stub_licensed_features(configurable_work_item_types: true)
    end

    where(:role, :allowed) do
      :guest                | false
      :subgroup_developer   | false
      :subgroup_maintainer  | true
      :admin                | true
    end

    with_them do
      let(:current_user) { try(role) }

      it "allows or disallows visibility actions based on role" do
        is_expected.to(allowed ? be_allowed(*visibility_actions) : be_disallowed(*visibility_actions))
      end
    end
  end

  shared_examples 'disallows type-related actions for all roles on subgroup' do
    before do
      stub_licensed_features(configurable_work_item_types: true)
    end

    where(:role) { [:guest, :subgroup_developer, :subgroup_maintainer, :subgroup_owner, :admin] }

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to be_disallowed(*type_related_actions) }
    end
  end

  shared_examples 'allows update_work_item_setting for maintainers and above on root group when licensed' do
    before do
      stub_licensed_features(configurable_work_item_types: true)
    end

    where(:role, :allowed) do
      :guest      | false
      :developer  | false
      :maintainer | true
      :owner      | true
      :admin      | true
    end

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to(allowed ? be_allowed(*settings_update_actions) : be_disallowed(*settings_update_actions)) }
    end
  end

  shared_examples 'disallows update_work_item_setting for all roles on subgroup' do
    before do
      stub_licensed_features(configurable_work_item_types: true)
    end

    where(:role) { [:guest, :subgroup_developer, :subgroup_maintainer, :subgroup_owner, :admin] }

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to be_disallowed(*settings_update_actions) }
    end
  end

  shared_examples 'disallows permissions when unlicensed' do
    context 'when work item statuses are not available' do
      let(:actions) { status_related_actions }

      before do
        stub_licensed_features(work_item_status: false)
      end

      include_examples 'permission disallowed for all roles'
    end

    context 'when configurable work item types are not available' do
      let(:actions) { type_related_actions }

      before do
        stub_licensed_features(configurable_work_item_types: false)
      end

      include_examples 'permission disallowed for all roles'
    end
  end

  shared_examples 'permission disallowed for all roles' do
    where(:role) { [:guest, :developer, :maintainer, :owner, :admin] }

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to be_disallowed(*actions) }
    end
  end

  it_behaves_like 'allows status-related actions for maintainers and above on root group when licensed'
  it_behaves_like 'allows type-related actions for maintainers and above on root group when licensed'
  it_behaves_like 'allows visibility-related actions for maintainers and above on root group when licensed'
  it_behaves_like 'allows update_work_item_setting for maintainers and above on root group when licensed'

  context 'with subgroup' do
    let(:policy_subject) { subgroup }

    it_behaves_like 'disallows status-related actions for all roles on subgroup'
    it_behaves_like 'disallows type-related actions for all roles on subgroup'
    it_behaves_like 'allows visibility-related actions for subgroup maintainers when licensed'
    it_behaves_like 'disallows update_work_item_setting for all roles on subgroup'
  end

  it_behaves_like 'disallows permissions when unlicensed'
end
