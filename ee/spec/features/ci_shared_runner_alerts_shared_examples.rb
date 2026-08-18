# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'page with the alert' do |usage_quotas_link_hidden = false|
  it 'displays the alert' do
    expect(has_testid?('ci-minute-limit-banner', count: 1)).to be true

    banner = find_by_testid('ci-minute-limit-banner')

    expect(banner).to match_selector('.js-minute-limit-banner')
    within(banner) do
      expect(page).to have_content(message)
      expect(page).to have_link 'Buy more compute minutes', href: buy_minutes_subscriptions_link(namespace)

      # rubocop: disable RSpec/AvoidConditionalStatements -- this is a minor difference in the UI that is not worth a separate test
      if usage_quotas_link_hidden
        expect(page).not_to have_link 'See usage statistics',
          href: usage_quotas_path(namespace, anchor: 'pipelines-quota-tab')
      else
        expect(page).to have_link 'See usage statistics',
          href: usage_quotas_path(namespace, anchor: 'pipelines-quota-tab')
      end
      # rubocop: enable RSpec/AvoidConditionalStatements
    end
  end
end

RSpec.shared_examples 'project pages with alerts' do
  it_behaves_like 'page with the alert' do
    before do
      visit project_pipelines_path(project)
    end
  end

  it_behaves_like 'page with the alert' do
    before do
      visit project_path(project)
    end
  end

  it_behaves_like 'page with the alert' do
    before do
      visit project_job_path(project, job)
    end
  end
end

RSpec.shared_examples 'page with no alerts' do
  it 'does not display the alert' do
    expect(has_testid?('ci-minute-limit-banner')).to be false
  end
end

RSpec.shared_examples 'project pages with no alerts' do
  it_behaves_like 'page with no alerts' do
    before do
      visit project_pipelines_path(project)
    end
  end

  it_behaves_like 'page with no alerts' do
    before do
      visit project_path(project)
    end
  end

  it_behaves_like 'page with no alerts' do
    before do
      visit project_job_path(project, job)
    end
  end
end
