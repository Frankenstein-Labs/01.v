import { GlIcon } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { INSTANCE_TYPE, GROUP_TYPE, STATUS_ONLINE, STATUS_OFFLINE } from '~/ci/runner/constants';
import RunnerDashboardStat from 'ee/ci/runner/components/runner_dashboard_stat.vue';

import RunnerDashboardStatStatus from 'ee/ci/runner/components/runner_dashboard_stat_status.vue';

describe('RunnerDashboardStatStatus', () => {
  let wrapper;

  const findRunnerDashboardStat = () => wrapper.findComponent(RunnerDashboardStat);
  const findIcon = () => wrapper.findComponent(GlIcon);

  const createComponent = ({ props, ...options } = {}) => {
    wrapper = shallowMountExtended(RunnerDashboardStatStatus, {
      propsData: {
        ...props,
      },
      stubs: {
        RunnerDashboardStat,
        GlSingleStat,
      },
      ...options,
    });
  };

  beforeEach(() => {});

  describe.each`
    scope            | status            | title        | icon                | iconClass
    ${INSTANCE_TYPE} | ${STATUS_ONLINE}  | ${'Online'}  | ${'status-active'}  | ${'gl-text-success'}
    ${INSTANCE_TYPE} | ${STATUS_OFFLINE} | ${'Offline'} | ${'status-waiting'} | ${'gl-text-subtle'}
    ${GROUP_TYPE}    | ${STATUS_ONLINE}  | ${'Online'}  | ${'status-active'}  | ${'gl-text-success'}
    ${GROUP_TYPE}    | ${STATUS_OFFLINE} | ${'Offline'} | ${'status-waiting'} | ${'gl-text-subtle'}
  `(
    'for runner of scope $scope and runner status $status',
    ({ scope, status, title, icon, iconClass }) => {
      beforeEach(() => {
        createComponent({
          props: { scope, status },
        });
      });

      it(`shows title "${title}"`, () => {
        expect(wrapper.findByTestId('title-text').text()).toBe(title);
      });

      it(`shows icon "${icon}"`, () => {
        expect(findIcon().props()).toMatchObject({
          name: icon,
          size: 16,
        });
      });

      it(`shows ${title} runners`, () => {
        expect(findRunnerDashboardStat().props()).toEqual({
          icon,
          iconClass,
          scope,
          title,
          variables: { status },
        });
      });

      it(`filters ${title} runners with additional variables`, () => {
        createComponent({
          props: { scope, status, variables: { key: 'value' } },
        });

        expect(findRunnerDashboardStat().props()).toEqual({
          icon,
          iconClass,
          scope,
          title,
          variables: { key: 'value', status },
        });
      });
    },
  );
});
