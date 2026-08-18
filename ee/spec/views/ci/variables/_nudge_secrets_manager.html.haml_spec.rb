# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ci/variables/_nudge_secrets_manager', feature_category: :secrets_management do
  let_it_be(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needs persisted group for route helpers
  let_it_be(:project) { create(:project, namespace: group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needs persisted project for route helpers
  let_it_be(:user) { build_stubbed(:user) }

  let(:entitlement) { SecretsManagement::Entitlement.new(state: :trial_eligible) }

  subject(:rendered_content) { render && rendered }

  shared_examples 'renders with CTA for owner' do
    before do
      allow(view).to receive(:can?).with(user, :admin_group, group).and_return(true)
    end

    it 'renders the correct body text with CTA button', :aggregate_failures do
      expect(rendered_content).to have_content('Protect your organization from potential leaks.')
      expect(rendered_content).to have_content('Keep secrets secure with GitLab Secrets Manager')
      expect(rendered_content).to have_link('Start free 30-day trial')
    end

    it 'renders the learn more link' do
      expect(rendered_content).to have_link('Learn more.', href: help_page_path('ci/secrets/secrets_manager/_index.md'))
    end
  end

  shared_examples 'renders without CTA for non-owner' do
    before do
      allow(view).to receive(:can?).with(user, :admin_group, group).and_return(false)
    end

    it 'renders the correct body text without the CTA button', :aggregate_failures do
      expect(rendered_content).to have_content('Contact your GitLab administrator for a trial.')
      expect(rendered_content).not_to have_link('Start free 30-day trial')
    end

    it 'renders the learn more link' do
      expect(rendered_content).to have_link('Learn more.', href: help_page_path('ci/secrets/secrets_manager/_index.md'))
    end
  end

  shared_examples 'renders nothing' do
    it 'renders nothing' do
      expect(rendered_content).to be_blank
    end
  end

  before do
    allow(view).to receive_messages(current_user: user, secrets_manager_entitlement_root_namespace: entitlement)
    allow(view).to receive(:can?).with(user, :admin_group, group).and_return(true)
  end

  context 'when rendered in a project context' do
    before do
      assign(:group, nil)
      assign(:project, project)
    end

    context 'when entitlement state is trial_eligible' do
      it_behaves_like 'renders without CTA for non-owner'

      it_behaves_like 'renders with CTA for owner'

      it 'links the CTA button to the project secrets manager page' do
        expect(rendered_content).to have_link('Start free 30-day trial', href: project_secrets_path(project))
      end
    end

    context 'when entitlement state is not trial_eligible' do
      let(:entitlement) { SecretsManagement::Entitlement.new(state: :ineligible) }

      it_behaves_like 'renders nothing'
    end

    context 'when entitlement is nil' do
      let(:entitlement) { nil }

      it_behaves_like 'renders nothing'
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: false)
      end

      it_behaves_like 'renders nothing'
    end
  end

  context 'when rendered in a group context' do
    before do
      assign(:group, group)
      assign(:project, nil)
    end

    context 'when entitlement state is trial_eligible' do
      it_behaves_like 'renders with CTA for owner'

      it 'links the CTA button to the group secrets manager page' do
        expect(rendered_content).to have_link('Start free 30-day trial', href: group_secrets_path(group))
      end
    end

    context 'when entitlement state is not trial_eligible' do
      let(:entitlement) { SecretsManagement::Entitlement.new(state: :ineligible) }

      it_behaves_like 'renders nothing'
    end

    context 'when entitlement is nil' do
      let(:entitlement) { nil }

      it_behaves_like 'renders nothing'
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager_paid_experience: false)
      end

      it_behaves_like 'renders nothing'
    end
  end
end
