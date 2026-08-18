import { GlSprintf, GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import mockTimezones from 'test_fixtures/timezones/full.json';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BaseRuleComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/base_rule_component.vue';
import DurationSelector from 'ee/security_orchestration/components/policy_editor/shared/duration_selector/duration_selector.vue';
import ScheduleRuleComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/schedule_rule_component.vue';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import {
  DEFAULT_AGENT_NAME,
  SCAN_EXECUTION_SCHEDULE_RULE,
  SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY,
  SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY,
  SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { CRON_DEFAULT_TIME } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  getHostname: jest.fn().mockReturnValue('gitlab.example.com'),
}));

describe('ScheduleRuleComponent', () => {
  let wrapper;
  const ruleLabel = 'ScanExecutionPolicy|if';
  const initRule = {
    type: SCAN_EXECUTION_SCHEDULE_RULE,
    branches: [],
    cadence: CRON_DEFAULT_TIME,
  };

  const createComponent = (options = {}) => {
    wrapper = shallowMountExtended(ScheduleRuleComponent, {
      propsData: {
        initRule,
        ruleLabel,
        ...options,
      },
      provide: {
        namespaceType: NAMESPACE_TYPES.PROJECT,
        timezones: mockTimezones,
      },
      stubs: {
        BaseRuleComponent,
        GlSprintf,
      },
    });
  };

  const findDurationSelector = () => wrapper.findComponent(DurationSelector);
  const findScheduleRuleScopeDropDown = () => wrapper.findComponentByTestId('rule-component-scope');
  const findScheduleRuleTypeDropDown = () => wrapper.findComponentByTestId('rule-component-type');
  const findScheduleRulePeriodDropDown = () =>
    wrapper.findComponentByTestId('rule-component-period');
  const findScheduleRuleAgentInput = () => wrapper.findComponentByTestId('pipeline-rule-agent');
  const findScheduleRuleNamespacesInput = () =>
    wrapper.findComponentByTestId('pipeline-rule-namespaces');
  const findScheduleRuleTimeDropDown = () => wrapper.findComponentByTestId('rule-component-time');
  const findScheduleRuleDayDropDown = () => wrapper.findComponentByTestId('rule-component-day');
  const findTimezoneDropdown = () => wrapper.findComponent(TimezoneDropdown);
  const findTimezoneLabel = () => wrapper.findByTestId('timezone-label');
  const findTimeWindowWarning = () => wrapper.findComponent(GlAlert);

  describe('select agent scope and namespaces', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should set default agent name if no name was provided', async () => {
      const agentName = 'other-then-default';
      findScheduleRuleScopeDropDown().vm.$emit('select', SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY);
      await nextTick();

      findScheduleRuleAgentInput().vm.$emit('update', agentName);
      await nextTick();
      findScheduleRuleAgentInput().vm.$emit('update', '');
      await nextTick();

      const [eventPayload] = wrapper.emitted().changed[3];

      expect(eventPayload).toMatchObject({
        type: SCAN_EXECUTION_SCHEDULE_RULE,
        agents: {
          [DEFAULT_AGENT_NAME]: {
            namespaces: [],
          },
        },
        cadence: CRON_DEFAULT_TIME,
      });
    });

    it('should select agent and list of name spaces', async () => {
      const agent = 'cube-agent';
      const namespaces = 'namespace1,namespace2,namespace3';

      findScheduleRuleScopeDropDown().vm.$emit('select', SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY);
      await nextTick();

      findScheduleRuleAgentInput().vm.$emit('update', agent);
      findScheduleRuleNamespacesInput().vm.$emit('update', namespaces);

      const [eventPayload] = wrapper.emitted().changed[3];

      expect(eventPayload).toMatchObject({
        type: SCAN_EXECUTION_SCHEDULE_RULE,
        agents: {
          [agent]: {
            namespaces: ['namespace1', 'namespace2', 'namespace3'],
          },
        },
        cadence: CRON_DEFAULT_TIME,
      });
    });
  });

  describe('select correct time', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should select correct time', () => {
      findScheduleRuleTimeDropDown().vm.$emit('select', '1');

      const [eventPayload] = wrapper.emitted().changed[0];
      expect(eventPayload).toEqual({
        type: SCAN_EXECUTION_SCHEDULE_RULE,
        branches: [],
        cadence: '0 1 * * *',
      });
    });

    it('should select correct time and day', async () => {
      findScheduleRulePeriodDropDown().vm.$emit('select', SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY);
      await nextTick();

      findScheduleRuleTimeDropDown().vm.$emit('select', '2');
      findScheduleRuleDayDropDown().vm.$emit('select', '2');

      await nextTick();

      const [eventPayload] = wrapper.emitted().changed[2];
      expect(eventPayload).toEqual({
        type: SCAN_EXECUTION_SCHEDULE_RULE,
        branches: [],
        cadence: '0 2 * * 2',
      });
    });

    it('should select correct timezone', () => {
      findTimezoneDropdown().vm.$emit('input', {
        identifier: mockTimezones[1].identifier,
        formattedTimezone: mockTimezones[0].identifier,
      });

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            type: SCAN_EXECUTION_SCHEDULE_RULE,
            branches: [],
            cadence: '0 0 * * *',
            timezone: mockTimezones[1].identifier,
          },
        ],
      ]);
    });
  });

  describe('parse existing rules', () => {
    it('should parse existing rules correctly', () => {
      createComponent({
        initRule: {
          type: SCAN_EXECUTION_SCHEDULE_RULE,
          cadence: '0 9 * * 4',
          branches: ['branch1,branch2'],
          timezone: mockTimezones[0].identifier,
        },
      });

      expect(findScheduleRuleTypeDropDown().props('selected')).toBe(initRule.type);

      expect(findScheduleRuleScopeDropDown().props('selected')).toBe(
        SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY,
      );

      expect(findTimezoneDropdown().props('value')).toBe(mockTimezones[0].identifier);

      expect(findScheduleRuleTimeDropDown().props('selected')).toBe('9');
      expect(findScheduleRuleDayDropDown().props('selected')).toBe('4');
      expect(findScheduleRulePeriodDropDown().props('selected')).toBe(
        SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY,
      );
    });
  });

  describe('timezone dropdown', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should display label for branch scope with host name', () => {
      expect(findTimezoneLabel().text()).toBe('on gitlab.example.com');
    });

    it('should display specific label for agent scope', async () => {
      findScheduleRuleScopeDropDown().vm.$emit('select', SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY);
      await nextTick();

      expect(findTimezoneLabel().text()).toBe('on the Kubernetes agent pod');
    });

    it('should display correct tooltip for branch scope with host name', () => {
      expect(findTimezoneDropdown().attributes('title')).toBe("gitlab.example.com's timezone");
    });

    it('should display specific tooltip for agent scope', async () => {
      findScheduleRuleScopeDropDown().vm.$emit('select', SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY);
      await nextTick();

      expect(findTimezoneDropdown().attributes('title')).toBe("Kubernetes agent's timezone");
    });
  });

  describe('duration selector', () => {
    it('renders', () => {
      createComponent();
      expect(findDurationSelector().props()).toMatchObject({
        timeWindow: { distribution: 'random' },
        timeWindowRequired: false,
      });
    });

    it('handles duration selection changes', async () => {
      createComponent();
      await findDurationSelector().vm.$emit('changed', { distribution: 'random', value: 7200 });
      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            branches: [],
            cadence: '0 0 * * *',
            time_window: { distribution: 'random', value: 7200 },
            type: 'schedule',
          },
        ],
      ]);
    });
  });

  describe('time window warning', () => {
    it('shows warning when time_window is not set', () => {
      createComponent({
        initRule: {
          type: SCAN_EXECUTION_SCHEDULE_RULE,
          branches: [],
          cadence: CRON_DEFAULT_TIME,
        },
      });

      expect(findTimeWindowWarning().exists()).toBe(true);
      expect(findTimeWindowWarning().props('variant')).toBe('warning');
      expect(findTimeWindowWarning().props('dismissible')).toBe(false);
      expect(findTimeWindowWarning().text()).toContain(
        'A time window is not set. Setting a time window helps distribute scheduled scans and reduces the load on runner infrastructure. We recommend a time window of at least 6 hours.',
      );
    });

    it('shows warning when time_window value is not set', () => {
      createComponent({
        initRule: {
          type: SCAN_EXECUTION_SCHEDULE_RULE,
          branches: [],
          cadence: CRON_DEFAULT_TIME,
          time_window: { distribution: 'random' },
        },
      });

      expect(findTimeWindowWarning().exists()).toBe(true);
    });

    it('does not show warning when time_window is properly set', () => {
      createComponent({
        initRule: {
          type: SCAN_EXECUTION_SCHEDULE_RULE,
          branches: [],
          cadence: CRON_DEFAULT_TIME,
          time_window: { distribution: 'random', value: 36000 },
        },
      });

      expect(findTimeWindowWarning().exists()).toBe(false);
    });
  });
});
