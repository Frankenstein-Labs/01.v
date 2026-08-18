import { GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import HealthPresenter from 'ee/glql/components/presenters/health.vue';

describe('HealthPresenter', () => {
  it.each`
    healthStatus        | icon               | textClass            | text
    ${'onTrack'}        | ${'status-health'} | ${'gl-text-success'} | ${'On track'}
    ${'needsAttention'} | ${'warning'}       | ${'gl-text-warning'} | ${'Needs attention'}
    ${'atRisk'}         | ${'error'}         | ${'gl-text-danger'}  | ${'At risk'}
  `(
    'for health status $healthStatus, it presents with the correct icon, text class, and text',
    ({ healthStatus, icon, textClass, text }) => {
      const wrapper = mountExtended(HealthPresenter, { propsData: { data: healthStatus } });

      expect(wrapper.findComponent(GlIcon).props('name')).toBe(icon);
      expect(wrapper.findByTestId('status-text').classes()).toContain(textClass);
      expect(wrapper.text()).toBe(text);
    },
  );
});
