import { GlIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import AgentStatusIcon from 'ee/ai/shared/widgets/agent_status_icon.vue';

describe('AgentStatusIcon', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = mount(AgentStatusIcon, {
      propsData: {
        ...props,
      },
      stubs: {
        GlIcon,
      },
    });
  };

  const findStatusIcon = () => wrapper.findComponent(GlIcon);
  const findStatusIconContainer = () => wrapper.find('span');

  describe('when status is provided', () => {
    it('renders the status icon when valid', () => {
      createWrapper({ status: 'FINISHED', humanStatus: 'Finished' });

      expect(findStatusIcon().exists()).toBe(true);
    });
  });

  describe('when status is not provided', () => {
    it('renders the status icon with default created state', () => {
      createWrapper({ status: '', humanStatus: '' });

      const icon = findStatusIcon();
      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('dash-circle');
    });
  });

  describe('with different item statuses', () => {
    const statusTestCases = [
      {
        status: 'CREATED',
        humanStatus: 'Created',
        expectedStatusIcon: 'dash-circle',
        expectedStatusBorderColor: 'neutral',
        expectedStatusBackgroundColor: 'neutral',
      },
      {
        status: 'FINISHED',
        humanStatus: 'Finished',
        expectedStatusIcon: 'check',
        expectedStatusBorderColor: 'green',
        expectedStatusBackgroundColor: 'success',
      },
      {
        status: 'FAILED',
        humanStatus: 'Failed',
        expectedStatusIcon: 'error',
        expectedStatusBorderColor: 'red',
        expectedStatusBackgroundColor: 'danger',
      },
      {
        status: 'PAUSED',
        humanStatus: 'Paused',
        expectedStatusIcon: 'pause',
        expectedStatusBorderColor: 'neutral',
        expectedStatusBackgroundColor: 'neutral',
      },
    ];

    statusTestCases.forEach(
      ({
        status,
        humanStatus,
        expectedStatusIcon,
        expectedStatusBorderColor,
        expectedStatusBackgroundColor,
      }) => {
        it(`renders correct status for ${status}`, () => {
          createWrapper({ status, humanStatus });

          const icon = findStatusIcon();
          expect(icon.props('name')).toBe(expectedStatusIcon);

          const containerClasses = findStatusIconContainer().classes();
          expect(containerClasses).toContain(`gl-border-${expectedStatusBorderColor}-100`);
          expect(containerClasses).toContain(`gl-bg-status-${expectedStatusBackgroundColor}`);
        });
      },
    );
  });
});
