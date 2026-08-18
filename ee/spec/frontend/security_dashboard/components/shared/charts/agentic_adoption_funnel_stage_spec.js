import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { formatNumber } from '~/locale';
import AgenticAdoptionFunnelStage from 'ee/security_dashboard/components/shared/charts/agentic_adoption_funnel_stage.vue';

jest.mock('~/locale', () => ({
  ...jest.requireActual('~/locale'),
  formatNumber: jest.fn((value) => `formatted-${value}`),
}));

describe('AgenticAdoptionFunnelStage', () => {
  let wrapper;

  const defaultProps = {
    count: 1240,
    title: 'Critical & High SAST vulnerabilities',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AgenticAdoptionFunnelStage, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findCount = () => wrapper.findByTestId('funnel-stage-count');
  const findDescription = () => wrapper.findByTestId('funnel-stage-description');

  beforeEach(() => {
    createComponent();
  });

  it('renders the count formatted with formatNumber', () => {
    expect(formatNumber).toHaveBeenCalledWith(1240);
    expect(findCount().text()).toBe('formatted-1240');
  });

  it('renders the title', () => {
    expect(wrapper.text()).toContain('Critical & High SAST vulnerabilities');
  });

  describe('without a description', () => {
    it('does not render the description', () => {
      expect(findDescription().exists()).toBe(false);
    });
  });

  describe('with a description', () => {
    beforeEach(() => {
      createComponent({ description: 'Vulnerability Resolution' });
    });

    it('renders the description text', () => {
      expect(findDescription().text()).toContain('Vulnerability Resolution');
    });

    it('renders the Duo (tanuki-ai) icon', () => {
      expect(findDescription().findComponent(GlIcon).props('name')).toBe('tanuki-ai');
    });
  });
});
