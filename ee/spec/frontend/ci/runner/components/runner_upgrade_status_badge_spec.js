import { GlBadge, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import RunnerUpgradeStatusBadge from 'ee/ci/runner/components/runner_upgrade_status_badge.vue';
import {
  UPGRADE_STATUS_AVAILABLE,
  UPGRADE_STATUS_RECOMMENDED,
  UPGRADE_STATUS_NOT_AVAILABLE,
  I18N_UPGRADE_STATUS_AVAILABLE,
  I18N_UPGRADE_STATUS_RECOMMENDED,
  RUNNER_UPGRADE_HELP_PATH,
  RUNNER_VERSION_HELP_PATH,
} from 'ee/ci/runner/constants';

describe('RunnerUpgradeStatusBadge', () => {
  let wrapper;
  let glLicensedFeatures;

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findPopover = () => wrapper.findComponent(GlPopover);

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(RunnerUpgradeStatusBadge, {
      propsData: {
        runner: {
          upgradeStatus: UPGRADE_STATUS_AVAILABLE,
          ...props.runner,
        },
        ...props,
      },
      provide: {
        glLicensedFeatures,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('When no feature is enabled', () => {
    beforeEach(() => {
      glLicensedFeatures = {};
    });

    it('Displays no upgrade status', () => {
      createComponent();

      expect(findBadge().exists()).toBe(false);
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe.each([['runnerUpgradeManagement'], ['runnerUpgradeManagementForNamespace']])(
    'When feature "%s" is enabled',
    (feature) => {
      beforeEach(() => {
        glLicensedFeatures[feature] = true;
      });

      it.each([UPGRADE_STATUS_RECOMMENDED, UPGRADE_STATUS_AVAILABLE])(
        'Displays %s status with icon and popover configured',
        (upgradeStatus) => {
          createComponent({
            props: {
              runner: {
                upgradeStatus,
              },
            },
          });

          expect(findBadge().props('icon')).toBe('upgrade');
          expect(
            findPopover()
              .findAllComponents(GlLink)
              .wrappers.map((c) => c.attributes('href')),
          ).toEqual([RUNNER_UPGRADE_HELP_PATH, RUNNER_VERSION_HELP_PATH]);
        },
      );

      it('Displays upgrade available status texts', () => {
        createComponent();

        expect(findBadge().text()).toBe(I18N_UPGRADE_STATUS_AVAILABLE);
        expect(findBadge().props('variant')).toBe('info');

        expect(findPopover().props('title')).toBe(I18N_UPGRADE_STATUS_AVAILABLE);
        expect(findPopover().text()).toBe(
          'Upgrade GitLab Runner to match your GitLab version. Major and minor versions must match.',
        );
      });

      it('Displays upgrade recommended status texts', () => {
        createComponent({
          props: {
            runner: {
              upgradeStatus: UPGRADE_STATUS_RECOMMENDED,
            },
          },
        });

        expect(findBadge().text()).toBe(I18N_UPGRADE_STATUS_RECOMMENDED);
        expect(findBadge().props('icon')).toBe('upgrade');

        expect(findPopover().props('title')).toBe(I18N_UPGRADE_STATUS_RECOMMENDED);
      });

      it('Displays no unavailable status', () => {
        createComponent({
          props: {
            runner: {
              upgradeStatus: UPGRADE_STATUS_NOT_AVAILABLE,
            },
          },
        });

        expect(findBadge().exists()).toBe(false);
      });

      it('Displays no status for unknown status', () => {
        createComponent({
          props: {
            runner: {
              upgradeStatus: 'SOME_UNKNOWN_STATUS',
            },
          },
        });

        expect(findBadge().exists()).toBe(false);
      });
    },
  );
});
