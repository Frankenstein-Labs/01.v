import { GlLink, GlIcon, GlTooltip } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { workItemDevelopmentFeatureFlagNodes } from 'jest/work_items/mock_data';
import WorkItemDevelopmentFfItem from 'ee/work_items/components/work_item_development/work_item_development_ff_item.vue';

jest.mock('~/alert');

describe('WorkItemDevelopmentFfItem', () => {
  let wrapper;

  const enabledFeatureFlag = workItemDevelopmentFeatureFlagNodes[0];
  const disabledFeatureFlag = workItemDevelopmentFeatureFlagNodes[1];

  const createComponent = ({ featureFlag = enabledFeatureFlag }) => {
    wrapper = shallowMount(WorkItemDevelopmentFfItem, {
      propsData: {
        itemContent: featureFlag,
      },
    });
  };

  const findFlagIcon = () => wrapper.findComponent(GlIcon);
  const findFlagLink = () => wrapper.findComponent(GlLink);
  const findIconTooltip = () => wrapper.findComponent(GlTooltip);

  describe('feature flag status icon', () => {
    it.each`
      state         | icon                       | featureFlag            | iconClass
      ${'Enabled'}  | ${'feature-flag'}          | ${enabledFeatureFlag}  | ${'gl-text-blue-500'}
      ${'Disabled'} | ${'feature-flag-disabled'} | ${disabledFeatureFlag} | ${'gl-text-subtle'}
    `(
      'renders icon "$icon" when the state of the feature flag is "$state"',
      ({ state, icon, iconClass, featureFlag }) => {
        createComponent({ featureFlag });

        expect(findFlagIcon().props('name')).toBe(icon);
        expect(findFlagIcon().attributes('class')).toBe(iconClass);
        expect(findIconTooltip().text()).toContain(state);
      },
    );
  });

  describe('feature flag link and name', () => {
    it('should render the flag path and name', () => {
      createComponent({ featureFlag: enabledFeatureFlag });

      expect(findFlagLink().attributes('href')).toBe(enabledFeatureFlag.path);
      expect(findFlagLink().attributes('href')).toContain(`/edit`);

      expect(findFlagLink().text()).toBe(enabledFeatureFlag.name);
    });
  });
});
