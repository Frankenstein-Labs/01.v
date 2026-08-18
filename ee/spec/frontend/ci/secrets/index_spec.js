import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import { initProjectSecretsApp } from 'ee/ci/secrets/index';
import SecretsBreadcrumbs from 'ee/ci/secrets/components/secrets_breadcrumbs.vue';

jest.mock('~/lib/utils/breadcrumbs');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

Vue.use(VueApollo);

describe('initProjectSecretsApp', () => {
  let appRoot;

  const createAppRoot = () => {
    appRoot = document.createElement('div');
    appRoot.setAttribute('id', 'js-project-secrets-manager');
    appRoot.dataset.projectPath = '/path/to/project';
    appRoot.dataset.projectSecretsSettingsPath = '/path/to/project/-/settings/ci_cd';
    appRoot.dataset.projectId = 7;
    appRoot.dataset.basePath = '/-/secrets';
    appRoot.dataset.secretsManagerActive = 'false';
    appRoot.dataset.enrollmentSettingsPath = '/group/-/edit';
    document.body.appendChild(appRoot);
  };

  describe('on /-/secrets', () => {
    beforeEach(() => {
      setWindowLocation(`${TEST_HOST}/path/to/project/-/secrets`);
      createAppRoot();
      initProjectSecretsApp();
    });

    it('injects breadcrumbs', () => {
      expect(injectVueAppBreadcrumbs).toHaveBeenCalledWith(expect.any(Object), SecretsBreadcrumbs);
    });
  });
});
