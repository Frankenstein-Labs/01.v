import { initGroupProtectedEnvironmentList } from 'ee/protected_environments/group_protected_environment_list';
import { initProtectedEnvironments } from 'ee/protected_environments/protected_environments';
import initPipelineSubscriptionsApp from 'ee/ci/pipeline_subscriptions';
import { initProjectSecretsApp } from 'ee/ci/secrets';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import '~/pages/projects/settings/ci_cd/show/index';

initGroupProtectedEnvironmentList();
initProtectedEnvironments();

if (gon.features?.vue3MigratePipelines) {
  (async () => {
    try {
      // eslint-disable-next-line no-shadow -- Override with Vue 3 app
      const { default: initPipelineSubscriptionsApp } =
        await import('ee/ci/pipeline_subscriptions?vue3');
      initPipelineSubscriptionsApp();
      return;
    } catch (e) {
      Sentry.captureException(e);
    }

    initPipelineSubscriptionsApp();
  })();
} else {
  initPipelineSubscriptionsApp();
}

initProjectSecretsApp(false);
