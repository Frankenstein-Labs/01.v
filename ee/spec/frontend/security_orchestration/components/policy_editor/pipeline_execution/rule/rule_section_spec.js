import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  DEFAULT_SCHEDULE,
  INJECT,
  SCHEDULE,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import RuleSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/rule_section.vue';
import ScheduleForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/schedule_form.vue';

describe('RuleSection', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {}, isStubbed = true } = {}) => {
    const stubs = isStubbed ? { GlSprintf } : {};

    wrapper = shallowMountExtended(RuleSection, {
      propsData,
      provide,
      stubs,
    });
  };

  const findGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findGlLink = () => wrapper.findComponent(GlLink);
  const findScheduleForm = () => wrapper.findComponent(ScheduleForm);

  describe('rendering', () => {
    it('renders inject/override message when schedule is not selected', () => {
      createComponent({ propsData: { strategy: INJECT } });
      expect(wrapper.findComponent(GlSprintf).exists()).toBe(true);
      expect(findScheduleForm().exists()).toBe(false);
    });

    describe('schedule form', () => {
      const provide = { glFeatures: { scheduledPipelineExecutionPolicies: true } };

      it('renders schedule form when schedule is selected', () => {
        createComponent({ propsData: { strategy: SCHEDULE }, provide });
        expect(wrapper.findComponent(GlSprintf).exists()).toBe(false);
        expect(findScheduleForm().exists()).toBe(true);
        expect(findScheduleForm().props('schedule')).toEqual(DEFAULT_SCHEDULE);
      });

      it('passes schedule prop to ScheduleForm component', () => {
        const customSchedule = { type: 'weekly', days: ['Monday'] };
        createComponent({
          propsData: { schedules: [customSchedule], strategy: SCHEDULE },
          provide,
        });

        expect(findScheduleForm().props(SCHEDULE)).toEqual(customSchedule);
      });

      it('listens for changed event from schedule form', async () => {
        createComponent({ propsData: { strategy: SCHEDULE }, provide });

        const updatedSchedule = { type: 'monthly', days_of_month: '15' };
        await findScheduleForm().vm.$emit('changed', updatedSchedule);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toEqual(updatedSchedule);
      });
    });
  });

  describe('errorSources', () => {
    const provide = { glFeatures: { scheduledPipelineExecutionPolicies: true } };

    it('passes errorSources to ScheduleForm', () => {
      const errorSources = [['schedules', '0', 'time_window']];
      createComponent({ propsData: { strategy: SCHEDULE, errorSources }, provide });
      expect(findScheduleForm().props('errorSources')).toEqual(errorSources);
    });

    it('passes empty errorSources by default', () => {
      createComponent({ propsData: { strategy: SCHEDULE }, provide });
      expect(findScheduleForm().props('errorSources')).toEqual([]);
    });
  });

  describe('inject/override message', () => {
    it('renders text', () => {
      createComponent({ isStubbed: false });
      expect(findGlSprintf().attributes('message')).toBe(
        'Configure your conditions in the pipeline execution file. %{linkStart}What can pipeline execution do?%{linkEnd}',
      );
    });

    it('renders link', () => {
      createComponent();
      expect(findGlLink().exists()).toBe(true);
      expect(findGlLink().text()).toBe('What can pipeline execution do?');
      expect(findGlLink().attributes('href')).toBe(
        '/help/user/application_security/policies/pipeline_execution_policies',
      );
    });
  });
});
