import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import {
  CLOSED,
  OPEN,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import FallbackAndEdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_and_edge_cases_section.vue';
import FallbackSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_section.vue';
import EdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/edge_cases_section.vue';

describe('FallbackAndEdgeCasesSection', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMount(FallbackAndEdgeCasesSection, {
      propsData: {
        policy: { fallback_behavior: { fail: CLOSED } },
        ...propsData,
      },
      provide,
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findFallbackSection = () => wrapper.findComponent(FallbackSection);
  const findEdgeCasesSection = () => wrapper.findComponent(EdgeCasesSection);

  describe('fallback section', () => {
    it('renders the fallback section with "property: closed" for a policy without fallback section', () => {
      createComponent();
      expect(findFallbackSection().props()).toEqual({ property: CLOSED });
      expect(findAlert().exists()).toBe(false);
    });

    it('renders the fallback section with "property: closed" for a policy with fallback section', () => {
      createComponent({ propsData: { policy: { fallback_behavior: { fail: OPEN } } } });
      expect(findFallbackSection().props()).toEqual({ property: OPEN });
    });

    it('renders an alert when there is an error', () => {
      createComponent({ propsData: { hasError: true } });
      expect(findAlert().exists()).toBe(true);
    });

    it('emits when a property has changed', () => {
      createComponent({ propsData: { policy: { fallback_behavior: { fail: OPEN } } } });
      findFallbackSection().vm.$emit('changed', 'fail', CLOSED);
      expect(wrapper.emitted('changed')).toEqual([['fail', CLOSED]]);
    });
  });

  describe('policy edge cases section', () => {
    it('renders the edge cases section', () => {
      createComponent();
      expect(findEdgeCasesSection().props()).toStrictEqual({
        policyTuning: { unblock_rules_using_execution_policies: false },
      });
    });

    it('renders the edge cases section with policy value provided', () => {
      createComponent({
        propsData: {
          policy: { policy_tuning: { unblock_rules_using_execution_policies: true } },
        },
      });
      expect(findEdgeCasesSection().props()).toEqual({
        policyTuning: { unblock_rules_using_execution_policies: true },
      });
    });

    it('emits when a property has changed', () => {
      createComponent({ propsData: { policy: { fallback_behavior: { fail: OPEN } } } });
      findEdgeCasesSection().vm.$emit('changed', 'unblock_rules_using_execution_policies', false);
      expect(wrapper.emitted('changed')).toEqual([
        ['unblock_rules_using_execution_policies', false],
      ]);
    });
  });
});
