import { GlAlert, GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import MissingSelfHostedModelsAlert from 'ee/ai/settings/components/missing_self_hosted_models_alert.vue';

let wrapper;

const createComponent = ({ props = {} } = {}) => {
  wrapper = extendedWrapper(
    shallowMount(MissingSelfHostedModelsAlert, {
      propsData: {
        modelSelectionPath: '/admin/model_selection',
        ...props,
      },
    }),
  );
};

const findAlert = () => wrapper.findComponent(GlAlert);
const findLink = () => wrapper.findComponent(GlLink);

describe('MissingSelfHostedModelsAlert', () => {
  beforeEach(() => {
    createComponent();
  });

  it('renders a non-dismissible warning alert', () => {
    expect(findAlert().exists()).toBe(true);
    expect(findAlert().props('variant')).toBe('warning');
    expect(findAlert().props('dismissible')).toBe(false);
  });

  it('renders the explanatory body text', () => {
    expect(findAlert().text()).toContain(
      'No self-hosted model is configured. AI requests route to GitLab-managed models until a self-hosted model is available.',
    );
  });

  describe('configure link', () => {
    it('renders the link text', () => {
      expect(findLink().text()).toBe('Configure self-hosted models');
    });

    it('points to the self-hosted models tab under the provided model selection path', () => {
      createComponent({ props: { modelSelectionPath: '/admin/gitlab_duo/model_selection' } });

      expect(findLink().attributes('href')).toBe('/admin/gitlab_duo/model_selection/models');
    });
  });
});
