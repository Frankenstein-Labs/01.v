# frozen_string_literal: true

RSpec.shared_context 'for a dependency proxy for packages' do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :public) }

  # all tokens that we're going to use
  let_it_be(:personal_access_token, freeze: false) { create(:personal_access_token, user: user) }
  let_it_be(:deploy_token, freeze: false) { create(:deploy_token, write_package_registry: true, projects: [project]) }
  let_it_be(:job, freeze: false) { create(:ci_build, user: user, status: :running, project: project) }

  before do
    stub_licensed_features(dependency_proxy_for_packages: true)
    stub_config(dependency_proxy: { enabled: true }) # not enabled by default
  end
end
