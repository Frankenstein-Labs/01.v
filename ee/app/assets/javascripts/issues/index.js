import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import RelatedFeatureFlags from './components/related_feature_flags.vue';
import UnableToLinkVulnerabilityError from './components/unable_to_link_vulnerability_error.vue';

export function initRelatedFeatureFlags() {
  const el = document.querySelector('#js-related-feature-flags-root');

  if (!el) {
    return undefined;
  }

  return initVueApp({
    el,
    name: 'RelatedFeatureFlagsRoot',
    provide: { endpoint: el.dataset.endpoint },
    component: RelatedFeatureFlags,
  });
}

export function initUnableToLinkVulnerabilityError() {
  const el = document.querySelector('#js-unable-to-link-vulnerability');

  if (!el) {
    return undefined;
  }

  const { vulnerabilityLink } = el.dataset;

  return initVueApp({
    el,
    name: 'UnableToLinkVulnerabilityErrorRoot',
    component: UnableToLinkVulnerabilityError,
    props: { vulnerabilityLink },
  });
}
