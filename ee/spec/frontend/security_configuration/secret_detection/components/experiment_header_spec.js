import { shallowMount } from '@vue/test-utils';
import { GlExperimentBadge, GlSprintf } from '@gitlab/ui';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import ExperimentHeader from 'ee/security_configuration/secret_detection/components/experiment_header.vue';

describe('ExperimentHeader', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(ExperimentHeader, {
      stubs: { GlSprintf },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findPromoPageLink = () => wrapper.findComponent(PromoPageLink);

  it('renders the experiment badge', () => {
    expect(findExperimentBadge().exists()).toBe(true);
  });

  it('renders correct links', () => {
    expect(findPromoPageLink().props('path')).toBe('/handbook/legal/testing-agreement/');
  });

  it('renders correct text', () => {
    expect(wrapper.text()).toMatchInterpolatedText(
      'This feature is subject to the GitLab Testing Agreement.',
    );
  });
});
