# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::Pipelines::Alerts::SharedRunnersMinutesLimitAlertComponent, :saas,
  feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers
  include NamespacesHelper
  include GitlabRoutingHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { build_stubbed(:user, :with_namespace) }
  let_it_be(:group) { build_stubbed(:group, :with_ci_minutes) }
  let_it_be(:project) { build_stubbed(:project, :with_ci_minutes, namespace: group) }

  let(:classes) { nil }
  let(:usage_quotas_link_hidden) { nil }

  let(:namespace) { group }
  let(:show_callout?) { false }
  let(:stage) { nil }
  let(:current_balance) { nil }
  let(:total) { 10_000 }
  let(:percentage) { 0 }
  let(:element) { find_by_testid('ci-minute-limit-banner') }

  subject(:component) do
    described_class.new(
      namespace: group,
      project: project,
      current_user: user,
      classes: classes,
      usage_quotas_link_hidden: usage_quotas_link_hidden
    )
  end

  before do
    allow_next_instance_of(::Ci::Minutes::Notification) do |instance|
      allow(instance).to receive_messages(
        namespace: namespace,
        show_callout?: show_callout?,
        stage: stage,
        current_balance: current_balance,
        total: total,
        percentage: percentage
      )
    end

    render_inline(component)
  end

  shared_examples 'alert with action buttons' do
    it 'displays the purchase button' do
      path = buy_additional_minutes_path(namespace)

      expect(element).to have_link('Buy more compute minutes', href: path)
    end

    it 'displays the usage quotas link' do
      path = usage_quotas_path(namespace, anchor: 'pipelines-quota-tab')

      expect(element).to have_link('See usage statistics', href: path)
    end

    describe 'with usage_quotas_link_hidden: true' do
      let(:usage_quotas_link_hidden) { true }

      it 'hides the usage quotas link' do
        expect(element).not_to have_link('See usage statistics')
      end
    end

    describe 'data attributes' do
      where(:stage, :feature_id) do
        :warning  | 'ci_minutes_limit_alert_warning_stage'
        :danger   | 'ci_minutes_limit_alert_danger_stage'
        :exceeded | 'ci_minutes_limit_alert_exceeded_stage'
      end

      with_them do
        it 'adds feature_id data attribute' do
          expect(element['data-feature-id']).to eq(feature_id)
        end
      end

      it 'adds group data attributes' do
        expect(element['data-dismiss-endpoint']).to eq(Rails.application.routes.url_helpers.group_callouts_path)
        expect(element['data-group-id']).to eq(group.id.to_s)
      end

      describe 'when in a user namespace' do
        let(:namespace) { user.namespace }

        it 'adds user namespace data attributes' do
          expect(element['data-dismiss-endpoint']).to eq(Rails.application.routes.url_helpers.callouts_path)
        end
      end
    end

    describe 'with custom classes' do
      let(:classes) { 'test-class' }

      it 'adds custom class to the alert' do
        expect(element).to match_css('.test-class')
      end
    end
  end

  describe 'not displayed' do
    let(:show_callout?) { false }

    it 'does not render the alert' do
      expect(page).not_to have_css('[data-testid="ci-minute-limit-banner"]')
    end
  end

  describe 'at warning level' do
    let(:show_callout?) { true }
    let(:stage) { :warning }
    let(:current_balance) { 2_000 }
    let(:percentage) { 20 }

    it 'renders the warning alert' do
      expect(element).to match_css('.gl-alert.gl-alert-warning.js-minute-limit-banner')
    end

    it 'displays the details' do
      expect(element.text).to match(%r{.*\shas 2,000 / 10,000 \(20%\) shared runner compute minutes remaining})
    end

    it_behaves_like 'alert with action buttons'
  end

  describe 'at danger level' do
    let(:show_callout?) { true }
    let(:stage) { :danger }
    let(:current_balance) { 500 }
    let(:total) { 10_000 }
    let(:percentage) { 5 }

    it 'renders the danger alert' do
      expect(element).to match_css('.gl-alert.gl-alert-danger.js-minute-limit-banner')
    end

    it 'displays the details' do
      expect(element.text).to match(%r{.*\shas 500 / 10,000 \(5%\) shared runner compute minutes remaining})
    end

    describe 'close to the exceeding level' do
      let(:current_balance) { 50 }
      let(:percentage) { 0.5 }

      it 'displays the details' do
        expect(element.text).to match(%r{.*\shas 50 / 10,000 \(1%\) shared runner compute minutes remaining})
      end
    end

    it_behaves_like 'alert with action buttons'
  end

  describe 'close to exceeded level' do
    let(:show_callout?) { true }
    let(:stage) { :exceeded }
    let(:current_balance) { 0 }
    let(:total) { 10_000 }
    let(:percentage) { 0 }

    it 'renders the danger alert' do
      expect(element).to match_css('.gl-alert.gl-alert-danger.js-minute-limit-banner')
    end

    it 'displays the details' do
      expect(element.text).to match(/.*\shas reached its shared runner compute minutes quota/)
    end

    it_behaves_like 'alert with action buttons'
  end
end
