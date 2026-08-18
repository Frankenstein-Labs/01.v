import { mount } from '@vue/test-utils';
import { GlBadge, GlLoadingIcon } from '@gitlab/ui';
import StatusBadge, { VARIANTS } from 'ee/vue_shared/security_reports/components/status_badge.vue';
import { VULNERABILITY_STATES } from 'ee/vulnerabilities/constants';
import { assertProps } from 'helpers/assert_props';

describe('StatusBadge', () => {
  let wrapper;

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const createWrapper = ({ state, loading }) => {
    wrapper = mount(StatusBadge, {
      propsData: {
        state,
        loading,
      },
    });
  };

  it.each(Object.entries(VARIANTS))(
    'the vulnerability state badge has the correct style for the %s state',
    (state, variant) => {
      createWrapper({ state });
      const badge = findBadge();

      expect(badge.props('variant')).toBe(variant);
      expect(badge.text()).toBe(VULNERABILITY_STATES[state]);
    },
  );

  it('fails validation if the passed state is not supported', () => {
    expect(() => {
      assertProps(StatusBadge, { state: 'invalid-prop' });
    }).toThrow('Invalid prop: custom validator check failed for prop');
  });

  it.each([true, false])('renders the loading icon: "%s"', (loading) => {
    createWrapper({ state: 'detected', loading });

    expect(findLoadingIcon().exists()).toBe(loading);
  });
});
