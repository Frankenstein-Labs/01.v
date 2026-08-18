import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import BetaFeaturesAlert from 'ee/ai/instance_model_selection/shared/components/beta_features_alert.vue';

describe('BetaFeaturesAlert', () => {
  let wrapper;
  const duoConfigurationSettingsPath = 'admin/gitlab_duo/configuration';
  const message = 'More features are available in beta. %{linkStart}Learn more%{linkEnd}.';

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(BetaFeaturesAlert, {
      provide: {
        duoConfigurationSettingsPath,
      },
      propsData: {
        message,
        ...props,
      },
      stubs: { GlSprintf },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findConfigurationLink = () => wrapper.findComponent(GlLink);

  it('renders the correct message', () => {
    expect(wrapper.text()).toMatchInterpolatedText(message);
  });

  it('contains a link to the Duo settings page', () => {
    expect(findConfigurationLink().props('href')).toBe(duoConfigurationSettingsPath);
  });
});
