import { GlPopover, GlSprintf, GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import EpicCountables from 'ee/vue_shared/components/epic_countables/epic_countables.vue';

describe('EpicCountables', () => {
  let wrapper;

  const defaultProps = {
    openedEpicsCount: 0,
    closedEpicsCount: 0,
    openedIssuesCount: 0,
    closedIssuesCount: 0,
    openedIssuesWeight: 0,
    closedIssuesWeight: 0,
  };

  function createComponent(options = {}) {
    const { props = {} } = options;

    return shallowMountExtended(EpicCountables, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  }

  describe('Count popover', () => {
    beforeEach(() => {
      wrapper = createComponent({
        props: {
          allowSubEpics: true,
          openedEpicsCount: 1,
          closedEpicsCount: 1,
          openedIssuesCount: 2,
          closedIssuesCount: 1,
          openedIssuesWeight: 9,
          closedIssuesWeight: 6,
        },
      });
    });

    it('returns string containing epic count based on available direct children within state', () => {
      expect(wrapper.findComponent(GlPopover).text()).toMatch(/Epics •\n\s+1 open, 1 closed/);
    });

    it('returns string containing issue count based on available direct children within state', () => {
      expect(wrapper.findComponent(GlPopover).text()).toMatch(/Issues •\n\s+2 open, 1 closed/);
    });

    it('displays warning', () => {
      expect(wrapper.findComponent(GlAlert).text()).toBe(
        'Counts reflect children you may not have access to.',
      );
    });

    it('total of openedIssues and closedIssues weight', () => {
      expect(wrapper.findComponent(GlPopover).text()).toMatch(/Total weight •\n\s+15/);
    });
  });

  it('shows render item countBadge, weights, and progress correctly', () => {
    wrapper = createComponent({
      props: {
        allowSubEpics: true,
        openedIssuesCount: 1,
        openedIssuesWeight: 5,
        closedIssuesWeight: 10,
      },
    });

    expect(wrapper.findByTestId('epic-countables-counts-issues').text()).toBe('1');
    expect(wrapper.findByTestId('epic-countables-weight-issues').text()).toBe('15');
    expect(wrapper.findByTestId('epic-progress').text()).toBe('67%');
  });

  it('does not render progress when weight is zero', () => {
    wrapper = createComponent({
      props: {
        allowSubEpics: true,
        openedIssuesCount: 1,
      },
    });

    expect(wrapper.findByTestId('epic-progress').exists()).toBe(false);
  });

  it('renders the popover with the correct data', () => {
    wrapper = createComponent({
      props: {
        allowSubEpics: true,
        openedIssuesCount: 1,
        closedIssuesCount: 1,
        openedIssuesWeight: 5,
        closedIssuesWeight: 10,
      },
    });

    expect(wrapper.findComponent(GlPopover)).toBeDefined();

    expect(wrapper.findByTestId('epic-countables-total-weight').text()).toBe('15');
    expect(wrapper.findByTestId('epic-progress').exists()).toBe(true);
    expect(wrapper.findByTestId('epic-progress-popover-content').text()).toBe(
      '10 of 15 weight completed',
    );
  });
});
